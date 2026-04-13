#!/bin/bash

# 检查并启动 tMai Server

set -e

echo "=== tMai Server 启动检查 ==="
echo ""

# 1. 检查 Docker 镜像
echo "1️⃣ 检查 Docker 镜像..."
if docker images | grep -q "tmai-server"; then
    echo "✅ 找到 tmai-server 镜像"
    docker images | grep tmai-server
else
    echo "❌ 未找到 tmai-server 镜像"
    echo ""
    echo "请先构建或上传镜像："
    echo "  方案1: 本地构建并上传"
    echo "    本地: docker build -f docker/server-v2/Dockerfile.minimal -t tmai-server:minimal ."
    echo "    本地: docker save tmai-server:minimal | gzip > tmai-server.tar.gz"
    echo "    本地: scp -i zk_gas.pem tmai-server.tar.gz ubuntu@54.255.184.251:~/node/"
    echo "    服务器: docker load < tmai-server.tar.gz"
    echo "    服务器: docker tag tmai-server:minimal tmai-server:latest"
    echo ""
    echo "  方案2: 使用现有镜像"
    echo "    服务器: docker tag <现有镜像ID> tmai-server:latest"
    exit 1
fi

echo ""

# 2. 检查 tmai_ecosystem 目录
echo "2️⃣ 检查 tmai_ecosystem 目录..."
if [ -d "tmai_ecosystem" ]; then
    echo "✅ tmai_ecosystem 目录存在"
    ls -lh tmai_ecosystem/
else
    echo "❌ tmai_ecosystem 目录不存在"
    echo "请运行: bash ./local/upload_ecosystem.sh"
    exit 1
fi

echo ""

# 3. 检查 PostgreSQL
echo "3️⃣ 检查 PostgreSQL..."
if docker ps | grep -q "tmai-postgres"; then
    echo "✅ PostgreSQL 运行中"
else
    echo "❌ PostgreSQL 未运行"
    echo "请运行: docker compose -f docker-compose.postgres.yml up -d"
    exit 1
fi

echo ""

# 4. 检查数据库连接
echo "4️⃣ 检查数据库连接..."
if docker exec tmai-postgres psql -U postgres -d zksync_server_bsc_testnet_tmai_chain -c "SELECT 1" > /dev/null 2>&1; then
    echo "✅ 数据库连接成功"
else
    echo "❌ 数据库连接失败"
    exit 1
fi

echo ""

# 5. 检查 docker-compose.yml
echo "5️⃣ 检查 docker-compose.yml..."
if [ -f "docker-compose.yml" ]; then
    echo "✅ docker-compose.yml 存在"
else
    echo "❌ docker-compose.yml 不存在"
    exit 1
fi

echo ""
echo "========================================="
echo "  ✅ 所有检查通过！"
echo "========================================="
echo ""

# 6. 启动 tMai Server
echo "🚀 启动 tMai Server..."
echo ""

# 停止旧容器（如果存在）
if docker ps -a | grep -q "tmai-server"; then
    echo "停止旧的 tmai-server 容器..."
    docker stop tmai-server 2>/dev/null || true
    docker rm tmai-server 2>/dev/null || true
fi

# 启动服务
docker compose up -d tmai-server

echo ""
echo "⏳ 等待服务启动..."
sleep 10

echo ""
echo "📊 容器状态："
docker ps | grep -E "CONTAINER|tmai"

echo ""
echo "📝 查看日志："
echo "  docker logs -f tmai-server"
echo ""
echo "🔍 健康检查："
echo "  curl http://localhost:3071/health"

