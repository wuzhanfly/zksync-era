#!/bin/bash

# 在服务器上运行此脚本来设置 PostgreSQL

set -e

echo "=== 设置 PostgreSQL for 远程连接 ==="
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装"
    exit 1
fi

# 检查 docker-compose 文件是否存在
if [ ! -f "docker-compose.postgres.yml" ]; then
    echo "❌ docker-compose.postgres.yml 不存在"
    exit 1
fi

echo "1️⃣ 启动 PostgreSQL 容器..."
docker-compose -f docker-compose.postgres.yml up -d

echo ""
echo "2️⃣ 等待 PostgreSQL 启动..."
sleep 10

# 检查 PostgreSQL 是否运行
if ! docker ps | grep -q "tmai-postgres"; then
    echo "❌ PostgreSQL 容器未运行"
    docker-compose logs postgres
    exit 1
fi

echo "✅ PostgreSQL 容器运行中"

echo ""
echo "3️⃣ 等待 PostgreSQL 就绪..."
for i in {1..30}; do
    if docker exec tmai-postgres pg_isready -U postgres &>/dev/null; then
        echo "✅ PostgreSQL 已就绪"
        break
    fi
    echo "⏳ 等待 PostgreSQL... ($i/30)"
    sleep 2
done

echo ""
echo "4️⃣ 测试数据库连接..."
docker exec tmai-postgres psql -U postgres -c "SELECT version();"

echo ""
echo "========================================="
echo "  ✅ PostgreSQL 设置完成！"
echo "========================================="
echo ""
echo "📊 连接信息:"
echo "  主机: 54.255.184.251"
echo "  端口: 5432"
echo "  用户: postgres"
echo "  密码: notsecurepassword"
echo "  数据库: postgres (默认)"
echo ""
echo "🔗 连接字符串:"
echo "  postgres://postgres:notsecurepassword@54.255.184.251:5432/postgres"
echo ""
echo "📋 管理命令:"
echo "  查看日志: docker-compose -f docker-compose.postgres.yml logs -f postgres"
echo "  进入数据库: docker exec -it tmai-postgres psql -U postgres"
echo "  停止: docker-compose -f docker-compose.postgres.yml stop"
echo "  重启: docker-compose -f docker-compose.postgres.yml restart"
echo "  完全删除: docker-compose -f docker-compose.postgres.yml down -v"
echo ""
echo "🔍 测试远程连接 (在本地运行):"
echo "  PGPASSWORD=notsecurepassword psql -h 54.255.184.251 -p 5432 -U postgres -d postgres -c '\\l'"
echo ""

