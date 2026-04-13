#!/bin/bash

# 部署只读副本节点（直接连接主节点数据库）

set -e

MAIN_NODE_IP="54.255.184.251"
MAIN_NODE_SSH_KEY="$HOME/zk_gas.pem"

REPLICA_NODE_IP="13.228.79.240"
REPLICA_NODE_SSH_KEY="$HOME/zk_node1.pem"
REPLICA_NODE_USER="ubuntu"
REPLICA_NODE_PATH="/home/ubuntu/e-node1"

# 端口配置
REPLICA_RPC_PORT="4050"
REPLICA_WS_PORT="4051"

echo "=== 部署只读副本节点 ==="
echo ""
echo "主节点: $MAIN_NODE_IP"
echo "副本节点: $REPLICA_NODE_IP"
echo ""

# 1. 检查 SSH 密钥
if [ ! -f "$REPLICA_NODE_SSH_KEY" ]; then
    echo "❌ SSH 密钥不存在: $REPLICA_NODE_SSH_KEY"
    exit 1
fi

# 2. 上传 tmai_ecosystem
echo "1️⃣ 从主节点下载配置..."
rm -rf /tmp/tmai_ecosystem
scp -i $MAIN_NODE_SSH_KEY -r ubuntu@$MAIN_NODE_IP:/home/ubuntu/node/tmai_ecosystem /tmp/

echo "2️⃣ 上传配置到副本节点..."
scp -i $REPLICA_NODE_SSH_KEY -r /tmp/tmai_ecosystem $REPLICA_NODE_USER@$REPLICA_NODE_IP:$REPLICA_NODE_PATH/

# 3. 上传 Docker 镜像
echo "3️⃣ 导出 Docker 镜像..."
docker save tmai-server:2.0 | gzip > /tmp/tmai-server.tar.gz

echo "4️⃣ 上传镜像到副本节点..."
scp -i $REPLICA_NODE_SSH_KEY /tmp/tmai-server.tar.gz $REPLICA_NODE_USER@$REPLICA_NODE_IP:$REPLICA_NODE_PATH/

# 4. 配置副本节点
echo "5️⃣ 配置副本节点..."
ssh -i $REPLICA_NODE_SSH_KEY $REPLICA_NODE_USER@$REPLICA_NODE_IP << ENDSSH
cd $REPLICA_NODE_PATH

# 加载镜像
docker load < tmai-server.tar.gz
rm tmai-server.tar.gz

# 停止旧容器
docker compose down 2>/dev/null || true

# 创建只读副本配置
cat > docker-compose.yml << 'EOF'
services:
  readonly-replica:
    image: tmai-server:2.0
    container_name: tmai-readonly-replica
    command:
      - "--config-path=/app/tmai_ecosystem/chains/tmai_chain/configs/general.yaml"
      - "--secrets-path=/app/tmai_ecosystem/chains/tmai_chain/configs/secrets.yaml"
      - "--contracts-config-path=/app/tmai_ecosystem/chains/tmai_chain/configs/contracts.yaml"
      - "--wallets-path=/app/tmai_ecosystem/chains/tmai_chain/configs/wallets.yaml"
      - "--genesis-path=/app/tmai_ecosystem/chains/tmai_chain/configs/genesis.yaml"
      - "--components=api"
    environment:
      # L1 配置
      L1_CHAIN_ID: 97
      L1_RPC_URL: http://13.212.114.138:10575
      
      # 连接主节点数据库（只读）
      DATABASE_URL: postgres://postgres:notsecurepassword@$MAIN_NODE_IP:5432/zksync_server_bsc_testnet_tmai_chain?options=-c%20default_transaction_read_only=on
      
      # 只启动 API 组件
      ZKSYNC_COMPONENTS: api
      
      # 日志
      RUST_LOG: info,zksync=info
      RUST_BACKTRACE: 1
    ports:
      - "$REPLICA_RPC_PORT:3050"
      - "$REPLICA_WS_PORT:3051"
    volumes:
      - ./tmai_ecosystem:/app/tmai_ecosystem
    restart: unless-stopped
    networks:
      - tmai-replica-network

networks:
  tmai-replica-network:
    driver: bridge
EOF

echo "✅ 配置完成"
echo ""
echo "启动服务..."
docker compose up -d

sleep 20

echo ""
echo "📊 容器状态:"
docker ps | grep -E "CONTAINER|tmai"

echo ""
echo "📝 日志:"
docker logs --tail 30 tmai-readonly-replica
ENDSSH

echo ""
echo "========================================="
echo "  ✅ 部署完成！"
echo "========================================="
echo ""
echo "只读副本信息:"
echo "  HTTP RPC: http://$REPLICA_NODE_IP:$REPLICA_RPC_PORT"
echo "  WS RPC:   ws://$REPLICA_NODE_IP:$REPLICA_WS_PORT"
echo ""
echo "验证:"
echo "  curl -X POST http://$REPLICA_NODE_IP:$REPLICA_RPC_PORT \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'"
echo ""
echo "注意: 这是只读副本，直接连接主节点数据库"

# 清理
rm -rf /tmp/tmai_ecosystem
rm -f /tmp/tmai-server.tar.gz

