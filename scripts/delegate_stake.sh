#!/bin/bash

# 委托质押到验证者

echo "🤝 委托质押到 ZKsync Era 验证者..."

# 参数检查
if [ $# -lt 3 ]; then
    echo "用法: $0 <验证者地址> <委托金额> <委托者私钥>"
    echo "示例: $0 0x1234...5678 500 0xabcd...ef01"
    echo ""
    echo "💡 委托质押说明:"
    echo "================"
    echo "- 委托者不需要运行验证者节点"
    echo "- 将代币委托给现有验证者"
    echo "- 获得验证者收益的分成"
    echo "- 可以随时取消委托"
    exit 1
fi

VALIDATOR_ADDRESS=$1
DELEGATE_AMOUNT=$2
DELEGATOR_PRIVATE_KEY=$3

# 合约地址
STAKING_CONTRACT="${STAKING_CONTRACT:-0x0000000000000000000000000000000000000000}"
REGISTRY_CONTRACT="${REGISTRY_CONTRACT:-0x0000000000000000000000000000000000000000}"

echo "📋 委托信息:"
echo "============"
echo "验证者地址: $VALIDATOR_ADDRESS"
echo "委托金额: $DELEGATE_AMOUNT ETH"
echo "质押合约: $STAKING_CONTRACT"

# 检查合约地址
if [ "$STAKING_CONTRACT" = "0x0000000000000000000000000000000000000000" ]; then
    echo "❌ 请设置 STAKING_CONTRACT 环境变量"
    exit 1
fi

echo ""
echo "🔍 检查验证者状态..."

# 获取委托者地址
DELEGATOR_ADDRESS=$(cast wallet address --private-key $DELEGATOR_PRIVATE_KEY)
echo "委托者地址: $DELEGATOR_ADDRESS"

# 检查验证者信息
echo "查询验证者信息..."
VALIDATOR_INFO=$(cast call $REGISTRY_CONTRACT \
  "getValidatorInfo(address)" \
  $VALIDATOR_ADDRESS \
  --rpc-url http://localhost:3050 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ 验证者已注册"
else
    echo "❌ 验证者未注册或查询失败"
    exit 1
fi

# 检查当前委托金额
echo ""
echo "🔍 检查当前委托状态..."
CURRENT_DELEGATION=$(cast call $STAKING_CONTRACT \
  "getDelegation(address,address)" \
  $DELEGATOR_ADDRESS \
  $VALIDATOR_ADDRESS \
  --rpc-url http://localhost:3050 2>/dev/null)

if [ $? -eq 0 ]; then
    CURRENT_AMOUNT=$(cast from-wei $CURRENT_DELEGATION 2>/dev/null || echo "0")
    echo "当前委托金额: $CURRENT_AMOUNT ETH"
fi

echo ""
echo "💰 执行委托交易..."

# 委托代币
DELEGATE_WEI=$(cast to-wei $DELEGATE_AMOUNT)

cast send $STAKING_CONTRACT \
  "delegate(address)" \
  $VALIDATOR_ADDRESS \
  --value $DELEGATE_WEI \
  --rpc-url http://localhost:3050 \
  --private-key $DELEGATOR_PRIVATE_KEY

if [ $? -eq 0 ]; then
    echo "✅ 委托成功！"
    echo ""
    echo "📊 委托详情:"
    echo "============"
    echo "委托者: $DELEGATOR_ADDRESS"
    echo "验证者: $VALIDATOR_ADDRESS"
    echo "委托金额: $DELEGATE_AMOUNT ETH"
    echo ""
    echo "🎯 预期收益:"
    echo "============"
    echo "- 参与验证者的区块奖励分成"
    echo "- 收益率取决于验证者表现"
    echo "- 承担验证者的惩罚风险"
    echo ""
    echo "🔍 查询命令:"
    echo "============"
    echo "查询委托: cast call $STAKING_CONTRACT 'getDelegation(address,address)' $DELEGATOR_ADDRESS $VALIDATOR_ADDRESS --rpc-url http://localhost:3050"
    echo "查询收益: cast call $STAKING_CONTRACT 'getRewards(address,address)' $DELEGATOR_ADDRESS $VALIDATOR_ADDRESS --rpc-url http://localhost:3050"
    echo ""
    echo "📤 取消委托:"
    echo "============"
    echo "bash scripts/undelegate_stake.sh $VALIDATOR_ADDRESS <取消金额> $DELEGATOR_PRIVATE_KEY"
else
    echo "❌ 委托失败，请检查参数和余额"
fi