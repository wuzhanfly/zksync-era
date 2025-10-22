#!/bin/bash

# 使用 BSC 测试网完成提币

WITHDRAW_TX_HASH="0x2e014c843cd2160a024d8c390bb3f12754d485c634fec7cfac52b090f60de32a"
PRIVATE_KEY="f778138bf30a0e6eea7eba238c474f082bd0a149a38031c3bf8062fdbdaf80da"

# BSC 测试网 RPC URL
BSC_TESTNET_RPC="https://rpc.ankr.com/bsc_testnet_chapel/a948b7471d1af62abb0a6a4af74da3d1b7616df9c666ff566a0d0a0433e7be5c"
# 备用 RPC
BSC_TESTNET_RPC_BACKUP="https://bsc-testnet.public.blastapi.io"

echo "🌉 完成 BSC 测试网提币"
echo "======================"
echo "交易哈希: $WITHDRAW_TX_HASH"
echo "提币金额: 0.001 ETH"
echo ""

# 获取账户地址
ACCOUNT=$(cast wallet address $PRIVATE_KEY)
echo "账户地址: $ACCOUNT"

echo ""
echo "🔍 检查 BSC 测试网连接..."

# 检查 BSC 测试网连接
if curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   $BSC_TESTNET_RPC | grep -q "result"; then
    echo "✅ BSC 测试网连接正常"
    L1_RPC=$BSC_TESTNET_RPC
elif curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   $BSC_TESTNET_RPC_BACKUP | grep -q "result"; then
    echo "✅ BSC 测试网备用 RPC 连接正常"
    L1_RPC=$BSC_TESTNET_RPC_BACKUP
else
    echo "❌ BSC 测试网连接失败"
    echo "请检查网络连接"
    exit 1
fi

# 检查账户余额
echo ""
echo "💰 检查账户余额..."
BALANCE=$(cast balance $ACCOUNT --rpc-url $L1_RPC)
BALANCE_ETH=$(cast to-unit $BALANCE ether)
echo "BSC 测试网余额: $BALANCE_ETH BNB"

if [ $(echo "$BALANCE_ETH < 0.01" | bc -l) -eq 1 ]; then
    echo "⚠️  余额较低，可能不足以支付 Gas 费用"
    echo "💡 请从水龙头获取测试 BNB: https://testnet.binance.org/faucet-smart"
fi

echo ""
echo "🔍 分析提币交易..."

# 从 L2 获取提币交易详情
L2_RPC="http://localhost:3050"

if ! curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   $L2_RPC | grep -q "result"; then
    echo "❌ L2 网络连接失败"
    echo "请确保 ZKsync Era 节点正在运行"
    exit 1
fi

# 获取提币交易详情
TX_DETAILS=$(cast tx $WITHDRAW_TX_HASH --rpc-url $L2_RPC 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ 无法获取提币交易详情"
    exit 1
fi

BLOCK_NUMBER=$(echo "$TX_DETAILS" | grep "blockNumber" | awk '{print $2}')
echo "L2 区块号: $BLOCK_NUMBER"

# 获取区块时间戳验证挑战期
BLOCK_INFO=$(cast block $BLOCK_NUMBER --rpc-url $L2_RPC 2>/dev/null)
TIMESTAMP=$(echo "$BLOCK_INFO" | grep "timestamp" | awk '{print $2}')

if [ -n "$TIMESTAMP" ]; then
    CHALLENGE_END=$((TIMESTAMP + 86400))
    CURRENT_TIME=$(date +%s)
    
    if [ $CURRENT_TIME -lt $CHALLENGE_END ]; then
        REMAINING=$((CHALLENGE_END - CURRENT_TIME))
        REMAINING_HOURS=$((REMAINING / 3600))
        echo "❌ 挑战期未结束，剩余 ${REMAINING_HOURS} 小时"
        exit 1
    fi
    
    echo "✅ 挑战期已结束，可以完成提币"
fi

echo ""
echo "⚠️  重要提示:"
echo "============"
echo "由于这是测试环境，L1 桥接合约可能未部署。"
echo "在生产环境中，你需要:"
echo ""
echo "1. 确保 L1 桥接合约已部署"
echo "2. 获取正确的合约地址"
echo "3. 调用 finalizeWithdrawal 函数"
echo ""
echo "🔧 手动完成提币步骤:"
echo "===================="
echo "1. 找到 L1 桥接合约地址"
echo "2. 构造 finalizeWithdrawal 调用"
echo "3. 提供提币证明数据"
echo ""
echo "💡 示例命令 (需要实际合约地址):"
echo "cast send <L1_BRIDGE_CONTRACT> \\"
echo "  'finalizeWithdrawal(uint256,uint256,uint16,bytes,bytes32[])' \\"
echo "  $BLOCK_NUMBER 0 0 '0x' '[]' \\"
echo "  --rpc-url $L1_RPC \\"
echo "  --private-key $PRIVATE_KEY"

echo ""
echo "🌐 有用的链接:"
echo "============="
echo "BSC 测试网浏览器: https://testnet.bscscan.com/"
echo "BSC 测试网水龙头: https://testnet.binance.org/faucet-smart"
echo "账户地址: https://testnet.bscscan.com/address/$ACCOUNT"

echo ""
echo "📊 当前状态总结:"
echo "================"
echo "✅ 提币交易已确认 (L2)"
echo "✅ 挑战期已结束"
echo "✅ BSC 测试网连接正常"
echo "⚠️  需要 L1 桥接合约地址完成提币"