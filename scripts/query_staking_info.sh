#!/bin/bash

# 查询质押信息

echo "📊 查询 ZKsync Era 质押信息..."

# 合约地址
STAKING_CONTRACT="${STAKING_CONTRACT:-0x0000000000000000000000000000000000000000}"
REGISTRY_CONTRACT="${REGISTRY_CONTRACT:-0x0000000000000000000000000000000000000000}"

if [ "$STAKING_CONTRACT" = "0x0000000000000000000000000000000000000000" ]; then
    echo "❌ 请设置合约地址环境变量:"
    echo "export STAKING_CONTRACT=<质押合约地址>"
    echo "export REGISTRY_CONTRACT=<注册合约地址>"
    exit 1
fi

echo "📋 合约信息:"
echo "============"
echo "质押合约: $STAKING_CONTRACT"
echo "注册合约: $REGISTRY_CONTRACT"

echo ""
echo "🏦 查询所有验证者..."

# 查询验证者委员会
VALIDATORS=$(cast call $REGISTRY_CONTRACT \
  "getValidatorCommittee()" \
  --rpc-url http://localhost:3050 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ 验证者委员会查询成功"
    # 这里需要解析返回的数据
else
    echo "❌ 无法查询验证者委员会"
fi

echo ""
echo "💰 查询总质押信息..."

# 查询总质押金额
TOTAL_STAKED=$(cast call $STAKING_CONTRACT \
  "getTotalStaked()" \
  --rpc-url http://localhost:3050 2>/dev/null)

if [ $? -eq 0 ]; then
    TOTAL_ETH=$(cast from-wei $TOTAL_STAKED 2>/dev/null || echo "0")
    echo "总质押金额: $TOTAL_ETH ETH"
fi

# 查询活跃验证者数量
ACTIVE_VALIDATORS=$(cast call $REGISTRY_CONTRACT \
  "getActiveValidatorCount()" \
  --rpc-url http://localhost:3050 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "活跃验证者: $ACTIVE_VALIDATORS 个"
fi

echo ""
echo "📈 查询质押奖励信息..."

# 查询年化收益率
APY=$(cast call $STAKING_CONTRACT \
  "getCurrentAPY()" \
  --rpc-url http://localhost:3050 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "当前年化收益率: $APY%"
fi

# 如果提供了地址参数，查询特定地址的质押信息
if [ $# -ge 1 ]; then
    USER_ADDRESS=$1
    echo ""
    echo "👤 查询用户质押信息: $USER_ADDRESS"
    echo "=================================="
    
    # 查询用户总质押
    USER_TOTAL_STAKE=$(cast call $STAKING_CONTRACT \
      "getTotalStake(address)" \
      $USER_ADDRESS \
      --rpc-url http://localhost:3050 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        USER_STAKE_ETH=$(cast from-wei $USER_TOTAL_STAKE 2>/dev/null || echo "0")
        echo "总质押金额: $USER_STAKE_ETH ETH"
    fi
    
    # 查询用户奖励
    USER_REWARDS=$(cast call $STAKING_CONTRACT \
      "getTotalRewards(address)" \
      $USER_ADDRESS \
      --rpc-url http://localhost:3050 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        USER_REWARDS_ETH=$(cast from-wei $USER_REWARDS 2>/dev/null || echo "0")
        echo "累计奖励: $USER_REWARDS_ETH ETH"
    fi
    
    # 查询待提取奖励
    PENDING_REWARDS=$(cast call $STAKING_CONTRACT \
      "getPendingRewards(address)" \
      $USER_ADDRESS \
      --rpc-url http://localhost:3050 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        PENDING_ETH=$(cast from-wei $PENDING_REWARDS 2>/dev/null || echo "0")
        echo "待提取奖励: $PENDING_ETH ETH"
    fi
    
    echo ""
    echo "📋 用户委托详情:"
    echo "================"
    
    # 这里需要遍历所有验证者查询委托情况
    # 简化版本，假设有3个验证者
    for i in {1..3}; do
        VALIDATOR_ADDR="0x$(printf '%040d' $i)"  # 示例地址
        DELEGATION=$(cast call $STAKING_CONTRACT \
          "getDelegation(address,address)" \
          $USER_ADDRESS \
          $VALIDATOR_ADDR \
          --rpc-url http://localhost:3050 2>/dev/null)
        
        if [ $? -eq 0 ] && [ "$DELEGATION" != "0" ]; then
            DELEGATION_ETH=$(cast from-wei $DELEGATION 2>/dev/null || echo "0")
            echo "验证者 $i: $DELEGATION_ETH ETH"
        fi
    done
fi

echo ""
echo "💡 有用的命令:"
echo "============="
echo "查询特定用户: $0 <用户地址>"
echo "委托质押: bash scripts/delegate_stake.sh <验证者> <金额> <私钥>"
echo "取消委托: bash scripts/undelegate_stake.sh <验证者> <金额> <私钥>"
echo "添加验证者: bash scripts/add_new_validator.sh <名称> <权重> <端口>"