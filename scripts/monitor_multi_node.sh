#!/bin/bash

# 监控多节点 ZKsync Era 网络状态

echo "🔍 监控多节点 ZKsync Era 网络状态..."
echo "=================================="

# 检查节点1
echo ""
echo "📡 节点1 (主节点) - 端口 3050:"
if curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   http://localhost:3050 | grep -q "result"; then
    BLOCK_NUMBER_1=$(curl -s -X POST -H "Content-Type: application/json" \
       --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
       http://localhost:3050 | jq -r '.result')
    echo "✅ 正常运行 - 当前区块: $BLOCK_NUMBER_1"
else
    echo "❌ 无法连接"
fi

# 检查节点2
echo ""
echo "📡 节点2 (验证者) - 端口 3060:"
if curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   http://localhost:3060 | grep -q "result"; then
    BLOCK_NUMBER_2=$(curl -s -X POST -H "Content-Type: application/json" \
       --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
       http://localhost:3060 | jq -r '.result')
    echo "✅ 正常运行 - 当前区块: $BLOCK_NUMBER_2"
else
    echo "❌ 无法连接"
fi

# 检查节点3
echo ""
echo "📡 节点3 (验证者) - 端口 3070:"
if curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   http://localhost:3070 | grep -q "result"; then
    BLOCK_NUMBER_3=$(curl -s -X POST -H "Content-Type: application/json" \
       --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
       http://localhost:3070 | jq -r '.result')
    echo "✅ 正常运行 - 当前区块: $BLOCK_NUMBER_3"
else
    echo "❌ 无法连接"
fi

# 检查共识端口
echo ""
echo "🔗 共识网络状态:"
echo "==============="
netstat -tlnp 2>/dev/null | grep -E "(3054|3055|3056)" | while read line; do
    echo "$line"
done

# 检查进程状态
echo ""
echo "⚙️ 进程状态:"
echo "==========="
if [ -f "logs/multi_node/node1.pid" ]; then
    NODE1_PID=$(cat logs/multi_node/node1.pid)
    if ps -p $NODE1_PID > /dev/null; then
        echo "✅ 节点1 运行中 (PID: $NODE1_PID)"
    else
        echo "❌ 节点1 已停止"
    fi
else
    echo "❌ 节点1 未启动"
fi

if [ -f "logs/multi_node/node2.pid" ]; then
    NODE2_PID=$(cat logs/multi_node/node2.pid)
    if ps -p $NODE2_PID > /dev/null; then
        echo "✅ 节点2 运行中 (PID: $NODE2_PID)"
    else
        echo "❌ 节点2 已停止"
    fi
else
    echo "❌ 节点2 未启动"
fi

if [ -f "logs/multi_node/node3.pid" ]; then
    NODE3_PID=$(cat logs/multi_node/node3.pid)
    if ps -p $NODE3_PID > /dev/null; then
        echo "✅ 节点3 运行中 (PID: $NODE3_PID)"
    else
        echo "❌ 节点3 已停止"
    fi
else
    echo "❌ 节点3 未启动"
fi

echo ""
echo "💡 有用的命令:"
echo "============="
echo "查看实时日志: tail -f logs/multi_node/node1.log"
echo "测试交易: cast send --rpc-url http://localhost:3050 ..."
echo "检查同步: cast block-number --rpc-url http://localhost:3050"