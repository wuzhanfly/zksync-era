#!/bin/bash

# 启动 ZKsync 节点以支持浏览器

echo "🚀 启动 ZKsync 节点以支持浏览器..."

# 检查是否已经在运行
if curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   http://localhost:3050 | grep -q "result"; then
    echo "✅ ZKsync 节点已经在运行"
    exit 0
fi

echo "🔧 启动 ZKsync 节点..."

# 使用 era 链配置启动节点
./zkstack_cli/target/release/zkstack server --chain era &

ZKSYNC_PID=$!
echo "ZKsync 节点 PID: $ZKSYNC_PID"

# 等待节点启动
echo "⏳ 等待 ZKsync 节点启动..."
for i in {1..30}; do
    if curl -s -X POST -H "Content-Type: application/json" \
       --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
       http://localhost:3050 | grep -q "result"; then
        echo "✅ ZKsync 节点启动成功！"
        echo "🌐 RPC 地址: http://localhost:3050"
        exit 0
    fi
    echo "等待中... ($i/30)"
    sleep 2
done

echo "❌ ZKsync 节点启动超时"
kill $ZKSYNC_PID 2>/dev/null || true
exit 1