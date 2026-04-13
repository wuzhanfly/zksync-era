#!/bin/bash
# 快速部署脚本

set -e

EXTERNAL_NODE_IP="13.228.79.240"
EXTERNAL_NODE_SSH_KEY="$HOME/zk_node1.pem"
MAIN_NODE_IP="54.255.184.251"

echo "=== 部署 External Node ==="
echo ""

# 上传镜像
echo "2️⃣ 上传镜像到服务器..."
scp -i $EXTERNAL_NODE_SSH_KEY /tmp/tmai-external-node.tar.gz ubuntu@$EXTERNAL_NODE_IP:/tmp/
echo "✅ 上传完成"
echo ""

# 配置和启动
echo "3️⃣ 配置并启动服务..."
ssh -i $EXTERNAL_NODE_SSH_KEY ubuntu@$EXTERNAL_NODE_IP << 'ENDSSH'
cd ~
mkdir -p e-node1/db/{state_cache,merkle_tree}
cd e-node1

# 加载镜像
echo "加载镜像..."
docker load < /tmp/tmai-external-node.tar.gz
rm /tmp/tmai-external-node.tar.gz

# 创建 .env
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
RUST_LOG=info,zksync_core=info,zksync_dal=info
RUST_BACKTRACE=1
EN_SNAPSHOTS_RECOVERY_ENABLED=true
EN_PRUNING_ENABLED=false
EOF

# 创建 docker-compose.yml
cat > docker-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:14
    container_name: tmai-external-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: notsecurepassword
      POSTGRES_DB: zksync_external_node
    ports:
      - "5433:5432"
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
      - "4050:4050"
      - "4051:4051"
      - "4071:4071"
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
EOF

# 启动
echo "启动服务..."
docker compose up -d

sleep 15
echo ""
echo "📊 容器状态:"
docker ps | grep tmai-external

echo ""
echo "📝 日志:"
docker logs --tail 20 tmai-external-node
ENDSSH

echo ""
echo "========================================="
echo "  ✅ 部署完成！"
echo "========================================="
echo ""
echo "验证:"
echo "  curl -X POST http://$EXTERNAL_NODE_IP:4050 \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}'"
