# BSC 主网部署方案

## 一、项目概述

zkStack 二改项目，L1 从 Ethereum 改为 BSC。当前运行在 BSC Testnet (chain_id 97)，目标部署到 BSC Mainnet (chain_id 56)。

### L1 RPC
- HTTP: `https://bsc-mainnet.nodereal.io/v1/d4f589d712f54a8d98e2ab2e687e609f`
- WSS: `wss://bsc-mainnet.nodereal.io/ws/v1/d4f589d712f54a8d98e2ab2e687e609f`

---

## 二、代码改动（已完成）

### 1. Gas 费用逻辑重构
删除了 `BscGasPriceProvider` 整套硬编码 gas 定价逻辑（BscFeeConfig/BscNetworkStatus/BscGasResult），BSC 现在和 ETH 走完全相同的 `GasAdjuster` 实时指数公式路径。

保留的 BSC 保护：
- `assert_fee_is_not_zero()`：BSC RPC 返回 0 时回退到 1 Gwei（而非 panic）
- `check_priority_fee()`：BSC fee 过高时 cap 到上限（而非 panic）

涉及文件：
- `core/node/eth_sender/src/eth_fees_oracle.rs` — 重写
- `core/node/eth_sender/src/eth_tx_manager.rs` — 移除 BscGasPriceProvider 引用

### 2. 配置清理
删除了 `general.yaml` 中的 `bsc_fee_optimization` 配置块（不再需要）。

### 3. Chain ID 56 网络检测（已验证正确）

4 个检测点全部覆盖 chain_id 56：
- `core/node/eth_sender/src/network_aware/network_detector.rs:21` — `56 | 97 => NetworkType::Bsc`
- `core/lib/eth_client/src/clients/http/query.rs:26` — `is_bsc_network()` fee_history 兼容
- `core/node/eth_watch/src/lib.rs:218` — BSC 每次最多查询 5000 个区块
- `core/node/eth_sender/src/node/manager.rs:83` — 通过环境变量 `L1_CHAIN_ID` 检测

**注意**：主网部署时必须设置环境变量 `L1_CHAIN_ID=56`，否则 manager.rs 默认 1（以太坊），query.rs 的 BSC 兼容逻辑不生效。

---

## 三、主网架构

### 排序器约束
- zkStack 排序器（Sequencer）是**单点**设计，只有 Main Node 能出块
- 没有热备/自动 failover 机制
- External Node 是只读副本，不能接替出块
- Consensus 层多 validator 只参与投票，不参与出块

### 架构图

```
                         BSC Mainnet (L1)
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
   ┌──────▼──────┐    ┌──────▼──────┐    ┌───────▼──────┐
   │  Server A   │    │  Server D   │    │  Server E    │
   │  排序器      │    │  Prover     │    │  GPU 证明    │
   │  (Main Node)│    │  调度机      │    │  (circuit    │
   │             │    │  (gateway   │    │   prover +   │
   │             │    │   + WG      │    │   compressor)│
   │             │    │   + monitor)│    │              │
   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
          │                  │                  │
          │           ┌──────▼──────────────────▼──────┐
          │           │         Server C               │
          ├──────────►│      PostgreSQL                 │
          │           │   server_db + prover_db         │
          │           └────────────────────────────────┘
          │
   ┌──────▼──────┐
   │  Server B   │
   │  External   │◄──── Nginx/LB ◄──── 用户流量
   │  Node (API) │
   └─────────────┘
```

### 服务器配置

| 机器 | 角色 | 配置 | 组件 |
|------|------|------|------|
| **A** | 排序器 | 16C / 64G / 1T NVMe | state_keeper, eth, tree, consensus, commitment_generator, da_dispatcher, proof_data_handler, vm_runner_bwip |
| **B** | API 节点 | 8C / 32G / 500G SSD | External Node (core + api + tree)，可多台 + Nginx 负载均衡 |
| **C** | 数据库 | 8C / 32G / 500G SSD | PostgreSQL (server_db + prover_db) |
| **D** | Prover 调度 | 16C / 64G / 50G SSD | prover_fri_gateway, witness_generator, prover_job_monitor |
| **E** | GPU 证明 | 16C / 64G / 300G NVMe + **GPU 24GB+** | circuit_prover, proof_compressor（串行，不能同时跑） |

