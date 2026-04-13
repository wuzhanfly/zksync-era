#!/bin/bash

# 使用官方方式部署 External Node

set -e

# 配置
MAIN_NODE_IP="54.255.184.251"
MAIN_NODE_RPC="http://$MAIN_NODE_IP:3050"

EXTERNAL_NODE_IP="13.228.79.240"
EXTERNAL_NODE_SSH_KEY="$HOME/zk_node1.pem"
EXTERNAL_NODE_USER="ubuntu"
EXTERNAL_NODE_PATH="/home/ubuntu/e-node1"

# L1 配置
L1_RPC_URL="http://13.212.114.138:10575"
L1_CHAIN_ID="97"
L2_CHAIN_ID="9720"

# 端口配置
HTTP_PORT="4050"
WS_PORT="4051"
HEALTH_PORT="4071"
DB_PORT="5433"

echo "=== 部署官方 External Node ==="
echo ""
echo "主节点: $MAIN_NODE_RPC"
echo "外部节点: $EXTERNAL_NODE_IP"
echo ""

# 1. 检查镜像
echo "1️⃣ 检查 Docker 镜像..."
if ! docker images | grep -q "tmai-external-node.*latest"; then
    echo "❌ 镜像不存在，请先构建:"
    echo "   bash external_node/build_external_node.sh"
    exit 1
fi
echo "✅ 镜像存在"
echo ""

# 2. 检查主节点连接
echo "2️⃣ 检查主节点连接..."
if ! curl -s -m 5 -X POST $MAIN_NODE_RPC \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' > /dev/null; then
    echo "❌ 无法连接到主节点"
    exit 1
fi
echo "✅ 主节点连接正常"
echo ""

# 3. 导出镜像
echo "3️⃣ 导出 Docker 镜像..."
docker save tmai-external-node:latest | gzip > /tmp/tmai-external-node.tar.gz
IMAGE_SIZE=$(du -h /tmp/tmai-external-node.tar.gz | cut -f1)
echo "✅ 镜像已导出 ($IMAGE_SIZE)"
echo ""

# 4. 上传到外部节点服务器
echo "4️⃣ 上传到外部节点服务器..."
ssh -i $EXTERNAL_NODE_SSH_KEY $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP "mkdir -p $EXTERNAL_NODE_PATH"
scp -i $EXTERNAL_NODE_SSH_KEY /tmp/tmai-external-node.tar.gz $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP:$EXTERNAL_NODE_PATH/
echo "✅ 上传完成"
echo ""

# 5. 在外部节点服务器上配置
echo "5️⃣ 配置外部节点..."
ssh -i $EXTERNAL_NODE_SSH_KEY $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP << ENDSSH
cd $EXTERNAL_NODE_PATH

# 加载镜像
echo "加载 Docker 镜像..."
docker load < tmai-external-node.tar.gz
rm tmai-external-node.tar.gz

# 创建必要的目录
mkdir -p db/state_cache
mkdir -p db/merkle_tree

# 创建 .env 文件
cat > .env << EOFENV
# 数据库配置
DATABASE_URL=postgres://postgres:notsecurepassword@postgres:5432/zksync_external_node
DATABASE_POOL_SIZE=50

# L1 配置
EN_ETH_CLIENT_URL=${L1_RPC_URL}
EN_L1_CHAIN_ID=${L1_CHAIN_ID}
EN_L2_CHAIN_ID=${L2_CHAIN_ID}

# 主节点 URL
EN_MAIN_NODE_URL=${MAIN_NODE_RPC}

# RocksDB 路径
EN_STATE_CACHE_PATH=/db/state_cache
EN_MERKLE_TREE_PATH=/db/merkle_tree

# API 配置
EN_HTTP_PORT=${HTTP_PORT}
EN_WS_PORT=${WS_PORT}
EN_HEALTHCHECK_PORT=${HEALTH_PORT}

# API 命名空间
EN_API_NAMESPACES=eth,net,web3,zks,pubsub,en

# 日志
RUST_LOG=info,zksync_core=info,zksync_dal=info,zksync_eth_client=info
RUST_BACKTRACE=1

# 其他配置
EN_SNAPSHOTS_RECOVERY_ENABLED=true
EN_PRUNING_ENABLED=false
EOFENV

# 创建 docker-compose.yml
cat > docker-compose.yml << 'EOFCOMPOSE'
services:
  postgres:
    image: postgres:14
    container_name: tmai-external-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: notsecurepassword
      POSTGRES_DB: zksync_external_node
    ports:
      - "${DB_PORT}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    command: postgres -c max_connections=200
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    networks:
      - tmai-external-network

  external-node:
    image: tmai-external-node:latest
    container_name: tmai-external-node
    depends_on:
      postgres:
        condition: service_healthy
    env_file:
      - .env
    ports:
      - "${HTTP_PORT}:${HTTP_PORT}"
      - "${WS_PORT}:${WS_PORT}"
      - "${HEALTH_PORT}:${HEALTH_PORT}"
    volumes:
      - ./db:/db
    restart: unless-stopped
    networks:
      - tmai-external-network

volumes:
  postgres_data:

networks:
  tmai-external-network:
    driver: bridge
EOFCOMPOSE

echo "✅ 配置完成"
ENDSSH

echo "✅ 外部节点配置完成"
echo ""

# 6. 启动服务
echo "6️⃣ 启动外部节点..."
ssh -i $EXTERNAL_NODE_SSH_KEY $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP << 'ENDSSH'
cd /home/ubuntu/e-node1

# 启动服务
docker compose up -d

echo ""
echo "⏳ 等待服务启动..."
sleep 20

echo ""
echo "📊 容器状态:"
docker ps | grep tmai-external

echo ""
echo "📝 查看日志（最近 30 行）:"
docker logs --tail 30 tmai-external-node
ENDSSH

echo ""
echo "========================================="
echo "  ✅ 部署完成！"
echo "========================================="
echo ""
echo "外部节点信息:"
echo "  HTTP RPC: http://$EXTERNAL_NODE_IP:$HTTP_PORT"
echo "  WS RPC:   ws://$EXTERNAL_NODE_IP:$WS_PORT"
echo "  Health:   http://$EXTERNAL_NODE_IP:$HEALTH_PORT/health"
echo ""
echo "验证部署:"
echo "  curl -X POST http://$EXTERNAL_NODE_IP:$HTTP_PORT \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}'"
echo ""
echo "查看日志:"
echo "  ssh -i $EXTERNAL_NODE_SSH_KEY $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP"
echo "  docker logs -f tmai-external-node"
echo ""
echo "⚠️  注意:"
echo "  - External Node 需要时间同步数据"
echo "  - 首次启动可能需要几小时来同步历史区块"
echo "  - 可以使用 bash external_node/check_sync_status.sh 检查同步进度"

# 清理临时文件
rm -f /tmp/tmai-external-node.tar.gz
