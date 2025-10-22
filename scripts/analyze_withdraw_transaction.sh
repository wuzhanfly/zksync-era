#!/bin/bash

# 分析提币交易脚本

WITHDRAW_TX_HASH="0x2e014c843cd2160a024d8c390bb3f12754d485c634fec7cfac52b090f60de32a"

echo "🔍 分析提币交易: $WITHDRAW_TX_HASH"
echo "=================================================="

# 检查 ZKsync 节点是否运行
if ! curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   http://localhost:3050 | grep -q "result"; then
    echo "❌ ZKsync 节点未运行，请先启动节点"
    exit 1
fi

echo "📊 交易基本信息:"
echo "================"

# 获取交易详情
echo "查询交易详情..."
TX_DETAILS=$(cast tx $WITHDRAW_TX_HASH --rpc-url http://localhost:3050 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ 交易找到"
    echo "$TX_DETAILS"
    echo ""
    
    # 提取关键信息
    FROM=$(echo "$TX_DETAILS" | grep "from" | awk '{print $2}')
    TO=$(echo "$TX_DETAILS" | grep "to" | awk '{print $2}')
    VALUE=$(echo "$TX_DETAILS" | grep "value" | awk '{print $2}')
    GAS_USED=$(echo "$TX_DETAILS" | grep "gas" | awk '{print $2}')
    BLOCK_NUMBER=$(echo "$TX_DETAILS" | grep "blockNumber" | awk '{print $2}')
    
    echo "📋 提币交易摘要:"
    echo "================"
    echo "发送者: $FROM"
    echo "接收者: $TO"
    echo "金额: $VALUE"
    echo "Gas 使用: $GAS_USED"
    echo "区块号: $BLOCK_NUMBER"
    
else
    echo "❌ 交易未找到，可能原因:"
    echo "1. 交易哈希错误"
    echo "2. 交易在不同的网络上"
    echo "3. 节点未完全同步"
fi

echo ""
echo "🔍 获取交易收据..."

# 获取交易收据
TX_RECEIPT=$(cast receipt $WITHDRAW_TX_HASH --rpc-url http://localhost:3050 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ 交易收据找到"
    echo "$TX_RECEIPT"
    echo ""
    
    # 检查交易状态
    STATUS=$(echo "$TX_RECEIPT" | grep "status" | awk '{print $2}')
    if [ "$STATUS" = "1" ]; then
        echo "✅ 交易执行成功"
    else
        echo "❌ 交易执行失败"
    fi
    
    # 分析日志事件
    echo ""
    echo "📜 交易日志分析:"
    echo "================"
    
    # 查找提币相关事件
    LOGS=$(echo "$TX_RECEIPT" | grep -A 20 "logs:")
    if echo "$LOGS" | grep -q "Withdrawal"; then
        echo "✅ 发现提币事件 (Withdrawal)"
    fi
    
    if echo "$LOGS" | grep -q "L2ToL1Log"; then
        echo "✅ 发现 L2 到 L1 日志事件"
    fi
    
else
    echo "❌ 交易收据未找到"
fi

echo ""
echo "🌉 检查 L1 桥接状态:"
echo "==================="

# 检查是否有对应的 L1 交易
echo "检查 L1 网络上的相关交易..."

# 这里需要 L1 网络的 RPC URL
L1_RPC_URL="http://localhost:8545"  # 假设 L1 在 8545 端口

if curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   $L1_RPC_URL | grep -q "result"; then
    
    echo "✅ L1 网络连接正常"
    
    # 查询 L1 桥接合约的相关事件
    # 这里需要知道具体的桥接合约地址
    echo "查询 L1 桥接合约事件..."
    
    # 示例：查询最近的区块中是否有相关的提币完成事件
    LATEST_BLOCK=$(cast block-number --rpc-url $L1_RPC_URL)
    echo "L1 最新区块: $LATEST_BLOCK"
    
else
    echo "❌ L1 网络连接失败"
    echo "💡 请确保 L1 节点在 $L1_RPC_URL 运行"
fi

echo ""
echo "⏰ 提币时间线分析:"
echo "=================="

if [ -n "$BLOCK_NUMBER" ]; then
    # 获取区块时间戳
    BLOCK_INFO=$(cast block $BLOCK_NUMBER --rpc-url http://localhost:3050 2>/dev/null)
    if [ $? -eq 0 ]; then
        TIMESTAMP=$(echo "$BLOCK_INFO" | grep "timestamp" | awk '{print $2}')
        if [ -n "$TIMESTAMP" ]; then
            # 转换时间戳为可读格式
            READABLE_TIME=$(date -d "@$TIMESTAMP" 2>/dev/null || date -r "$TIMESTAMP" 2>/dev/null)
            echo "提币发起时间: $READABLE_TIME"
            
            # 计算挑战期结束时间 (24小时后)
            CHALLENGE_END=$((TIMESTAMP + 86400))
            CHALLENGE_END_TIME=$(date -d "@$CHALLENGE_END" 2>/dev/null || date -r "$CHALLENGE_END" 2>/dev/null)
            echo "挑战期结束时间: $CHALLENGE_END_TIME"
            
            # 检查是否已过挑战期
            CURRENT_TIME=$(date +%s)
            if [ $CURRENT_TIME -gt $CHALLENGE_END ]; then
                echo "✅ 挑战期已结束，可以完成提币"
                echo "💡 运行完成提币命令: bash scripts/finalize_withdrawal.sh $WITHDRAW_TX_HASH"
            else
                REMAINING=$((CHALLENGE_END - CURRENT_TIME))
                REMAINING_HOURS=$((REMAINING / 3600))
                echo "⏳ 挑战期剩余时间: ${REMAINING_HOURS} 小时"
            fi
        fi
    fi
fi

echo ""
echo "🔧 提币状态检查:"
echo "================"

# 创建提币状态检查函数
check_withdrawal_status() {
    local tx_hash=$1
    
    echo "检查提币状态: $tx_hash"
    
    # 这里可以添加更多的状态检查逻辑
    # 例如查询特定的提币跟踪合约或事件
    
    echo "💡 手动检查步骤:"
    echo "1. 确认 L2 交易已确认"
    echo "2. 等待 24 小时挑战期"
    echo "3. 调用 finalizeWithdrawal 完成提币"
}

check_withdrawal_status $WITHDRAW_TX_HASH

echo ""
echo "💡 有用的命令:"
echo "============="
echo "查看交易详情: cast tx $WITHDRAW_TX_HASH --rpc-url http://localhost:3050"
echo "查看交易收据: cast receipt $WITHDRAW_TX_HASH --rpc-url http://localhost:3050"
echo "检查区块信息: cast block $BLOCK_NUMBER --rpc-url http://localhost:3050"
echo "完成提币: bash scripts/finalize_withdrawal.sh $WITHDRAW_TX_HASH"