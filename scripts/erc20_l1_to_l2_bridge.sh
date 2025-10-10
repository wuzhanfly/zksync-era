#!/bin/bash

# ERC20 代币 L1 到 L2 跨链脚本
# 支持任意 ERC20 代币从 BSC 测试网跨链到 ZKsync Era L2

set -e

echo "🪙 ERC20 代币 L1→L2 跨链"
echo "======================="

# 配置
PRIVATE_KEY="3e6767c091986dbbd24e0d01ac5a65abdfb9ee75cae3da3bdf6e79f3b7564845"
WALLET_ADDRESS="0x2B9952Dfb901Acc336ac133a7bf270c8bCE2dff8"
BSC_RPC="https://rpc.ankr.com/bsc_testnet_chapel/a948b7471d1af62abb0a6a4af74da3d1b7616df9c666ff566a0d0a0433e7be5c"
L2_RPC="http://localhost:3050"

# 合约地址
BRIDGEHUB="0x375afbf83b81aded6a484591aa6db8c4f5ce0d1d"
SHARED_BRIDGE="0xda6835ef9a5f239fa14df32eb606cf2d55b3643b"
L1_ASSET_ROUTER="0xda6835ef9a5f239fa14df32eb606cf2d55b3643b"  # 通常与 Shared Bridge 相同

CHAIN_ID="9701"

# ERC20 代币配置 (示例：USDT 测试网代币)
TOKEN_ADDRESS="0x337610d27c682E347C9cD60BD4b3b107C9d34dDd"  # BSC 测试网 USDT
TOKEN_AMOUNT="10"  # 10 USDT
TOKEN_DECIMALS="18"

echo "📋 ERC20 跨链配置"
echo "================"
echo "代币地址: $TOKEN_ADDRESS"
echo "代币数量: $TOKEN_AMOUNT"
echo "代币精度: $TOKEN_DECIMALS"
echo "目标链 ID: $CHAIN_ID"
echo ""

# 检查代币余额和授权
echo "💰 检查代币状态"
echo "==============="

echo "检查 ERC20 代币余额..."
TOKEN_BALANCE=$(cast call $TOKEN_ADDRESS \
    --rpc-url $BSC_RPC \
    "balanceOf(address)(uint256)" \
    $WALLET_ADDRESS)

echo "当前代币余额: $(cast --to-unit $TOKEN_BALANCE $TOKEN_DECIMALS) tokens"

if [ "$TOKEN_BALANCE" = "0x0" ]; then
    echo "❌ 代币余额为 0，无法进行跨链"
    exit 1
fi

# 检查授权额度
echo "检查代币授权额度..."
ALLOWANCE=$(cast call $TOKEN_ADDRESS \
    --rpc-url $BSC_RPC \
    "allowance(address,address)(uint256)" \
    $WALLET_ADDRESS \
    $SHARED_BRIDGE)

REQUIRED_AMOUNT=$(cast --to-wei $TOKEN_AMOUNT $TOKEN_DECIMALS)

echo "当前授权额度: $(cast --to-unit $ALLOWANCE $TOKEN_DECIMALS) tokens"
echo "需要授权额度: $(cast --to-unit $REQUIRED_AMOUNT $TOKEN_DECIMALS) tokens"

# 如果授权不足，进行授权
if [ "$(cast --to-dec $ALLOWANCE)" -lt "$(cast --to-dec $REQUIRED_AMOUNT)" ]; then
    echo "🔐 授权代币给 Shared Bridge..."
    
    cast send $TOKEN_ADDRESS \
        --rpc-url $BSC_RPC \
        --private-key $PRIVATE_KEY \
        --gas-limit 100000 \
        "approve(address,uint256)" \
        $SHARED_BRIDGE \
        $REQUIRED_AMOUNT && echo "✅ 代币授权成功" || echo "❌ 代币授权失败"
    
    echo "等待授权交易确认..."
    sleep 5
fi

echo ""

# 方法 1: 使用新的 Asset Router 系统
echo "🔄 方法 1: 使用 Asset Router 系统"
echo "==============================="

echo "计算 Asset ID..."
# Asset ID = keccak256(abi.encode(chainId, assetDeploymentTracker, assetData))
# 对于 NTV 资产，assetDeploymentTracker 是 L1 NTV 地址，assetData 是代币地址

ASSET_DATA=$(cast --to-bytes32 $TOKEN_ADDRESS)
echo "Asset Data: $ASSET_DATA"

