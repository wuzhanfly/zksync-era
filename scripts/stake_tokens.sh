#!/bin/bash

# 质押代币到验证者

echo "💰 质押代币到 ZKsync Era 验证者..."

# 参数检查
if [ $# -lt 3 ]; then
    echo "用法: $0 <验证者地址> <质押金额> <质押者私钥>"
    echo "示例: $0 0x1234...5678 1000 0xabcd...ef01"
    exit 1
fi

VALIDATOR_ADDRESS=$1
STAKE_AMOUNT=$2
STAKER_PRIVATE_KEY=$3

# 合约地址 (需要设置)
STAKING_CONTRACT="${STAKING_CONTRACT:-0x0000000000000000000000000000000000000000}"
REGISTRY_CONTRACT="${REGISTRY_CONTRACT:-0x0000000000000000000000000000000000000000}"

echo "📋 质押信息:"
echo "============"
echo "验证者地址: $VALIDATOR_ADDRESS"
echo "质押金额: $STAKE_AMOUNT ETH"
echo "质押合约: $STAKING_CONTRACT"
echo "注册合约: $REGISTRY_CONTRACT"

# 检查合约地址
if [ "$STAKING_CONTRACT" = "0x0000000000000000000000000000000000000000" ]; then
    echo "❌ 请设置 STAKING_CONTRACT 环境变量"
    echo "export STAKING_CONTRACT=<质押合约地址>"
    exit 1
fi

echo ""
echo "🔍 检查验证者状态..."

# 检查验证者是否已注册
VALIDATOR_INFO=$(cast call $REGISTRY_CONTRACT \
  "validators(address)" \
  $VALIDATOR_ADDRESS \
  --rpc-url http://localhost:3050 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ 无法查询验证者信息，请检查合约地址和网络连接"
    exit 1
fi

echo "验证者信息: $VALIDATOR_INFO"

echo ""
echo "💰 执行质押交易..."

# 质押代币 (假设质押合约有 stake 函数)
STAKE_WEI=$(cast to-wei $STAKE_AMOUNT)

cast send $STAKING_CONTRACT \
  "stake(address)" \
  $VALIDATOR_ADDRESS \
  --value $STAKE_WEI \
  --rpc-url http://localhost:3050 \
  --private-key $STAKER_PRIVATE_KEY

if [ $? -eq 0 ]; then
    echo "✅ 质押成功！"
    echo ""
    echo "📊 质押详情:"
    echo "============"
    echo "验证者: $VALIDATOR_ADDRESS"
    echo "金额: $STAKE_AMOUNT ETH"
    echo "交易已提交到网络"
    echo ""
    echo "🔍 查询质押状态:"
    echo "================"
    echo "cast call $STAKING_CONTRACT 'getStake(address,address)' <质押者地址> $VALIDATOR_ADDRESS --rpc-url http://localhost:3050"
else
    echo "❌ 质押失败，请检查参数和余额"
fi