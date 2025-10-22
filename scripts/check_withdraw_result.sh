#!/bin/bash

# 检查提币结果的脚本

set -e

ADDRESS="0x69AC695BE0e9f67d9b2e933628039Af1E37f5840"
L2_RPC="http://localhost:3050"
L1_RPC="https://rpc.ankr.com/bsc_testnet_chapel/a948b7471d1af62abb0a6a4af74da3d1b7616df9c666ff566a0d0a0433e7be5c"

echo "💰 提币后余额检查:"
echo "=================="

echo "🔍 L2 余额:"
L2_BALANCE=$(cast balance $ADDRESS --rpc-url $L2_RPC)
L2_BALANCE_ETH=$(echo "scale=18; $L2_BALANCE / 1000000000000000000" | bc -l)
echo "$L2_BALANCE_ETH ETH ($L2_BALANCE wei)"

echo ""
echo "🔍 L1 余额:"
L1_BALANCE=$(cast balance $ADDRESS --rpc-url $L1_RPC)
L1_BALANCE_ETH=$(echo "scale=18; $L1_BALANCE / 1000000000000000000" | bc -l)
echo "$L1_BALANCE_ETH ETH ($L1_BALANCE wei)"

echo ""
echo "📊 分析:"
echo "========"
echo "如果 L2 余额减少了，说明提币请求已发送"
echo "如果 L1 余额暂时没有增加，这是正常的"
echo "ZKsync 提币需要等待挑战期 (~24小时) 才能在 L1 完成"

echo ""
echo "🔍 检查 L2 交易数量:"
NONCE=$(cast nonce $ADDRESS --rpc-url $L2_RPC)
echo "Nonce: $NONCE (如果 > 0 说明已发送提币交易)"

echo ""
echo "💡 持续监控命令:"
echo "==============="
echo "L2: cast balance $ADDRESS --rpc-url $L2_RPC"
echo "L1: cast balance $ADDRESS --rpc-url $L1_RPC"