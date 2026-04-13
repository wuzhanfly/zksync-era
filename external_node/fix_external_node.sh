#!/bin/bash

# 修复外部节点配置

EXTERNAL_NODE_SSH_KEY="$HOME/zk_node1.pem"
EXTERNAL_NODE_IP="13.228.79.240"
EXTERNAL_NODE_USER="ubuntu"
EXTERNAL_NODE_PATH="/home/ubuntu/e-node1"
MAIN_NODE_IP="54.255.184.251"

echo "=== 修复外部节点配置 ==="
echo ""

ssh -i $EXTERNAL_NODE_SSH_KEY $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP << ENDSSH
cd $EXTERNAL_NODE_PATH

# 停止当前容器
docker compose down

# 创建外部节点专用配置
cat > external_node_config.yaml << 'EOF'
# External Node 配置
remote:
  l2_chain_id: 9720
  main_node_url: http://$MAIN_NODE_IP:3050

api:
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

postgres:
  database_url: postgres://postgres:notsecurepassword@postgres:5432/zksync_external_node

db:
  state_keeper_db_path: /app/db/state_keeper
  merkle_tree:
    path: /app/db/tree
EOF

# 更新 docker-compose.yml - 移除 --external-node 参数
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
    image: tmai-server:2.0
    container_name: tmai-external-node
    depends_on:
      postgres:
        condition: service_healthy
    # 移除 --external-node 参数，使用环境变量控制
    command:
      - "--config-path=/app/tmai_ecosystem/chains/tmai_chain/configs/general.yaml"
      - "--secrets-path=/app/tmai_ecosystem/chains/tmai_chain/configs/secrets.yaml"
      - "--contracts-config-path=/app/tmai_ecosystem/chains/tmai_chain/configs/contracts.yaml"
      - "--wallets-path=/app/tmai_ecosystem/chains/tmai_chain/configs/wallets.yaml"
      - "--genesis-path=/app/tmai_ecosystem/chains/tmai_chain/configs/genesis.yaml"
    environment:
      # L1 配置
      L1_CHAIN_ID: 97
      L1_RPC_URL: http://13.212.114.138:10575
      L1_WS_URL: ws://13.212.114.138:10576
      
      # 数据库配置
      DATABASE_URL: postgres://postgres:notsecurepassword@postgres:5432/zksync_external_node
      
      # 主节点 URL - 关键配置！
      EN_MAIN_NODE_URL: http://$MAIN_NODE_IP:3050
      EN_L2_CHAIN_ID: 9720
      
      # 标记为外部节点模式
      ZKSYNC_ENV: ext-node
      
      # 日志
      RUST_LOG: info,zksync=info
      RUST_BACKTRACE: 1
    ports:
      - "4050:3050"
      - "4051:3051"
      - "4071:3071"
    volumes:
      - ./tmai_ecosystem:/app/tmai_ecosystem
      - ./db:/app/db
      - ./external_node_config.yaml:/app/external_node_config.yaml
    restart: unless-stopped
    networks:
      - tmai-external-network

volumes:
  postgres_data:

networks:
  tmai-external-network:
    driver: bridge
EOFCOMPOSE

echo "✅ 配置已更新"
echo ""
echo "重新启动服务..."
docker compose up -d

echo ""
echo "等待 30 秒..."
sleep 30

echo ""
echo "📊 容器状态:"
docker ps | grep -E "CONTAINER|tmai"

echo ""
echo "📝 最新日志:"
docker logs --tail 30 tmai-external-node
ENDSSH

echo ""
echo "========================================="
echo "  修复完成"
echo "========================================="
echo ""
echo "如果还有问题，查看完整日志:"
echo "  ssh -i $EXTERNAL_NODE_SSH_KEY $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP"
echo "  docker logs -f tmai-external-node"

