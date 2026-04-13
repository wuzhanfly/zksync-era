#!/bin/bash

# 部署 External Node 到独立服务器

set -e

# 配置
MAIN_NODE_IP="54.255.184.251"
MAIN_NODE_SSH_KEY="$HOME/zk_gas.pem"

EXTERNAL_NODE_IP="13.228.79.240"
EXTERNAL_NODE_SSH_KEY="$HOME/zk_node1.pem"  # 使用 $HOME 确保路径正确
EXTERNAL_NODE_USER="ubuntu"
EXTERNAL_NODE_PATH="/home/ubuntu/e-node1"

# 端口配置（避免与现有服务冲突）
EXTERNAL_NODE_RPC_PORT="4050"
EXTERNAL_NODE_WS_PORT="4051"
EXTERNAL_NODE_HEALTH_PORT="4071"
EXTERNAL_NODE_DB_PORT="5433"

echo "=== 部署 External Node 到独立服务器 ==="
echo ""
echo "主节点: $MAIN_NODE_IP"
echo "外部节点: $EXTERNAL_NODE_IP"
echo ""

# 检查 SSH 密钥文件
if [ ! -f "$EXTERNAL_NODE_SSH_KEY" ]; then
    echo "❌ SSH 密钥文件不存在: $EXTERNAL_NODE_SSH_KEY"
    echo ""
    echo "请确认密钥文件路径，可能的位置："
    echo "  - $HOME/zk_node1.pem"
    echo "  - $(pwd)/zk_node1.pem"
    echo "  - ~/.ssh/zk_node1.pem"
    echo ""
    echo "如果密钥在当前目录，请修改脚本中的 EXTERNAL_NODE_SSH_KEY 变量"
    exit 1
fi

if [ ! -f "$MAIN_NODE_SSH_KEY" ]; then
    echo "❌ 主节点 SSH 密钥文件不存在: $MAIN_NODE_SSH_KEY"
    exit 1
fi

echo "✅ SSH 密钥文件检查通过"
echo ""

# 1. 检查主节点是否可访问
echo "1️⃣ 检查主节点连接..."
if ! curl -s -m 5 -X POST http://$MAIN_NODE_IP:3050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' > /dev/null; then
    echo "❌ 无法连接到主节点 RPC"
    echo "   请确保:"
    echo "   1. 主节点正在运行"
    echo "   2. 端口 3050 已开放"
    echo "   3. 防火墙允许外部访问"
    exit 1
fi
echo "✅ 主节点连接正常"
echo ""

# 2. 从主节点下载 tmai_ecosystem
echo "2️⃣ 从主节点下载配置文件..."
rm -rf /tmp/tmai_ecosystem
scp -i $MAIN_NODE_SSH_KEY -r ubuntu@$MAIN_NODE_IP:/home/ubuntu/node/tmai_ecosystem /tmp/
echo "✅ 配置文件下载完成"
echo ""

# 3. 检查 Docker 镜像
echo "3️⃣ 检查 Docker 镜像..."
if ! docker images | grep -q "tmai-server.*2.0"; then
    echo "❌ 本地没有 tmai-server:2.0 镜像"
    echo "   请先构建镜像: bash local/build_minimal_image.sh"
    exit 1
fi
echo "✅ Docker 镜像存在"
echo ""

# 4. 导出 Docker 镜像
echo "4️⃣ 导出 Docker 镜像..."
docker save tmai-server:2.0 | gzip > /tmp/tmai-server.tar.gz
IMAGE_SIZE=$(du -h /tmp/tmai-server.tar.gz | cut -f1)
echo "✅ 镜像已导出 ($IMAGE_SIZE)"
echo ""

# 5. 上传到外部节点服务器
echo "5️⃣ 上传文件到外部节点服务器..."
echo "   这可能需要几分钟..."

# 创建目录
ssh -i $EXTERNAL_NODE_SSH_KEY $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP << EOF
mkdir -p $EXTERNAL_NODE_PATH
mkdir -p $EXTERNAL_NODE_PATH/db/state_keeper
mkdir -p $EXTERNAL_NODE_PATH/db/tree
EOF

# 上传 tmai_ecosystem
echo "   上传配置文件..."
scp -i $EXTERNAL_NODE_SSH_KEY -r /tmp/tmai_ecosystem $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP:$EXTERNAL_NODE_PATH/

# 上传 Docker 镜像
echo "   上传 Docker 镜像..."
scp -i $EXTERNAL_NODE_SSH_KEY /tmp/tmai-server.tar.gz $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP:$EXTERNAL_NODE_PATH/

