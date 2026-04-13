#!/bin/bash

# 使用 Docker 运行 zkstack server
# 不需要本地安装 zkstack

set -e

echo "=== tMai Chain Server Starting ==="
echo ""

# 配置
ECOSYSTEM_PATH="/home/ubuntu/node/tmai_ecosystem"
CHAIN_NAME="tmai_chain"
L1_RPC_URL="http://13.212.114.138:10575"

# 检查 tmai_ecosystem
if [ ! -d "$ECOSYSTEM_PATH" ]; then
    echo "❌ tmai_ecosystem not found"
    exit 1
fi

# 检查数据库连接
echo "检查数据库连接..."
if docker exec tmai-postgres pg_isready -U postgres &>/dev/null; then
    echo "✅ 数据库连接成功"
else
    echo "❌ 数据库未运行，请先启动 PostgreSQL:"
    echo "  docker compose -f docker-compose.postgres.yml up -d"
    exit 1
fi

echo ""
echo "启动 ZKsync Server..."
echo "Chain: $CHAIN_NAME"
echo "L1 RPC: $L1_RPC_URL"
echo ""

# 停止现有容器
docker stop tmai-server 2>/dev/null || true
docker rm tmai-server 2>/dev/null || true

# 使用 Docker 运行 zksync_server
docker run -d \
    --name tmai-server \
    --network node_tmai-network \
    -p 3050:3050 \
    -p 3051:3051 \
    -p 3071:3071 \
    -p 3312:3312 \
    -v "$ECOSYSTEM_PATH:/app/ecosystem:ro" \
    -e DATABASE_URL="postgres://postgres:notsecurepassword@tmai-postgres:5432/zksync_server_bsc_testnet_tmai_chain" \
    -e L1_RPC_URL="$L1_RPC_URL" \
    -e L1_CHAIN_ID="97" \
    -e RUST_LOG="info,zksync=debug" \
    -e RUST_BACKTRACE="1" \
    --restart unless-stopped \
    ubuntu:22.04 \
    bash -c "
        apt-get update && apt-get install -y curl && \
        /app/ecosystem/zksync_server \
            --genesis-path /app/ecosystem/chains/$CHAIN_NAME/configs/genesis.yaml \
            --config-path /app/ecosystem/chains/$CHAIN_NAME/configs/general.yaml \
            --wallets-path /app/ecosystem/chains/$CHAIN_NAME/configs/wallets.yaml \
            --secrets-path /app/ecosystem/chains/$CHAIN_NAME/configs/secrets.yaml \
            --contracts-config-path /app/ecosystem/chains/$CHAIN_NAME/configs/contracts.yaml
    "

echo ""
echo "⏳ 等待服务启动..."
sleep 10

# 检查容器状态
if docker ps | grep -q tmai-server; then
    echo "✅ 容器运行中"
else
    echo "❌ 容器启动失败"
    docker logs tmai-server
    exit 1
fi

echo ""
echo "========================================="
echo "  ✅ 服务已启动！"
echo "========================================="
echo ""
echo "🌐 访问地址:"
echo "HTTP API: http://54.255.184.251:3050"
echo "Health: http://54.255.184.251:3071/health"
echo ""
echo "📊 管理命令:"
echo "查看日志: docker logs -f tmai-server"
echo "停止服务: docker stop tmai-server"
echo "重启服务: docker restart tmai-server"
echo ""

