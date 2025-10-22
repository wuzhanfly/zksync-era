#!/bin/bash

# 检查浏览器服务状态

echo "🔍 检查 ZKStack 浏览器服务状态..."
echo "=================================="

# 检查 ZKsync 节点
echo ""
echo "📡 ZKsync 节点 (端口 3050):"
if curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   http://localhost:3050 | grep -q "result"; then
    BLOCK_NUMBER=$(curl -s -X POST -H "Content-Type: application/json" \
       --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
       http://localhost:3050 | jq -r '.result')
    echo "✅ 正常运行 - 当前区块: $BLOCK_NUMBER"
else
    echo "❌ 无法连接"
fi

# 检查浏览器 API
echo ""
echo "🔧 浏览器 API (端口 3002):"
if curl -s http://localhost:3002/health > /dev/null 2>&1; then
    echo "✅ 正常运行"
else
    echo "❌ 无法连接"
fi

# 检查 Data Fetcher
echo ""
echo "📊 Data Fetcher (端口 3040):"
if curl -s http://localhost:3040/health > /dev/null 2>&1; then
    echo "✅ 正常运行"
else
    echo "❌ 无法连接"
fi

# 检查前端应用
echo ""
echo "🌐 前端应用 (端口 3010):"
if curl -s http://localhost:3010 > /dev/null 2>&1; then
    echo "✅ 正常运行"
else
    echo "❌ 无法连接 (可能还未启动)"
fi

echo ""
echo "🎯 访问地址:"
echo "============"
echo "🌐 浏览器前端: http://localhost:3010"
echo "🔧 API 接口: http://localhost:3002"
echo "📊 Data Fetcher: http://localhost:3040"
echo "📡 ZKsync RPC: http://localhost:3050"

echo ""
echo "💡 如果前端未启动，请运行:"
echo "   ./zkstack_cli/target/release/zkstack explorer run --chain era"