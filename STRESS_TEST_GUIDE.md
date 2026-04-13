# 🔥 tMai Chain Hardhat 压力测试指南

## 快速开始

### 1. 安装依赖

```bash
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
```

### 2. 配置私钥

确保 `.env.tmai` 文件中有测试私钥：

```bash
PRIVATE_KEY=0x你的私钥
```

### 3. 运行测试

#### 方式一：使用脚本（推荐）

```bash
bash scripts/run-stress-test.sh
```

#### 方式二：使用 npm 命令

```bash
# 基础压力测试
npm run test:stress

# 高级压力测试（多轮次、详细报告）
npm run stress
```

#### 方式三：直接使用 Hardhat

```bash
# 基础测试
npx hardhat test test/stress-test.js --network tmaiChain

# 高级测试
npx hardhat run scripts/advanced-stress-test.js --network tmaiChain
```

## 测试内容

### 基础压力测试 (test/stress-test.js)

- ✅ 单次交易延迟测试
- ✅ 批量交易测试 (10笔、50笔)
- ✅ 批量转账测试 (20笔)
- ✅ Gas 消耗测试
- ✅ 极限压力测试 (100笔并发)

### 高级压力测试 (scripts/advanced-stress-test.js)

- 🔥 预热阶段
- 🔥 多轮次测试（默认5轮，每轮50笔）
- 🔥 详细统计报告
- 🔥 TPS、延迟、成功率分析

## 测试报告示例

```
📈 压力测试汇总报告
============================================================

总交易数: 250
成功: 248 (99.20%)
失败: 2 (0.80%)

平均 TPS: 12.45
最高 TPS: 15.23
最低 TPS: 10.87
平均延迟: 4012ms

============================================================

📋 各轮详细数据:

轮次 | 成功率 | TPS   | 延迟(ms)
-----|--------|-------|----------
  1  |  98.0% | 12.34 | 4050.5
  2  | 100.0% | 15.23 | 3280.2
  3  |  98.0% | 11.87 | 4210.8
  4  | 100.0% | 13.45 | 3715.4
  5  | 100.0% | 14.32 | 3490.3
```

## 自定义配置

### 修改测试参数

编辑 `scripts/advanced-stress-test.js`：

```javascript
const config = {
  warmup: 10,      // 预热交易数
  rounds: 5,       // 测试轮数
  txPerRound: 50,  // 每轮交易数
};
```

### 修改网络配置

编辑 `hardhat.config.js`：

```javascript
networks: {
  tmaiChain: {
    url: "http://54.255.184.251:3050",
    chainId: 9720,
    timeout: 60000,  // 调整超时时间
  },
}
```

## 测试合约

压测合约 `test/StressTest.sol` 包含：

- `increment()` - 简单计数器
- `batchIncrement(uint256)` - 批量计数
- `deposit()` - 存款测试
- `withdraw(uint256)` - 提款测试
- `complexOperation(uint256)` - 复杂操作

## 注意事项

1. **余额充足**：确保测试账户有足够的 tMai 支付 gas
2. **网络稳定**：确保能访问 http://54.255.184.251:3050
3. **超时设置**：大量并发可能需要增加 timeout
4. **节点负载**：注意观察节点 CPU/内存使用情况

## 故障排查

### 问题：交易失败率高

```bash
# 检查节点状态
curl http://54.255.184.251:3071/health

# 检查账户余额
npx hardhat run scripts/check-balance.js --network tmaiChain
```

### 问题：连接超时

增加 `hardhat.config.js` 中的 timeout：

```javascript
timeout: 120000,  // 2分钟
```

### 问题：Gas 不足

检查 `.env.tmai` 中的账户余额，或降低并发数。

## 性能优化建议

1. **批量发送**：使用 `Promise.all()` 并发发送
2. **合理间隔**：轮次间增加延迟避免节点过载
3. **监控指标**：实时观察 TPS、延迟、成功率
4. **逐步增压**：从小并发开始，逐步增加

## 更多测试场景

可以扩展测试合约添加：

- ERC20 代币转账
- NFT 铸造
- 复杂的 DeFi 操作
- 跨合约调用
- 事件监听测试

---

**网络信息**

- L2 RPC: http://54.255.184.251:3050
- L2 WebSocket: ws://54.255.184.251:3051
- L2 Health: http://54.255.184.251:3071/health
- Chain ID: 9720
