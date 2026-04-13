#!/bin/bash

echo "🧪 测试 RPC 代理服务"
echo "================================"

RPC_URL="${1:-http://localhost:8545}"

echo "测试 RPC: $RPC_URL"
echo ""

# 测试 1: 健康检查
echo "1️⃣  健康检查..."
if curl -s http://localhost:8545/health | grep -q "OK"; then
    echo "✅ 健康检查通过"
else
    echo "❌ 健康检查失败"
fi
echo ""

# 测试 2: 获取区块高度
echo "2️⃣  获取区块高度..."
RESPONSE=$(curl -s -X POST "$RPC_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}')

if echo "$RESPONSE" | grep -q "result"; then
    BLOCK_HEX=$(echo "$RESPONSE" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    BLOCK_DEC=$((16#${BLOCK_HEX#0x}))
    echo "✅ 区块高度: $BLOCK_DEC (0x${BLOCK_HEX#0x})"
else
    echo "❌ 获取区块高度失败"
    echo "响应: $RESPONSE"
fi
echo ""

# 测试 3: 获取链 ID
echo "3️⃣  获取链 ID..."
RESPONSE=$(curl -s -X POST "$RPC_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}')

if echo "$RESPONSE" | grep -q "result"; then
    CHAIN_HEX=$(echo "$RESPONSE" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    CHAIN_DEC=$((16#${CHAIN_HEX#0x}))
    echo "✅ 链 ID: $CHAIN_DEC (BSC Testnet)"
else
    echo "❌ 获取链 ID 失败"
    echo "响应: $RESPONSE"
fi
echo ""

# 测试 4: 连续请求测试（测试负载均衡）
echo "4️⃣  连续请求测试（10次）..."
SUCCESS=0
FAIL=0

for i in {1..10}; do
    RESPONSE=$(curl -s -X POST "$RPC_URL" \
        -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}')
    
    if echo "$RESPONSE" | grep -q "result"; then
        SUCCESS=$((SUCCESS + 1))
        echo -n "✅ "
    else
        FAIL=$((FAIL + 1))
        echo -n "❌ "
    fi
done

echo ""
echo "成功: $SUCCESS/10, 失败: $FAIL/10"
echo ""

# 测试 5: 查看 Nginx 日志（最后 10 行）
echo "5️⃣  最近的访问日志:"
if [ -f "logs/access.log" ]; then
    tail -5 logs/access.log
else
    echo "⚠️  日志文件不存在"
fi
echo ""

echo "================================"
echo "测试完成!"
