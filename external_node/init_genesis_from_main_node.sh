#!/bin/bash

# 从主节点初始化 External Node 的创世数据

set -e

MAIN_NODE_RPC="http://54.255.184.251:3050"
EXTERNAL_NODE_IP="13.228.79.240"
SSH_KEY="$HOME/zk_node1.pem"

echo "=== 从主节点初始化创世数据 ==="
echo ""

# 1. 从主节点获取创世区块信息
echo "1️⃣ 从主节点获取创世区块..."
GENESIS_BLOCK=$(curl -s -X POST $MAIN_NODE_RPC \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x0",false],"id":1}')

echo "创世区块信息:"
echo "$GENESIS_BLOCK" | jq '.'

# 2. 在外部节点上初始化数据库
echo ""
echo "2️⃣ 初始化外部节点数据库..."
ssh -i $SSH_KEY ubuntu@$EXTERNAL_NODE_IP << 'ENDSSH'
cd e-node1

# 停止服务
docker compose down

# 清理数据库
docker compose up -d postgres
sleep 10

# 重新创建数据库
docker exec tmai-external-postgres psql -U postgres -c "DROP DATABASE IF EXISTS zksync_external_node;"
docker exec tmai-external-postgres psql -U postgres -c "CREATE DATABASE zksync_external_node;"

echo "✅ 数据库已重置"

# 清理 RocksDB
rm -rf db/state_cache/* db/merkle_tree/*
echo "✅ RocksDB 已清理"

# 更新配置 - 完全禁用快照恢复
cat > .env << 'EOF'
DATABASE_URL=postgres://postgres:notsecurepassword@postgres:5432/zksync_external_node
DATABASE_POOL_SIZE=50
EN_ETH_CLIENT_URL=http://13.212.114.138:10575
EN_L1_CHAIN_ID=97
EN_L2_CHAIN_ID=9720
EN_MAIN_NODE_URL=http://54.255.184.251:3050
EN_STATE_CACHE_PATH=/db/state_cache
EN_MERKLE_TREE_PATH=/db/merkle_tree
EN_HTTP_PORT=4050
EN_WS_PORT=4051
EN_HEALTHCHECK_PORT=4071
EN_API_NAMESPACES=eth,net,web3,zks,pubsub,en
RUST_LOG=debug,zksync_core=debug,zksync_dal=debug,zksync_node_storage_init=debug
RUST_BACKTRACE=full

# 完全禁用快照
EN_SNAPSHOTS_RECOVERY_ENABLED=false
EN_SNAPSHOTS_OBJECT_STORE_MODE=FileBacked
EN_SNAPSHOTS_OBJECT_STORE_FILE_BACKED_BASE_PATH=/tmp/snapshots

# 从主节点同步
EN_MAIN_NODE_RATE_LIMIT_RPS=100
EOF

echo "✅ 配置已更新"
ENDSSH

echo ""
echo "3️⃣ 启动 External Node..."
ssh -i $SSH_KEY ubuntu@$EXTERNAL_NODE_IP << 'ENDSSH'
cd e-node1

# 启动服务
docker compose up -d

sleep 25
echo ""
echo "📊 容器状态:"
docker ps | grep tmai-external

echo ""
echo "📝 启动日志:"
docker logs --tail 50 tmai-external-node
ENDSSH

echo ""
echo "========================================="
echo "  初始化完成"
echo "========================================="
echo ""
echo "监控同步进度:"
echo "  ssh -i $SSH_KEY ubuntu@$EXTERNAL_NODE_IP"
echo "  docker logs -f tmai-external-node"
