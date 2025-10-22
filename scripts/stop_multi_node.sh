#!/bin/bash

# 停止多节点 ZKsync Era 网络

echo "🛑 停止多节点 ZKsync Era 网络..."

# 停止节点1
if [ -f "logs/multi_node/node1.pid" ]; then
    NODE1_PID=$(cat logs/multi_node/node1.pid)
    echo "停止节点1 (PID: $NODE1_PID)..."
    kill $NODE1_PID 2>/dev/null || echo "节点1已停止"
    rm -f logs/multi_node/node1.pid
fi

# 停止节点2
if [ -f "logs/multi_node/node2.pid" ]; then
    NODE2_PID=$(cat logs/multi_node/node2.pid)
    echo "停止节点2 (PID: $NODE2_PID)..."
    kill $NODE2_PID 2>/dev/null || echo "节点2已停止"
    rm -f logs/multi_node/node2.pid
fi

# 停止节点3
if [ -f "logs/multi_node/node3.pid" ]; then
    NODE3_PID=$(cat logs/multi_node/node3.pid)
    echo "停止节点3 (PID: $NODE3_PID)..."
    kill $NODE3_PID 2>/dev/null || echo "节点3已停止"
    rm -f logs/multi_node/node3.pid
fi

echo "✅ 多节点网络已停止"