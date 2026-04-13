#!/bin/bash

# 使用只读模式配置外部节点

EXTERNAL_NODE_SSH_KEY="$HOME/zk_node1.pem"
EXTERNAL_NODE_IP="13.228.79.240"
EXTERNAL_NODE_USER="ubuntu"
EXTERNAL_NODE_PATH="/home/ubuntu/e-node1"
MAIN_NODE_IP="54.255.184.251"

echo "=== 配置外部节点为只读模式 ==="
echo ""

ssh -i $EXTERNAL_NODE_SSH_KEY $EXTERNAL_NODE_USER@$EXTERNAL_NODE_IP << 'ENDSSH'
cd /home/ubuntu/e-node1

# 停止服务
docker compose down

# 清理数据库（重新开始）
echo "清理旧数据..."
rm -rf db/*

# 修改 general.yaml 添加外部节点配置
cat > tmai_ecosystem/chains/tmai_chain/configs/external_node.yaml << 'EOF'
# External Node 特定配置
remote:
  l2_chain_id: 9720
  main_node_url: "http://54.255.184.251:3050"

# 只读模式
readonly: true

# API 配置
api:
  web3_json_rpc:
    http_port: 3050
    http_url: "http://0.0.0.0:3050/"
    ws_port: 3051
    ws_url: "ws://0.0.0.0:3051/"
    api_namespaces:
      - eth
      - net
      - web3
      - zks
      - pubsub
      - debug

# 数据库配置
postgres:
  database_url: "postgres://postgres:notsecurepassword@postgres:5432/zksync_external_node"

db:
  state_keeper_db_path: "/app/db/state_keeper"
  merkle_tree:
    path: "/app/db/tree"
EOF

# 更新 docker-compose.yml
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
    # 只使用基本配置文件
    command:
      - "--config-path=/app/tmai_ecosystem/chains/tmai_chain/configs/general.yaml"
      - "--secrets-path=/app/tmai_ecosystem/chains/tmai_chain/configs/secrets.yaml"
      - "--contracts-config-path=/app/tmai_ecosystem/chains/tmai_chain/configs/contracts.yaml"
      - "--wallets-path=/app/tmai_ecosystem/chains/tmai_chain/configs/wallets.yaml"
      - "--genesis-path=/app/tmai_ecosystem/chains/tmai_chain/configs/genesis.yaml"
    environment:
      # 数据库配置
      DATABASE_URL: "postgres://postgres:notsecurepassword@postgres:5432/zksync_external_node"
      
      # 禁用主节点功能
      DISABLE_CONSENSUS: "true"
      DISABLE_STATE_KEEPER: "true"
      DISABLE_BLOCK_REVERTER: "true"
      
      # 只读模式
      EN_MAIN_NODE_URL: "http://54.255.184.251:3050"
      
      # L1 配置（用于验证）
      L1_CHAIN_ID: "97"
      L1_RPC_URL: "http://13.212.114.138:10575"
      
      # 日志
      RUST_LOG: "info,zksync=debug"
      RUST_BACKTRACE: "1"
    ports:
      - "4050:3050"
      - "4051:3051"
      - "4071:3071"
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
EOFCOMPOSE

echo "✅ 配置已更新"
echo ""
echo "启动服务..."
docker compose up -d

echo ""
echo "等待 30 秒..."
sleep 30

echo ""
echo "📊 容器状态:"
docker ps | grep -E "CONTAINER|tmai"

echo ""
echo "📝 最新日志:"
docker logs --tail 50 tmai-external-node 2>&1 | grep -v "WARN.*consensus"
ENDSSH

echo ""
echo "========================================="
echo "  配置完成"
echo "========================================="
echo ""
echo "测试 RPC:"
echo "  curl -X POST http://13.228.79.240:4050 \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}'"

