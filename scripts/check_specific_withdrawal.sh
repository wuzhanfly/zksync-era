#!/bin/bash

# 检查特定提币交易状态

WITHDRAW_TX_HASH="0x2e014c843cd2160a024d8c390bb3f12754d485c634fec7cfac52b090f60de32a"

echo "🔍 检查提币交易状态"
echo "==================="
echo "交易哈希: $WITHDRAW_TX_HASH"
echo "发送者: 0x69AC695BE0e9f67d9b2e933628039Af1E37f5840"
echo "提币金额: 0.001 ETH"
echo "区块号: 7"
echo ""

# 获取区块 7 的时间戳
echo "📅 获取交易时间信息..."
BLOCK_INFO=$(cast block 7 --rpc-url http://localhost:3050 2>/dev/null)

if [ $? -eq 0 ]; then
    TIMESTAMP=$(echo "$BLOCK_INFO" | grep "timestamp" | awk '{print $2}')
    
    if [ -n "$TIMESTAMP" ]; then
        # 转换为可读时间
        READABLE_TIME=$(date -d "@$TIMESTAMP" 2>/dev/null || date -r "$TIMESTAMP" 2>/dev/null)
        echo "提币发起时间: $READABLE_TIME"
        
        # 计算挑战期结束时间 (24小时)
        CHALLENGE_END=$((TIMESTAMP + 86400))
        CHALLENGE_END_TIME=$(date -d "@$CHALLENGE_END" 2>/dev/null || date -r "$CHALLENGE_END" 2>/dev/null)
        echo "挑战期结束时间: $CHALLENGE_END_TIME"
        
        # 检查当前状态
        CURRENT_TIME=$(date +%s)
        
        if [ $CURRENT_TIME -gt $CHALLENGE_END ]; then
            echo ""
            echo "✅ 挑战期已结束！"
            echo "🎯 可以完成提币到 L1"
            echo ""
            echo "💡 完成提币步骤:"
            echo "================"
            echo "1. 确保 L1 网络正在运行"
            echo "2. 设置私钥环境变量: export PRIVATE_KEY=your_private_key"
            echo "3. 运行完成提币: bash scripts/finalize_withdrawal.sh $WITHDRAW_TX_HASH"
            
        else
            REMAINING=$((CHALLENGE_END - CURRENT_TIME))
            REMAINING_HOURS=$((REMAINING / 3600))
            REMAINING_MINUTES=$(((REMAINING % 3600) / 60))
            
            echo ""
            echo "⏳ 挑战期进行中"
            echo "剩余时间: ${REMAINING_HOURS} 小时 ${REMAINING_MINUTES} 分钟"
            echo ""
            echo "💡 等待期间可以做的事:"
            echo "===================="
            echo "1. 准备 L1 网络环境"
            echo "2. 确保 L1 账户有足够的 Gas 费"
            echo "3. 准备完成提币的私钥"
        fi
        
    else
        echo "❌ 无法获取区块时间戳"
    fi
else
    echo "❌ 无法获取区块信息"
fi

echo ""
echo "🔧 提币交易详情:"
echo "================"
echo "• 这是一笔从 L2 (ZKsync Era) 到 L1 的提币交易"
echo "• 金额: 0.001 ETH"
echo "• 需要等待 24 小时挑战期"
echo "• 挑战期后需要手动调用 finalizeWithdrawal"
echo "• 完成后资金将出现在 L1 账户中"

echo ""
echo "🌐 网络信息:"
echo "==========="
echo "L2 网络 (ZKsync Era): http://localhost:3050"
echo "L1 网络 (以太坊): https://rpc.ankr.com/bsc_testnet_chapel/a948b7471d1af62abb0a6a4af74da3d1b7616df9c666ff566a0d0a0433e7be5c"
echo "链 ID: 9701"

echo ""
echo "💡 有用的命令:"
echo "============="
echo "查看交易: cast tx $WITHDRAW_TX_HASH --rpc-url http://localhost:3050"
echo "查看区块: cast block 7 --rpc-url http://localhost:3050"
echo "检查 L1 余额: cast balance 0x69AC695BE0e9f67d9b2e933628039Af1E37f5840 --rpc-url http://localhost:8545"
echo "完成提币: bash scripts/finalize_withdrawal.sh $WITHDRAW_TX_HASH