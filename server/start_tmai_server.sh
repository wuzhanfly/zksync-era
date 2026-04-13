#!/bin/bash

# 在服务器上启动 tMai Server

set -e

echo "=== 启动 tMai Server ==="
echo ""

# 1. 检查当前目录
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ 错误: 请在 /home/ubuntu/node 目录下运行此脚本"
    exit 1
fi

# 2. 检查 Docker 镜像
echo "1️⃣ 检查 Docker 镜像..."
if docker images | grep -q "tmai-server.*2.0"; then
    echo "✅ 找到 tmai-server:2.0 镜像"
    docker images | grep tmai-server
else
    echo "❌ 未找到 tmai-server:2.0 镜像"
    exit 1
fi

echo ""

# 3. 检查 PostgreSQL
echo "2️⃣ 检查 PostgreSQL..."
if docker ps | grep -q "tmai-postgres"; then
    echo "✅ PostgreSQL 运行中"
    docker ps | grep tmai-postgres
else
    echo "❌ PostgreSQL 未运行，正在启动..."
    docker compose -f docker-compose.postgres.yml up -d
    echo "⏳ 等待 PostgreSQL 启动..."
    sleep 10
fi

echo ""

# 4. 检查 tmai_ecosystem
echo "3️⃣ 检查 tmai_ecosystem..."
if [ -d "tmai_ecosystem" ]; then
    echo "✅ tmai_ecosystem 目录存在"
    echo "   配置文件:"
    ls -lh tmai_ecosystem/chains/tmai_chain/configs/*.yaml 2>/dev/null || echo "   配置文件未找到"
else
    echo "❌ tmai_ecosystem 目录不存在"
    exit 1
fi

echo ""

# 5. 停止旧容器
echo "4️⃣ 停止旧的 tmai-server 容器..."
if docker ps -a | grep -q "tmai-server"; then
    docker stop tmai-server 2>/dev/null || true
    docker rm tmai-server 2>/dev/null || true
    echo "✅ 旧容器已清理"
else
    echo "✅ 没有旧容器"
fi

echo ""

# 6. 启动 tMai Server
echo "5️⃣ 启动 tMai Server..."
echo ""

docker compose up -d tmai-server

echo ""
echo "⏳ 等待服务启动（30秒）..."
sleep 30

echo ""
echo "========================================="
echo "  📊 服务状态"
echo "========================================="
echo ""

# 7. 检查容器状态
echo "容器状态："
docker ps | grep -E "CONTAINER|tmai"

echo ""
echo "========================================="
echo "  📝 查看日志"
echo "========================================="
echo ""

# 显示最近的日志
docker logs --tail 50 tmai-server

echo ""
echo "========================================="
echo "  🔍 有用的命令"
echo "========================================="
echo ""
echo "查看实时日志:"
echo "  docker logs -f tmai-server"
echo ""
echo "检查健康状态:"
echo "  curl http://localhost:3071/health"
echo ""
echo "检查 RPC:"
echo "  curl -X POST http://localhost:3050 -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}'"
echo ""
echo "停止服务:"
echo "  docker compose down"
echo ""
echo "重启服务:"
echo "  docker compose restart tmai-server"

