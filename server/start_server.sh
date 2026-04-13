#!/bin/bash

# tMai Server Startup Script
# 使用 Docker Compose 启动服务

set -e

echo "🚀 Starting tMai Server"
echo "==========================================="

COMPOSE_FILE="/home/ubuntu/node/docker-compose.yml"
ECOSYSTEM_PATH="/home/ubuntu/node/tmai_ecosystem"

# 检查 docker-compose 文件
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
fi

# 检查 tmai_ecosystem
if [ ! -d "$ECOSYSTEM_PATH" ]; then
    echo "❌ tmai_ecosystem not found at $ECOSYSTEM_PATH"
    echo "Please upload tmai_ecosystem first"
    exit 1
fi

# 检查 Docker 镜像
if ! docker images | grep -q "tmai-server"; then
    echo "❌ tmai-server image not found"
    echo "Please load the Docker image first"
    exit 1
fi

echo "✅ Pre-flight checks passed"
echo ""

# 停止现有容器
echo "🛑 Stopping existing containers..."
cd /home/ubuntu/node
docker-compose down 2>/dev/null || true

echo ""
echo "🚀 Starting services..."
docker-compose up -d

echo ""
echo "⏳ Waiting for services to start..."
sleep 10

# 检查容器状态
echo ""
echo "📊 Container Status:"
docker-compose ps

echo ""
echo "⏳ Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker exec tmai-postgres pg_isready -U postgres &>/dev/null; then
        echo "✅ PostgreSQL is ready"
        break
    fi
    echo "⏳ Waiting for PostgreSQL... ($i/30)"
    sleep 2
done

echo ""
echo "⏳ Waiting for tMai Server to initialize..."
sleep 20

# 健康检查
echo ""
echo "🔍 Health Check:"
HEALTH_CHECK_PASSED=false
for i in {1..10}; do
    if curl -s --max-time 5 "http://localhost:3071/health" &>/dev/null; then
        echo "✅ Health check passed"
        HEALTH_CHECK_PASSED=true
        break
    fi
    echo "⏳ Health check attempt $i/10..."
    sleep 5
done

if [ "$HEALTH_CHECK_PASSED" = false ]; then
    echo "⚠️ Health check timeout - checking logs..."
    echo ""
    echo "📋 Recent logs:"
    docker-compose logs --tail 50 tmai-server
    echo ""
    echo "💡 The server may need more time to initialize"
fi

# API 测试
echo ""
echo "🔗 Testing API..."
CHAIN_ID=$(timeout 10 curl -s -X POST "http://localhost:3050" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | \
    jq -r '.result' 2>/dev/null || echo "null")

if [ "$CHAIN_ID" != "null" ] && [ "$CHAIN_ID" != "" ]; then
    echo "✅ API working - Chain ID: $CHAIN_ID"
else
    echo "⚠️ API not responding yet"
    echo "💡 Try again in a few minutes"
fi

echo ""
echo "🎉 Startup Complete!"
echo "=================================="
echo ""
echo "🌐 Access URLs:"
echo "HTTP API: http://54.255.184.251:3050"
echo "WebSocket: ws://54.255.184.251:3051"
echo "Health: http://54.255.184.251:3071/health"
echo "Metrics: http://54.255.184.251:3312/metrics"
echo ""
echo "📊 Management Commands:"
echo "View logs: docker-compose logs -f tmai-server"
echo "View all logs: docker-compose logs -f"
echo "Stop: docker-compose down"
echo "Restart: docker-compose restart tmai-server"
echo "Status: docker-compose ps"
echo ""
echo "🔍 Troubleshooting:"
echo "Check logs: docker-compose logs --tail 100 tmai-server"
echo "Check DB: docker exec tmai-postgres psql -U postgres -l"
echo "Container shell: docker exec -it tmai-server bash"
echo ""