### 网络拓扑

```
Internet → Nginx:443 → Server B (EN :3050/3051)
                              │ 内网
                       Server A (排序器 :3050 内部API, :3054 consensus)
                              │ 内网
                       Server C (PostgreSQL :5432 仅内网)
                              │ 内网
                       Server D/E (Prover，通过 :3320 proof_data_handler 连 A)
```

防火墙规则：
- Server A：只开放 3050/3054 给内网
- Server B：3050/3051 通过 Nginx 反代对外（加 rate limit）
- Server C：5432 只允许 A/B/D/E 的内网 IP
- Server D/E：不对外暴露

---

## 四、ZK Proof 方案

### 证明流水线

```
Core 排序器                                Prover 集群
──────────                                ──────────
state_keeper → batch
      │
BWIP → witness_inputs.bin
      │
proof_data_handler (:3320) ◄──────────►  prover_fri_gateway (机器 D)
                                              │
                                    witness_generator (机器 D, CPU)
                                         5 轮聚合:
                                         Round 0: ~10,000 基础电路
                                         Round 1: ~100 叶子聚合
                                         Round 2: ≤16 节点聚合
                                         Round 3: 1 递归顶
                                         Round 4: 1 调度器
                                              │
                                    circuit_prover (机器 E, GPU)
                                         10,000 → 1 proof
                                              │
                                    proof_compressor (机器 E, GPU)
                                         FRI proof → fflonk SNARK
                                              │
                                    prover_fri_gateway → Core
                                              │
                                    eth_sender → proveBatches() on BSC L1
```

### GPU 硬件要求

| 资源 | 依据 | 来源 |
|------|------|------|
| setup data 占 VRAM | **21.8GB** 固定 | `fri_prover_dal.rs:54` |
| WVG 线程额外占用 | 1.7-3.5GB/线程 | `fri_prover_dal.rs:34-43` |
| circuit_prover 最低 | **24GB VRAM** | `00_intro.md:75` |
| proof_compressor | **24GB VRAM** | `03_launch.md:103` |
| 两者不能同时跑 | 共享 GPU | `03_launch.md:104` |
| 满载推荐 | 48GB VRAM | `05_proving_batch.md:12` |
| shivini 库 | 纯 GPU，无 CPU fallback | `shivini/src/context.rs` — StaticDeviceAllocator |

**当前本地 GPU（RTX 5080 16GB）不够**，setup data 21.8GB 放不下，shivini 不支持 GPU+CPU 混合内存。

推荐 GPU 选择：
- **最低**：RTX 3090/4090 (24GB) — 单 WVG 线程，~10-20h/batch
- **推荐**：L40S (48GB) — 满载，~2-4h/batch
- **最佳**：A100 80GB — 可同时跑 prover+compressor

### CPU Prover 情况
- `ProverMode` 枚举只有 `NoProofs` 和 `Gpu`，无 CPU 选项
- 当前 circuit_prover 硬编码依赖 shivini（GPU CUDA 库）
- 旧版 CPU Prover 在架构重构时未迁移到新 Circuit Prover

### External Proof API（外部证明接口）
zkStack 内置了 `external_proof_integration_api` 组件 (:3073)，支持外部 prover 通过 HTTP API 拉取/提交证明：
- `GET /proof_generation_data` — 获取待证明数据
- `GET /proof_generation_data/{batch}` — 获取指定 batch 数据
- `POST /verify_proof/{batch}` — 提交并验证证明

可用于远程 GPU 机器证明，无需和排序器在同一网络。

---

## 五、两阶段上线策略

### Phase 1：无证明上线（先跑起来）

部署 A + B + C 三台，不需要 GPU。

```yaml
# genesis.yaml
dummy_verifier: true

# general.yaml
eth.sender:
  proof_sending_mode: SKIP_EVERY_PROOF
  is_verifier_pre_fflonk: true
```

L1 部署 DummyVerifier 合约，batch 直接标记为 "proven"。

### Phase 2：切换真实证明

触发条件：链上 TVL 达到一定规模 / 社区要求 ZK 安全保障。

