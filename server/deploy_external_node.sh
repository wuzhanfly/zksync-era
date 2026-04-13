#!/bin/bash

# 在服务器上部署 ZKsync External Node

set -e

echo "=== 部署 ZKsync External Node ==="
echo ""

# 配置
MAIN_NODE_URL="http://localhost:3050"
EXTERNAL_NODE_PORT="4050"
EXTERNAL_NODE_WS_PORT="4051"
DB_NAME="zksync_external_node"

# 1. 检查主节点是否运行
echo "1️⃣ 检查主节点状态..."
if ! curl -s -X POST $MAIN_NODE_URL \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' > /dev/null; then
    echo "❌ 主节点未运行或无法访问"
    exit 1
fi
echo "✅ 主节点运行正常"
echo ""

# 2. 创建外部节点数据库
echo "2️⃣ 创建外部节点数据库..."
docker exec tmai-postgres psql -U postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || echo "数据库已存在"
echo "✅ 数据库准备完成"
echo ""

# 3. 创建外部节点配置目录
echo "3️⃣ 创建配置目录..."
mkdir -p external_node/db/state_keeper
mkdir -p external_node/db/tree
echo "✅ 目录创建完成"
echo ""

# 4. 创建外部节点配置文件
echo "4️⃣ 创建配置文件..."
cat > external_node/general.yaml << 'EOF'
api:
  healthcheck:
    port: 4071
  web3_json_rpc:
    http_port: 3050
    http_url: http://0.0.0.0:3050/
    ws_port: 3051
    ws_url: ws://0.0.0.0:3051/
    api_namespaces:
      - eth
      - net
      - web3
      - zks
      - pubsub
      - debug

db:
  state_keeper_db_path: /app/external_node/db/state_keeper
  merkle_tree:
    path: /app/external_node/db/tree

# 主节点连接
main_node_url: http://tmai-server:3050

# 只读模式
readonly: true
EOF

echo "✅ 配置文件创建完成"
echo ""

# 5. 创建 docker-compose 文件
echo "5️⃣ 创建 docker-compose 配置..."
cat > external_node/docker-compose.yml << 'EOF'
services:
  external-node:
    image: tmai-server:2.0
    container_name: tmai-external-node
    command:
      - "--config-path=/app/external_node/general.yaml"
      - "--secrets-path=/app/tmai_ecosystem/chains/tmai_chain/configs/secrets.yaml"
      - "--contracts-config-path=/app/tmai_ecosystem/chains/tmai_chain/configs/contracts.yaml"
      - "--wallets-path=/app/tmai_ecosystem/chains/tmai_chain/configs/wallets.yaml"
      - "--genesis-path=/app/tmai_ecosystem/chains/tmai_chain/configs/genesis.yaml"
      - "--external-node"
    environment:
      # L1 配置
      L1_CHAIN_ID: 97
      L1_RPC_URL: http://13.212.114.138:10575
      
      # 数据库配置
      DATABASE_URL: postgres://postgres:notsecurepassword@tmai-postgres:5432/zksync_external_node
      
      # 主节点 URL
      MAIN_NODE_URL: http://tmai-server:3050
      
      # 日志
      RUST_LOG: info,zksync=info
      RUST_BACKTRACE: 1
    ports:
      - "4050:3050"  # HTTP RPC
      - "4051:3051"  # WebSocket RPC
      - "4071:4071"  # Health check
    volumes:
      - ../tmai_ecosystem:/app/tmai_ecosystem
      - ./db:/app/external_node/db
      - ./general.yaml:/app/external_node/general.yaml
    restart: unless-stopped

networks:
  default:
    name: node_tmai-network
    external: true
EOF

echo "✅ docker-compose 配置创建完成"
echo ""

# 6. 启动外部节点
echo "6️⃣ 启动外部节点..."
cd external_node
docker compose up -d

echo ""
echo "⏳ 等待外部节点启动..."
sleep 15

echo ""
echo "========================================="
echo "  📊 节点状态"
echo "========================================="
echo ""

# 7. 检查节点状态
docker ps | grep -E "CONTAINER|tmai"

echo ""
echo "========================================="
echo "  🔍 验证部署"
echo "========================================="
echo ""

# 检查主节点
echo "主节点 (3050):"
curl -s -X POST http://localhost:3050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r '.result' || echo "❌ 无法连接"

echo ""

# 检查外部节点
echo "外部节点 (4050):"
curl -s -X POST http://localhost:4050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r '.result' || echo "⏳ 正在同步..."

echo ""
echo "========================================="
echo "  ✅ 部署完成！"
echo "========================================="
echo ""
echo "外部节点 RPC:"
echo "  HTTP: http://$(hostname -I | awk '{print $1}'):4050"
echo "  WS:   ws://$(hostname -I | awk '{print $1}'):4051"
echo ""
echo "查看日志:"
echo "  docker logs -f tmai-external-node"
echo ""
echo "停止外部节点:"
echo "  cd external_node && docker compose down"