echo "✅ 文件上传完成"
echo ""

# 6. 在外部节点服务器上配置
echo "6️⃣ 配置外部节点..."
ssh -i $EXTERNAL_NODE_SSH_KEY $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP << ENDSSH
cd $EXTERNAL_NODE_PATH

# 加载 Docker 镜像
echo "加载 Docker 镜像..."
docker load < tmai-server.tar.gz
rm tmai-server.tar.gz

# 创建 docker-compose.yml（使用不冲突的端口）
cat > docker-compose.yml << EOF
services:
  postgres:
    image: postgres:14
    container_name: tmai-external-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: notsecurepassword
      POSTGRES_DB: zksync_external_node
    ports:
      - "$EXTERNAL_NODE_DB_PORT:5432"
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
    image: tmai-server:2.0
    container_name: tmai-external-node
    depends_on:
      postgres:
        condition: service_healthy
    command:
      - "--config-path=/app/tmai_ecosystem/chains/tmai_chain/configs/general.yaml"
      - "--secrets-path=/app/tmai_ecosystem/chains/tmai_chain/configs/secrets.yaml"
      - "--contracts-config-path=/app/tmai_ecosystem/chains/tmai_chain/configs/contracts.yaml"
      - "--wallets-path=/app/tmai_ecosystem/chains/tmai_chain/configs/wallets.yaml"
      - "--genesis-path=/app/tmai_ecosystem/chains/tmai_chain/configs/genesis.yaml"
      - "--external-node"
    environment:
      # L1 配置
      L1_CHAIN_ID: 97
      L1_RPC_URL: http://13.212.114.138:10575
      L1_WS_URL: ws://13.212.114.138:10576
      
      # 数据库配置
      DATABASE_URL: postgres://postgres:notsecurepassword@postgres:5432/zksync_external_node
      
      # 主节点 URL（使用公网 IP）
      MAIN_NODE_URL: http://$MAIN_NODE_IP:3050
      
      # 日志
      RUST_LOG: info,zksync=info
      RUST_BACKTRACE: 1
    ports:
      - "$EXTERNAL_NODE_RPC_PORT:3050"    # HTTP RPC
      - "$EXTERNAL_NODE_WS_PORT:3051"     # WebSocket RPC
      - "$EXTERNAL_NODE_HEALTH_PORT:3071" # Health check
    volumes:
      - ./tmai_ecosystem:/app/tmai_ecosystem
      - ./db:/app/db
    restart: unless-stopped
    networks:
      - tmai-external-network

volumes:
  postgres_data:

networks:
  tmai-external-network:
    driver: bridge
EOF

echo "✅ 配置文件创建完成"
ENDSSH

echo "✅ 外部节点配置完成"
echo ""

# 7. 启动外部节点
echo "7️⃣ 启动外部节点..."
ssh -i $EXTERNAL_NODE_SSH_KEY $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP << 'ENDSSH'
cd /home/ubuntu/e-node1

# 启动服务
docker compose up -d

echo ""
echo "⏳ 等待服务启动..."
sleep 20

echo ""
echo "📊 容器状态:"
docker ps

echo ""
echo "📝 查看日志（最近 20 行）:"
docker logs --tail 20 tmai-external-node
ENDSSH

echo ""
echo "========================================="
echo "  ✅ 部署完成！"
echo "========================================="
echo ""
echo "外部节点信息:"
echo "  HTTP RPC: http://$EXTERNAL_NODE_IP:$EXTERNAL_NODE_RPC_PORT"
echo "  WS RPC:   ws://$EXTERNAL_NODE_IP:$EXTERNAL_NODE_WS_PORT"
echo "  Health:   http://$EXTERNAL_NODE_IP:$EXTERNAL_NODE_HEALTH_PORT/health"
echo "  Database: localhost:$EXTERNAL_NODE_DB_PORT"
echo ""
echo "现有服务（不受影响）:"
echo "  ZK Node:  http://$EXTERNAL_NODE_IP:3050"
echo "  Database: localhost:10432"
echo ""
echo "验证部署:"
echo "  curl -X POST http://$EXTERNAL_NODE_IP:$EXTERNAL_NODE_RPC_PORT \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}'"
echo ""
echo "查看日志:"
echo "  ssh -i $EXTERNAL_NODE_SSH_KEY $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP"
echo "  docker logs -f tmai-external-node"
echo ""
echo "注意: 外部节点需要时间同步数据，请耐心等待"

# 清理临时文件
rm -rf /tmp/tmai_ecosystem
rm -f /tmp/tmai-server.tar.gz

