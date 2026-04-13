# 🔥 tMai Chain TPS 优化指南

## 问题分析

当前 TPS 性能：
- **TPS**: 0.02-0.04 (极低)
- **成功率**: 5% (每轮20笔只成功1笔)
- **延迟**: 25-40秒/笔

## 根本原因

### 1. **区块封装延迟过高**
```yaml
block_commit_deadline_ms: 3000      # 3秒才封装一个区块
miniblock_commit_deadline_ms: 1000  # 1秒才封装一个 miniblock
```
**影响**: 交易需要等待很久才能被打包

### 2. **内存池同步慢**
```yaml
sync_interval_ms: 10                # 10ms 同步一次
delay_interval: 100                 # 100ms 延迟
```
**影响**: 交易进入内存池慢

### 3. **交易槽位限制**
```yaml
transaction_slots: 10000            # 只能处理 10000 笔并发
```
**影响**: 高并发时交易被拒绝

### 4. **数据库连接不足**
```yaml
max_connections: 200                # 只有 200 个连接
```
**影响**: 高并发时数据库成为瓶颈

## 优化方案

### 🚀 关键参数优化

| 参数 | 原值 | 优化值 | 提升 |
|------|------|--------|------|
| **block_commit_deadline_ms** | 3000 | 500 | 6x faster |
| **miniblock_commit_deadline_ms** | 1000 | 200 | 5x faster |
| **transaction_slots** | 10000 | 20000 | 2x capacity |
| **max_gas_per_batch** | 200M | 500M | 2.5x capacity |
| **miniblock_max_payload_size** | 1M | 5M | 5x capacity |
| **sync_interval_ms** | 10 | 5 | 2x faster |
| **max_connections** | 200 | 500 | 2.5x capacity |
| **cache sizes** | 128MB | 512MB | 4x memory |

### 📈 预期效果

优化后预期性能：
- **TPS**: 10-50 (提升 250-1250倍)
- **成功率**: 95%+ (从 5% 提升到 95%+)
- **延迟**: 1-3秒/笔 (从 25-40秒降到 1-3秒)

## 应用步骤

### 方式一：自动应用（推荐）

```bash
# 1. 应用优化配置
bash scripts/apply_high_tps_config.sh

# 2. 上传到服务器
scp -i ~/zk_gas.pem \
    tmai_ecosystem/chains/tmai_chain/configs/general.yaml \
    ubuntu@54.255.184.251:/home/ubuntu/node/tmai_ecosystem/chains/tmai_chain/configs/

# 3. 重启节点
ssh -i ~/zk_gas.pem ubuntu@54.255.184.251 << 'EOF'
cd /home/ubuntu/node
docker-compose down
docker-compose up -d
EOF

# 4. 等待节点启动（约30秒）
sleep 30

# 5. 检查节点状态
curl http://54.255.184.251:3071/health
```

### 方式二：手动修改

直接编辑 `tmai_ecosystem/chains/tmai_chain/configs/general.yaml`：

```yaml
state_keeper:
  block_commit_deadline_ms: 500          # 改这里
  miniblock_commit_deadline_ms: 200      # 改这里
  transaction_slots: 20000               # 改这里
  max_gas_per_batch: 500000000          # 改这里
  miniblock_max_payload_size: 5000000   # 改这里
  miniblock_seal_queue_capacity: 50     # 改这里

mempool:
  sync_interval_ms: 5                    # 改这里
  delay_interval: 50                     # 改这里
  capacity: 20000000                     # 改这里
  sync_batch_size: 2000                  # 改这里

postgres:
  max_connections: 500                   # 改这里

db:
  experimental:
    state_keeper_db_block_cache_capacity_mb: 512  # 改这里
  merkle_tree:
    block_cache_size_mb: 512             # 改这里
    memtable_capacity_mb: 512            # 改这里
```

## 验证优化效果

### 1. 运行压测

```bash
cd stress-test
npm run seq
```

### 2. 观察指标

优化成功的标志：
- ✅ TPS > 10
- ✅ 成功率 > 90%
- ✅ 平均延迟 < 5秒

