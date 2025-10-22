#!/bin/bash

# 取消委托质押

echo "📤 取消委托质押..."

# 参数检查
if [ $# -lt 3 ]; then
    echo "用法: $0 <验证者地址> <取消金额> <委托者私钥>"
    echo "示例: $0 0x1234...5678 200 0xabcd...ef01"
    echo ""
    echo "💡 取消委托说明:"
    echo "================"
    echo "- 可以部分或全部取消委托"
    echo "- 可能有解锁期限制"
    echo "- 取消后停止获得收益"
    exit 1
fi

VALIDATOR_ADDRESS=$1
UNDELEGATE_AMOUNT=$2
DELEGATOR_PRIVATE_KEY=$3

# 合约地址
STAKING_CONTRACT="${STAKING_CONTRACT:-0x0000000000000000000000000000000000000000}"

echo "📋 取消委托信息:"
echo "================"
echo "验证者地址: $VALIDATOR_ADDRESS"
echo "取消金额: $UNDELEGATE_AMOUNT ETH"

# 获取委托者地址
DELEGATOR_ADDRESS=$(cast wallet address --private-key $DELEGATOR_PRIVATE_KEY)
echo "委托者地址: $DELEGATOR_ADDRESS"

echo ""
echo "🔍 检查当前委托状态..."

# 查询当前委托金额
CURRENT_DELEGATION=$(cast call $STAKING_CONTRACT \
  "getDelegation(address,address)" \
  $DELEGATOR_ADDRESS \
  $VALIDATOR_ADDRESS \
  --rpc-url http://localhost:3050 2>/dev/null)

if [ $? -eq 0 ]; then
    CURRENT_AMOUNT=$(cast from-wei $CURRENT_DELEGATION 2>/dev/null || echo "0")
    echo "当前委托金额: $CURRENT_AMOUNT ETH"
    
    # 检查取消金额是否超过委托金额
    if (( $(echo "$UNDELEGATE_AMOUNT > $CURRENT_AMOUNT" | bc -l) )); then
        echo "❌ 取消金额超过当前委托金额"
        exit 1
    fi
else
    echo "❌ 无法查询委托状态"
    exit 1
fi

# 查询解锁期
echo ""
echo "🔍 检查解锁期限制..."
UNLOCK_TIME=$(cast call $STAKING_CONTRACT \
  "getUnlockTime(address,address)" \
  $DELEGATOR_ADDRESS \
  $VALIDATOR_ADDRESS \
  --rpc-url http://localhost:3050 2>/dev/null)

if [ $? -eq 0 ] && [ "$UNLOCK_TIME" != "0" ]; then
    CURRENT_TIME=$(date +%s)
    if [ "$UNLOCK_TIME" -gt "$CURRENT_TIME" ]; then
        UNLOCK_DATE=$(date -d "@$UNLOCK_TIME" '+%Y-%m-%d %H:%M:%S')
        echo "⚠️  解锁时间: $UNLOCK_DATE"
        echo "还需等待 $((UNLOCK_TIME - CURRENT_TIME)) 秒"
    else
        echo "✅ 已过解锁期，可以取消委托"
    fi
fi

echo ""
echo "📤 执行取消委托交易..."

# 取消委托
UNDELEGATE_WEI=$(cast to-wei $UNDELEGATE_AMOUNT)

cast send $STAKING_CONTRACT \
  "undelegate(address,uint256)" \
  $VALIDATOR_ADDRESS \
  $UNDELEGATE_WEI \
  --rpc-url http://localhost:3050 \
  --private-key $DELEGATOR_PRIVATE_KEY

if [ $? -eq 0 ]; then
    echo "✅ 取消委托成功！"
    echo ""
    echo "📊 操作详情:"
    echo "============"
    echo "委托者: $DELEGATOR_ADDRESS"
    echo "验证者: $VALIDATOR_ADDRESS"
    echo "取消金额: $UNDELEGATE_AMOUNT ETH"
    echo ""
    echo "⏰ 资金状态:"
    echo "============"
    echo "- 资金可能需要等待解锁期"
    echo "- 解锁后可以提取到钱包"
    echo "- 停止获得该部分的收益"
    echo ""
    echo "🔍 查询命令:"
    echo "============"
    echo "查询剩余委托: cast call $STAKING_CONTRACT 'getDelegation(address,address)' $DELEGATOR_ADDRESS $VALIDATOR_ADDRESS --rpc-url http://localhost:3050"
    echo "查询待提取: cast call $STAKING_CONTRACT 'getPendingWithdrawal(address)' $DELEGATOR_ADDRESS --rpc-url http://localhost:3050"
else
    echo "❌ 取消委托失败，请检查参数和解锁期"
fi