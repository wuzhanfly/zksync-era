#!/bin/bash

# 使用 ZKsync CLI 进行 L1 到 L2 跨链
# 配置自定义 BSC 测试网环境

set -e

echo "🔧 ZKsync CLI 跨链配置"
echo "====================="

# 配置
PRIVATE_KEY="${1:-3e6767c091986dbbd24e0d01ac5a65abdfb9ee75cae3da3bdf6e79f3b7564845}"
AMOUNT="${2:-0.001}"
RECIPIENT="${3:-0x2B9952Dfb901Acc336ac133a7bf270c8bCE2dff8}"

# 网络配置
BSC_RPC="https://rpc.ankr.com/bsc_testnet_chapel/a948b7471d1af62abb0a6a4af74da3d1b7616df9c666ff566a0d0a0433e7be5c"
L2_RPC="http://localhost:3050"

echo "💰 跨链参数"
echo "==========="
echo "金额: $AMOUNT BNB"
echo "接收地址: $RECIPIENT"
echo "L1 RPC: $BSC_RPC"
echo "L2 RPC: $L2_RPC"
echo ""

# 方法 1: 使用 dockerized-node 配置
echo "🐳 方法 1: 使用 dockerized-node 配置"
echo "================================="

echo "尝试使用 dockerized-node 预设..."
npx zksync-cli bridge deposit \
    --chain dockerized-node \
    --amount $AMOUNT \
    --to $RECIPIENT \
    --pk $PRIVATE_KEY \
    --l1-rpc $BSC_RPC \
    --rpc $L2_RPC && echo "✅ dockerized-node 方法成功!" || echo "❌ dockerized-node 方法失败"

echo ""

# 方法 2: 使用 in-memory-node 配置
echo "💾 方法 2: 使用 in-memory-node 配置"
echo "================================="

echo "尝试使用 in-memory-node 预设..."
npx zksync-cli bridge deposit \
    --chain in-memory-node \
    --amount $AMOUNT \
    --to $RECIPIENT \
    --pk $PRIVATE_KEY \
    --l1-rpc $BSC_RPC \
    --rpc $L2_RPC && echo "✅ in-memory-node 方法成功!" || echo "❌ in-memory-node 方法失败"

echo ""

# 方法 3: 创建自定义网络配置
echo "⚙️ 方法 3: 创建自定义网络配置"
echo "============================"

# 创建 ZKsync CLI 配置文件
CONFIG_DIR="$HOME/.config/zksync-cli"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/config.json" << EOF
{
  "networks": {
    "bsc-testnet-l2": {
      "name": "BSC Testnet L2",
      "rpcUrl": "$L2_RPC",
      "l1Network": {
        "name": "BSC Testnet",
        "rpcUrl": "$BSC_RPC",
        "chainId": 97
      },
      "chainId": 9701,
      "bridgeAddress": "0xda6835ef9a5f239fa14df32eb606cf2d55b3643b",
      "l1BridgeAddress": "0xda6835ef9a5f239fa14df32eb606cf2d55b3643b"
    }
  }
}
EOF

echo "✅ 自定义配置已创建: $CONFIG_DIR/config.json"

# 尝试使用自定义配置
echo "使用自定义网络配置进行跨链..."
npx zksync-cli bridge deposit \
    --chain bsc-testnet-l2 \
    --amount $AMOUNT \
    --to $RECIPIENT \
    --pk $PRIVATE_KEY && echo "✅ 自定义配置方法成功!" || echo "❌ 自定义配置方法失败"

echo ""

# 方法 4: 直接指定所有参数
echo "🎯 方法 4: 直接指定所有参数"
echo "========================="

echo "使用完整参数进行跨链..."
npx zksync-cli bridge deposit \
    --amount $AMOUNT \
    --to $RECIPIENT \
    --pk $PRIVATE_KEY \
    --l1-rpc $BSC_RPC \
    --rpc $L2_RPC && echo "✅ 直接参数方法成功!" || echo "❌ 直接参数方法失败"

echo ""

# 检查结果
echo "🔍 检查跨链结果"
echo "==============="

echo "等待交易处理..."
sleep 20

echo "检查 L2 余额..."
if curl -s -X POST -H "Content-Type: application/json" \
   -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'$RECIPIENT'","latest"],"id":1}' \
   $L2_RPC | grep -q "result"; then
    L2_BALANCE=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'$RECIPIENT'","latest"],"id":1}' \
        $L2_RPC | jq -r '.result')
    echo "L2 余额: $(cast --to-unit $L2_BALANCE ether) ETH"
    
    if [ "$L2_BALANCE" != "0x0" ]; then
        echo "🎉 跨链成功！"
    else
        echo "⏰ 跨链处理中，请稍后再检查"
    fi
else
    echo "❌ 无法连接到 L2"
fi

echo ""
echo "📋 ZKsync CLI 跨链完成"
echo "===================="
echo "如果上述方法都失败，可能的原因："
echo "1. ZKsync CLI 版本不兼容"
echo "2. 自定义网络配置不被支持"
echo "3. 合约地址或网络配置错误"
echo ""
echo "建议使用我们的自定义脚本："
echo "./scripts/quick_l1_to_l2_bridge.sh"