#!/bin/bash

# 测试从 L2 提币到 L1 的脚本

set -e

echo "💸 测试从 L2 提币 0.01 ETH 到 L1..."

# 配置参数
ADDRESS="0x69AC695BE0e9f67d9b2e933628039Af1E37f5840"
PRIVATE_KEY="f778138bf30a0e6eea7eba238c474f082bd0a149a38031c3bf8062fdbdaf80da"
WITHDRAW_AMOUNT="0.001"
L1_RPC="https://rpc.ankr.com/bsc_testnet_chapel/a948b7471d1af62abb0a6a4af74da3d1b7616df9c666ff566a0d0a0433e7be5c"
L2_RPC="http://localhost:3050"

echo "📋 提币参数:"
echo "============"
echo "地址: $ADDRESS"
echo "提币金额: $WITHDRAW_AMOUNT ETH"
echo "L1 RPC: $L1_RPC"
echo "L2 RPC: $L2_RPC"

# 检查提币前的余额
echo ""
echo "💰 提币前余额检查:"
echo "=================="

echo "🔍 检查 L2 余额..."
L2_BALANCE_BEFORE=$(cast balance $ADDRESS --rpc-url $L2_RPC 2>/dev/null || echo "查询失败")
if [ "$L2_BALANCE_BEFORE" != "查询失败" ]; then
    L2_BALANCE_ETH=$(echo "scale=18; $L2_BALANCE_BEFORE / 1000000000000000000" | bc -l)
    echo "L2 余额: $L2_BALANCE_ETH ETH ($L2_BALANCE_BEFORE wei)"
else
    echo "❌ L2 余额查询失败"
    exit 1
fi

echo ""
echo "🔍 检查 L1 余额..."
L1_BALANCE_BEFORE=$(cast balance $ADDRESS --rpc-url $L1_RPC 2>/dev/null || echo "查询失败")
if [ "$L1_BALANCE_BEFORE" != "查询失败" ]; then
    L1_BALANCE_ETH=$(echo "scale=18; $L1_BALANCE_BEFORE / 1000000000000000000" | bc -l)
    echo "L1 余额: $L1_BALANCE_ETH ETH ($L1_BALANCE_BEFORE wei)"
else
    echo "❌ L1 余额查询失败"
    exit 1
fi

# 检查是否有足够余额
WITHDRAW_AMOUNT_WEI=$(echo "$WITHDRAW_AMOUNT * 1000000000000000000" | bc -l | cut -d'.' -f1)
if [ $L2_BALANCE_BEFORE -lt $WITHDRAW_AMOUNT_WEI ]; then
    echo "❌ L2 余额不足，无法提币 $WITHDRAW_AMOUNT ETH"
    echo "当前余额: $L2_BALANCE_ETH ETH"
    echo "需要余额: $WITHDRAW_AMOUNT ETH"
    exit 1
fi

echo "✅ L2 余额充足，可以进行提币"

# 执行提币操作
echo ""
echo "🚀 执行提币操作..."
echo "=================="

echo "命令: node /home/wuzhanfly/git/zksync-cli/bin/index.js bridge withdraw --chain in-memory-node --amount $WITHDRAW_AMOUNT --to $ADDRESS --pk $PRIVATE_KEY --l1-rpc $L1_RPC --rpc $L2_RPC"

# 实际执行提币
node /home/wuzhanfly/git/zksync-cli/bin/index.js bridge withdraw \
    --chain in-memory-node \
    --amount $WITHDRAW_AMOUNT \
    --to $ADDRESS \
    --pk $PRIVATE_KEY \
    --l1-rpc $L1_RPC \
    --rpc $L2_RPC

WITHDRAW_EXIT_CODE=$?

if [ $WITHDRAW_EXIT_CODE -eq 0 ]; then
    echo "✅ 提币命令执行成功"
else
    echo "❌ 提币命令执行失败，退出码: $WITHDRAW_EXIT_CODE"
    exit $WITHDRAW_EXIT_CODE
fi

