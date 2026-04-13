# 🔥 tMai Chain Hardhat 压力测试

独立的 Hardhat 压测项目，避免与主项目的 contracts 目录冲突。

## 快速开始

```bash
cd stress-test

# 1. 安装依赖
npm install

# 2. 快速测试（3轮x20笔，推荐）
npm run quick

# 3. 完整压测（5轮x50笔）
npm run stress

# 4. 基础测试套件
npx hardhat test --network tmaiChain
```

## 配置

确保根目录的 `.env.tmai` 文件包含：

```
DEPLOYER_PRIVATE_KEY=0x你的私钥
# 或
OPERATOR_PRIVATE_KEY=0x你的私钥
```

## 测试内容

### 快速测试 (npm run quick)
- 3笔预热
- 3轮测试，每轮20笔
- 实时显示交易状态
- 约2-3分钟完成

### 完整压测 (npm run stress)
- 10笔预热
- 5轮测试，每轮50笔
- 详细统计报告
- 约10-15分钟完成

### 基础测试套件
- ✅ 单次交易延迟
- ✅ 批量并发 (10/50/100笔)
- ✅ TPS 统计
- ✅ Gas 消耗分析

## 网络信息

- RPC: http://54.255.184.251:3050
- Chain ID: 9720
