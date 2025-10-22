#!/bin/bash

# 完成提币脚本

if [ $# -eq 0 ]; then
    echo "用法: $0 <withdrawal_tx_hash>"
    echo "示例: $0 0x2e014c843cd2160a024d8c390bb3f12754d485c634fec7cfac52b090f60de32a"
    exit 1
fi

WITHDRAW_TX_HASH=$1

echo "🌉 完成提币交易: $WITHDRAW_TX_HASH"
echo "=================================="

# 检查 L1 和 L2 网络连接
L1_RPC_URL="https://rpc.ankr.com/bsc_testnet_chapel/a948b7471d1af62abb0a6a4af74da3d1b7616df9c666ff566a0d0a0433e7be5c"
L2_RPC_URL="http://localhost:3050"

echo "🔍 检查网络连接..."

# 检查 L2 网络
if ! curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   $L2_RPC_URL | grep -q "result"; then
    echo "❌ L2 网络 ($L2_RPC_URL) 连接失败"
    exit 1
fi
echo "✅ L2 网络连接正常"

# 检查 L1 网络
if ! curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   $L1_RPC_URL | grep -q "result"; then
    echo "❌ L1 网络 ($L1_RPC_URL) 连接失败"
    echo "💡 请确保 L1 节点正在运行"
    exit 1
fi
echo "✅ L1 网络连接正常"

echo ""
echo "📊 获取提币交易信息..."

# 获取 L2 交易详情
TX_RECEIPT=$(cast receipt $WITHDRAW_TX_HASH --rpc-url $L2_RPC_URL 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ 无法获取交易收据"
    echo "请检查交易哈希是否正确"
    exit 1
fi

echo "✅ 交易收据获取成功"

# 提取关键信息
BLOCK_NUMBER=$(echo "$TX_RECEIPT" | grep "blockNumber" | awk '{print $2}')
TX_INDEX=$(echo "$TX_RECEIPT" | grep "transactionIndex" | awk '{print $2}')

echo "区块号: $BLOCK_NUMBER"
echo "交易索引: $TX_INDEX"

echo ""
echo "⏰ 检查挑战期状态..."

# 获取区块时间戳
BLOCK_INFO=$(cast block $BLOCK_NUMBER --rpc-url $L2_RPC_URL 2>/dev/null)
TIMESTAMP=$(echo "$BLOCK_INFO" | grep "timestamp" | awk '{print $2}')

if [ -n "$TIMESTAMP" ]; then
    CHALLENGE_END=$((TIMESTAMP + 86400))  # 24小时后
    CURRENT_TIME=$(date +%s)
    
    if [ $CURRENT_TIME -lt $CHALLENGE_END ]; then
        REMAINING=$((CHALLENGE_END - CURRENT_TIME))
        REMAINING_HOURS=$((REMAINING / 3600))
        echo "⏳ 挑战期未结束，剩余 ${REMAINING_HOURS} 小时"
        echo "请等待挑战期结束后再完成提币"
        exit 1
    fi
    
    echo "✅ 挑战期已结束，可以完成提币"
else
    echo "⚠️  无法获取区块时间戳，继续尝试完成提币"
fi

echo ""
echo "🔧 准备完成提币..."

# 这里需要实际的 L1 桥接合约地址
# 在实际部署中，这些地址会在部署时确定
L1_BRIDGE_CONTRACT="0x0000000000000000000000000000000000000000"  # 需要实际地址
PRIVATE_KEY="${PRIVATE_KEY:-0x0000000000000000000000000000000000000000000000000000000000000000}"  # 需要实际私钥

if [ "$L1_BRIDGE_CONTRACT" = "0x0000000000000000000000000000000000000000" ]; then
    echo "❌ L1 桥接合约地址未配置"
    echo "💡 请在脚本中设置正确的 L1_BRIDGE_CONTRACT 地址"
    exit 1
fi

if [ "$PRIVATE_KEY" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "❌ 私钥未配置"
    echo "💡 请设置环境变量 PRIVATE_KEY 或在脚本中配置"
    exit 1
fi

echo "L1 桥接合约: $L1_BRIDGE_CONTRACT"

echo ""
echo "🚀 执行完成提币交易..."

# 构造完成提币的调用
# 这是一个示例，实际的函数签名可能不同
echo "调用 finalizeWithdrawal 函数..."

# 示例调用 (需要根据实际合约接口调整)
FINALIZE_TX=$(cast send $L1_BRIDGE_CONTRACT \
    "finalizeWithdrawal(uint256,uint256,uint16,bytes,bytes32[])" \
    $BLOCK_NUMBER \
    $TX_INDEX \
    0 \
    "0x" \
    "[]" \
    --rpc-url $L1_RPC_URL \
    --private-key $PRIVATE_KEY \
    2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ 完成提币交易已发送"
    echo "L1 交易哈希: $FINALIZE_TX"
    
    echo ""
    echo "⏳ 等待 L1 交易确认..."
    
    # 等待交易确认
    sleep 10
    
    # 检查交易状态
    L1_RECEIPT=$(cast receipt $FINALIZE_TX --rpc-url $L1_RPC_URL 2>/dev/null)
    if [ $? -eq 0 ]; then
        STATUS=$(echo "$L1_RECEIPT" | grep "status" | awk '{print $2}')
        if [ "$STATUS" = "1" ]; then
            echo "🎉 提币完成成功！"
            echo "资金已转移到 L1 账户"
        else
            echo "❌ 提币完成失败"
            echo "请检查交易详情: cast receipt $FINALIZE_TX --rpc-url $L1_RPC_URL"
        fi
    else
        echo "⏳ 交易仍在处理中..."
        echo "请稍后检查: cast receipt $FINALIZE_TX --rpc-url $L1_RPC_URL"
    fi
    
else
    echo "❌ 完成提币交易失败"
    echo "可能的原因:"
    echo "1. 挑战期未结束"
    echo "2. 提币已经完成"
    echo "3. 合约地址或参数错误"
    echo "4. Gas 费用不足"
fi

echo ""
echo "💡 有用的命令:"
echo "============="
echo "检查 L1 交易: cast receipt $FINALIZE_TX --rpc-url $L1_RPC_URL"
echo "查看 L1 余额: cast balance <address> --rpc-url $L1_RPC_URL"
echo "重新分析提币: bash scripts/analyze_withdraw_transaction.sh $WITHDRAW_TX_HASH"