# 等待一段时间让交易处理
echo ""
echo "⏳ 等待交易处理 (10秒)..."
sleep 10

# 检查提币后的余额
echo ""
echo "💰 提币后余额检查:"
echo "=================="

echo "🔍 检查 L2 余额..."
L2_BALANCE_AFTER=$(cast balance $ADDRESS --rpc-url $L2_RPC 2>/dev/null || echo "查询失败")
if [ "$L2_BALANCE_AFTER" != "查询失败" ]; then
    L2_BALANCE_AFTER_ETH=$(echo "scale=18; $L2_BALANCE_AFTER / 1000000000000000000" | bc -l)
    echo "L2 余额: $L2_BALANCE_AFTER_ETH ETH ($L2_BALANCE_AFTER wei)"
    
    # 计算L2余额变化
    L2_BALANCE_CHANGE=$((L2_BALANCE_AFTER - L2_BALANCE_BEFORE))
    L2_CHANGE_ETH=$(echo "scale=18; $L2_BALANCE_CHANGE / 1000000000000000000" | bc -l)
    echo "L2 余额变化: $L2_CHANGE_ETH ETH ($L2_BALANCE_CHANGE wei)"
else
    echo "❌ L2 余额查询失败"
fi

echo ""
echo "🔍 检查 L1 余额..."
L1_BALANCE_AFTER=$(cast balance $ADDRESS --rpc-url $L1_RPC 2>/dev/null || echo "查询失败")
if [ "$L1_BALANCE_AFTER" != "查询失败" ]; then
    L1_BALANCE_AFTER_ETH=$(echo "scale=18; $L1_BALANCE_AFTER / 1000000000000000000" | bc -l)
    echo "L1 余额: $L1_BALANCE_AFTER_ETH ETH ($L1_BALANCE_AFTER wei)"
    
    # 计算L1余额变化
    L1_BALANCE_CHANGE=$((L1_BALANCE_AFTER - L1_BALANCE_BEFORE))
    L1_CHANGE_ETH=$(echo "scale=18; $L1_BALANCE_CHANGE / 1000000000000000000" | bc -l)
    echo "L1 余额变化: $L1_CHANGE_ETH ETH ($L1_BALANCE_CHANGE wei)"
else
    echo "❌ L1 余额查询失败"
fi

# 分析结果
echo ""
echo "📊 提币结果分析:"
echo "================"

if [ "$L2_BALANCE_AFTER" != "查询失败" ] && [ "$L1_BALANCE_AFTER" != "查询失败" ]; then
    echo "提币金额: $WITHDRAW_AMOUNT ETH"
    echo "L2 减少: $(echo $L2_CHANGE_ETH | tr -d '-') ETH"
    echo "L1 增加: $L1_CHANGE_ETH ETH"
    
    # 检查是否成功
    if [ $L2_BALANCE_CHANGE -lt 0 ]; then
        echo "✅ L2 余额已减少，提币请求已发送"
    else
        echo "⚠️  L2 余额未减少，可能提币失败或延迟"
    fi
    
    if [ $L1_BALANCE_CHANGE -gt 0 ]; then
        echo "✅ L1 余额已增加，提币已到账"
    else
        echo "⏳ L1 余额未增加，可能需要等待确认"
        echo "💡 ZKsync 提币通常需要等待挑战期 (约24小时)"
    fi
fi

echo ""
echo "📝 重要说明:"
echo "==========="
echo "1. 🕐 ZKsync 提币有挑战期，通常需要 24 小时才能在 L1 上完成"
echo "2. 🔍 可以通过区块浏览器查看提币状态"
echo "3. 💰 L2 余额立即减少，但 L1 余额需要等待挑战期结束"
echo "4. ⚡ 这是 ZKsync 安全机制的一部分"

echo ""
echo "🔍 监控建议:"
echo "==========="
echo "定期检查余额变化:"
echo "L2: cast balance $ADDRESS --rpc-url $L2_RPC"
echo "L1: cast balance $ADDRESS --rpc-url $L1_RPC"

echo ""
echo "🎯 提币测试完成！"