步骤：
1. 部署 Prover 基础设施 (D + E)
2. 下载 GPU setup keys（从 GCS，数十 GB）
3. 用 `OnlySampledProofs` 模式试跑，确认能生成有效证明
4. 在 BSC 主网升级 Verifier 合约（通过 governance 执行 Diamond Proxy 升级）
5. 切换配置 `proof_sending_mode: ONLY_REAL_PROOFS`，`dummy_verifier: false`

---

## 六、主网配置变更清单

### genesis.yaml
```yaml
l1_chain_id: 56              # 97 → 56
l2_chain_id: 9720             # 保持不变
dummy_verifier: true          # Phase 1
```

### secrets.yaml
```yaml
database:
  server_url: postgres://USER:STRONG_PASSWORD@DB_HOST:5432/tmai_mainnet
  prover_url: postgres://USER:STRONG_PASSWORD@DB_HOST:5432/prover_mainnet
l1:
  l1_rpc_url: https://bsc-mainnet.nodereal.io/v1/d4f589d712f54a8d98e2ab2e687e609f
```

### general.yaml 关键调整
```yaml
eth:
  gas_adjuster:
    default_priority_fee_per_gas: 1000000000   # 1 Gwei
    max_base_fee_samples: 10
    pricing_formula_parameter_a: 1.2
    pricing_formula_parameter_b: 1.005
  sender:
    pubdata_sending_mode: BLOBS
    use_fusaka_blob_format: false               # 必须 false
    fusaka_upgrade_block: 999999999             # 禁用 Fusaka
    wait_confirmations: 5                       # 主网 5 确认
    max_acceptable_base_fee_in_wei: 50000000000 # 50 Gwei 上限
    proof_sending_mode: SKIP_EVERY_PROOF        # Phase 1
  watcher:
    confirmations_for_eth_event: 5
```

### ZkStack.yaml
```yaml
l1_network: bsc-mainnet       # bsc-testnet → bsc-mainnet
```

### 环境变量
```bash
export L1_CHAIN_ID=56         # 必须设置
```

### wallets.yaml
- 必须使用全新钱包，不复用测试网私钥
- 所需角色：deployer, governor, operator, blob_operator, fee_account, token_multiplier_setter

---

## 七、部署顺序

```
1. Server C  → PostgreSQL（强密码 + 内网绑定）
2. Server A  → 部署合约到 BSC 主网 → genesis → 启动排序器
3. Server B  → EN 连接排序器 → 验证同步 → Nginx 反代对外
4. 监控      → Prometheus + Grafana（operator 余额 / L1 tx 状态 / 出块延迟）
5. (Phase 2) Server D + E → Prover 部署
```

---

## 八、成本估算

### Phase 1（无证明）
| 项目 | 费用 |
|------|------|
| L1 合约部署 | ~3-5 BNB (一次性) |
| 每日 Blob 提交 | ~0.5-2 BNB/天 |
| 每日 Commit/Execute | ~0.3-1 BNB/天 |
| 服务器 (A+B+C) | ~$500-1000/月 |

### Phase 2（含证明）
| 项目 | 费用 |
|------|------|
| Server D (Prover 调度) | ~$300/月 |
| Server E (GPU A100 按需) | ~$2-4/GPU·小时 |
| 每 batch 证明 | ~$6-12/batch |
| 日均 (50 batch/天) | ~$300-600/天 |

---

## 九、安全注意事项

1. **私钥管理**：wallets.yaml 中的私钥不要明文存储，考虑 KMS/Vault
2. **RPC 备用**：NodeReal 单节点不够稳定，建议自建 BSC 全节点作为 fallback
3. **数据库安全**：PostgreSQL 不暴露公网，使用内网 + SSH tunnel
4. **监控告警**：operator BNB 余额 < 2 BNB 时自动告警
5. **排序器容灾**：DB 持续备份 (WAL 流复制) + Docker 镜像预构建 + RocksDB 定期快照，预计恢复时间 5-15 分钟

---

## 十、关键文档参考

项目内置 prover 文档：`prover/docs/src/`
- `00_intro.md` — 组件介绍 + 硬件要求
- `01_gcp_vm.md` — GCP VM 创建
- `02_setup.md` — CUDA + Bellman-CUDA 安装
- `03_launch.md` — 启动各 prover 组件
- `04_flow.md` — 证明流水线详解
- `05_proving_batch.md` — 独立证明一个 batch 的完整步骤
