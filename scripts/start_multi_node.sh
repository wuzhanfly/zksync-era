#!/bin/bash

# 启动多节点 ZKsync Era 网络

echo "🚀 启动多节点 ZKsync Era 网络..."

# 检查配置文件
if [ ! -d "multi_node" ]; then
    echo "❌ 多节点配置不存在，请先运行: bash scripts/setup_multi_node.sh"
    exit 1
fi

# 创建日志目录
mkdir -p logs/multi_node

# 启动节点1 (主节点)
echo "🔧 启动节点1 (主节点)..."
CONSENSUS_SECRETS_PATH="consensus_keys/node1/secrets.yaml" \
CONSENSUS_CONFIG_PATH="multi_node/node1/general.yaml" \
./zkstack_cli/target/release/zkstack server \
  --config-path multi_node/node1/general.yaml \
  --secrets-path consensus_keys/node1/secrets.yaml \
  --chain era > logs/multi_node/node1.log 2>&1 &

NODE1_PID=$!
echo "节点1 PID: $NODE1_PID"

# 等待节点1启动
sleep 10

# 启动节点2 (验证者)
echo "🔧 启动节点2 (验证者)..."
CONSENSUS_SECRETS_PATH="consensus_keys/node2/secrets.yaml" \
CONSENSUS_CONFIG_PATH="multi_node/node2/general.yaml" \
./zkstack_cli/target/release/zkstack server \
  --config-path multi_node/node2/general.yaml \
  --secrets-path consensus_keys/node2/secrets.yaml \
  --chain era > logs/multi_node/node2.log 2>&1 &

NODE2_PID=$!
echo "节点2 PID: $NODE2_PID"

# 等待节点2启动
sleep 10

# 启动节点3 (验证者)
echo "🔧 启动节点3 (验证者)..."
CONSENSUS_SECRETS_PATH="consensus_keys/node3/secrets.yaml" \
CONSENSUS_CONFIG_PATH="multi_node/node3/general.yaml" \
./zkstack_cli/target/release/zkstack server \
  --config-path multi_node/node3/general.yaml \
  --secrets-path consensus_keys/node3/secrets.yaml \
  --chain era > logs/multi_node/node3.log 2>&1 &

NODE3_PID=$!
echo "节点3 PID: $NODE3_PID"

# 保存PID
echo "$NODE1_PID" > logs/multi_node/node1.pid
echo "$NODE2_PID" > logs/multi_node/node2.pid  
echo "$NODE3_PID" > logs/multi_node/node3.pid

echo ""
echo "✅ 多节点网络启动完成！"
echo ""
echo "📊 节点状态:"
echo "============"
echo "节点1: PID $NODE1_PID, 日志: logs/multi_node/node1.log"
echo "节点2: PID $NODE2_PID, 日志: logs/multi_node/node2.log"
echo "节点3: PID $NODE3_PID, 日志: logs/multi_node/node3.log"
echo ""
echo "🌐 RPC 接口:"
echo "============"
echo "节点1: http://localhost:3050"
echo "节点2: http://localhost:3060"
echo "节点3: http://localhost:3070"
echo ""
echo "🔍 监控命令:"
echo "============"
echo "查看节点1日志: tail -f logs/multi_node/node1.log"
echo "查看节点2日志: tail -f logs/multi_node/node2.log"
echo "查看节点3日志: tail -f logs/multi_node/node3.log"
echo ""
echo "停止网络: bash scripts/stop_multi_node.sh"