echo "调用 L1 Asset Router 进行跨链..."

# 构建 requestL2TransactionTwoBridges 调用
# 这需要通过 Bridgehub 调用
echo "通过 Bridgehub 调用 requestL2TransactionTwoBridges..."

# 准备 L2 调用数据
L2_CALLDATA=$(cast calldata "finalizeDeposit(uint256,bytes32,bytes)" \
    $CHAIN_ID \
    $(cast keccak "$(cast abi-encode "(uint256,address,bytes)" $CHAIN_ID $SHARED_BRIDGE $ASSET_DATA)") \
    $(cast abi-encode "(address,uint256,address)" $WALLET_ADDRESS $REQUIRED_AMOUNT $WALLET_ADDRESS))

echo "L2 Calldata: $L2_CALLDATA"

# 调用 Bridgehub
cast send $BRIDGEHUB \
    --rpc-url $BSC_RPC \
    --private-key $PRIVATE_KEY \
    --gas-limit 2000000 \
    "requestL2TransactionTwoBridges((uint256,uint256,uint256,uint256,address,address,address,uint256,bytes,bytes))" \
    "($CHAIN_ID,0,200000,800,$WALLET_ADDRESS,$L1_ASSET_ROUTER,$WALLET_ADDRESS,0,$L2_CALLDATA,0x)" && \
    echo "✅ Asset Router 跨链成功!" || echo "❌ Asset Router 跨链失败"

echo ""

# 方法 2: 使用传统 Shared Bridge
echo "🌉 方法 2: 使用传统 Shared Bridge"
echo "=============================="

echo "调用 Shared Bridge 的 bridgehubDepositBaseToken..."

cast send $SHARED_BRIDGE \
    --rpc-url $BSC_RPC \
    --private-key $PRIVATE_KEY \
    --gas-limit 1500000 \
    "bridgehubDepositBaseToken(uint256,address,address,uint256)" \
    $CHAIN_ID \
    $WALLET_ADDRESS \
    $TOKEN_ADDRESS \
    $REQUIRED_AMOUNT && echo "✅ Shared Bridge 跨链成功!" || echo "❌ Shared Bridge 跨链失败"

echo ""

# 方法 3: 直接调用 ERC20 Bridge (如果存在)
echo "🔗 方法 3: 查找专用 ERC20 Bridge"
echo "============================="

# 尝试查找是否有专用的 ERC20 Bridge
echo "检查是否存在专用 ERC20 Bridge..."

# 这里可以添加特定 ERC20 Bridge 的逻辑
echo "ℹ️  当前使用通用桥接方案"

echo ""

# 检查跨链结果
echo "🔍 检查跨链结果"
echo "==============="

echo "等待交易处理..."
sleep 20

echo "检查 L1 代币余额变化..."
NEW_L1_BALANCE=$(cast call $TOKEN_ADDRESS \
    --rpc-url $BSC_RPC \
    "balanceOf(address)(uint256)" \
    $WALLET_ADDRESS)

echo "新的 L1 余额: $(cast --to-unit $NEW_L1_BALANCE $TOKEN_DECIMALS) tokens"

echo "尝试检查 L2 代币余额..."
# 注意：L2 上的代币地址可能不同，需要通过桥接映射查询
echo "ℹ️  L2 代币地址需要通过桥接合约查询"

# 检查 L2 ETH 余额（gas 费用）
if curl -s -X POST -H "Content-Type: application/json" \
   -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'$WALLET_ADDRESS'","latest"],"id":1}' \
   $L2_RPC | grep -q "result"; then
    L2_ETH_BALANCE=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'$WALLET_ADDRESS'","latest"],"id":1}' \
        $L2_RPC | jq -r '.result')
    echo "L2 ETH 余额: $(cast --to-unit $L2_ETH_BALANCE ether) ETH"
else
    echo "❌ 无法连接到 L2"
fi

echo ""
echo "📋 ERC20 跨链完成"
echo "================"
echo "跨链状态检查："
echo "1. L1 代币余额是否减少"
echo "2. L2 网络是否可访问"
echo "3. 等待 L2 代币到账（可能需要几分钟）"
echo ""
echo "💡 提示："
echo "- L2 上的代币地址可能与 L1 不同"
echo "- 可以通过桥接合约查询 L2 代币地址"
echo "- 首次跨链可能需要部署 L2 代币合约"