### 3. 监控服务器

```bash
# CPU 使用率
ssh -i ~/zk_gas.pem ubuntu@54.255.184.251 "top -bn1 | head -20"

# 内存使用
ssh -i ~/zk_gas.pem ubuntu@54.255.184.251 "free -h"

# Docker 日志
ssh -i ~/zk_gas.pem ubuntu@54.255.184.251 "docker logs tmai-server --tail 100"
```

## 进一步优化

如果 TPS 仍然不够，可以继续调整：

### 1. 更激进的区块封装
```yaml
block_commit_deadline_ms: 200          # 从 500 降到 200
miniblock_commit_deadline_ms: 100      # 从 200 降到 100
```

### 2. 增加并发处理
```yaml
transaction_slots: 50000               # 从 20000 增加到 50000
max_gas_per_batch: 1000000000         # 从 500M 增加到 1B
```

### 3. 数据库优化
```yaml
max_connections: 1000                  # 从 500 增加到 1000
```

### 4. 服务器硬件升级
- CPU: 增加核心数
- 内存: 增加到 16GB+
- 磁盘: 使用 SSD

## 注意事项

### ⚠️ 资源消耗

优化后资源使用会增加：
- **CPU**: +50-100%
- **内存**: +2-4GB
- **磁盘 I/O**: +50%

### ⚠️ L1 Gas 成本

更快的区块封装意味着：
- 更频繁的 L1 交易
- 更高的 L1 gas 成本

### ⚠️ 回滚方案

如果出现问题，快速回滚：

```bash
# 使用备份恢复
BACKUP_FILE=$(ls -t tmai_ecosystem/chains/tmai_chain/configs/backups/general_*.yaml | head -1)
cp $BACKUP_FILE tmai_ecosystem/chains/tmai_chain/configs/general.yaml

# 上传并重启
scp -i ~/zk_gas.pem \
    tmai_ecosystem/chains/tmai_chain/configs/general.yaml \
    ubuntu@54.255.184.251:/home/ubuntu/node/tmai_ecosystem/chains/tmai_chain/configs/

ssh -i ~/zk_gas.pem ubuntu@54.255.184.251 << 'EOF'
cd /home/ubuntu/node
docker-compose restart
EOF
```

## 故障排查

### 问题：节点启动失败

```bash
# 检查日志
ssh -i ~/zk_gas.pem ubuntu@54.255.184.251 "docker logs tmai-server --tail 200"

# 常见原因：
# 1. 配置文件格式错误 - 检查 YAML 语法
# 2. 内存不足 - 降低 cache sizes
# 3. 数据库连接失败 - 检查 PostgreSQL
```

### 问题：TPS 仍然很低

```bash
# 1. 检查是否真的应用了配置
ssh -i ~/zk_gas.pem ubuntu@54.255.184.251 \
    "grep 'block_commit_deadline_ms' /home/ubuntu/node/tmai_ecosystem/chains/tmai_chain/configs/general.yaml"

# 2. 检查服务器资源
ssh -i ~/zk_gas.pem ubuntu@54.255.184.251 "htop"

# 3. 检查数据库性能
ssh -i ~/zk_gas.pem ubuntu@54.255.184.251 \
    "docker exec tmai-postgres psql -U postgres -d zksync_server_bsc_testnet_tmai_chain -c 'SELECT * FROM pg_stat_activity;'"
```

### 问题：交易仍然失败

可能原因：
1. **Nonce 冲突** - 使用顺序测试而不是并发
2. **Gas 不足** - 增加 gasLimit
3. **账户余额不足** - 检查测试账户余额

## 总结

通过这些优化，tMai Chain 的 TPS 应该能从 0.04 提升到 10-50，这是一个 **250-1250倍的性能提升**。

关键是：
1. ✅ 减少区块封装延迟
2. ✅ 增加并发处理能力
3. ✅ 优化内存池同步
4. ✅ 提升数据库性能

优化后再次运行压测，应该能看到显著的性能提升！
