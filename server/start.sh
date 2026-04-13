#!/bin/bash
set -e

echo "=== tMai Chain Server Starting ==="

# 检查 tmai_ecosystem 是否存在
if [ ! -d "/app/tmai_ecosystem" ]; then
    echo "❌ tmai_ecosystem 目录不存在"
    echo "请先在本地部署合约并上传 tmai_ecosystem 目录"
    exit 1
fi

# 检查数据库连接
echo "检查数据库连接..."
until PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USER" -d postgres -c '\q' 2>/dev/null; do
  echo "等待数据库..."
  sleep 2
done
echo "✅ 数据库连接成功"

# 进入 ecosystem 目录
cd /app/tmai_ecosystem

# 启动服务器
echo "启动 ZKsync Server..."
exec zkstack server --chain tmai_chain
