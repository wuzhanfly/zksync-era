#!/bin/bash
set -e

echo "=== tMai Chain Server Starting ==="

# 检查 tmai_ecosystem 是否存在
if [ ! -d "/app/tmai_ecosystem" ]; then
    echo "❌ tmai_ecosystem 目录不存在"
    echo "请确保已挂载 tmai_ecosystem 目录"
    exit 1
fi

# 检查数据库连接
echo "检查数据库连接..."
DB_HOST=${DATABASE_HOST:-localhost}
DB_USER=${DATABASE_USER:-postgres}
DB_PASSWORD=${DATABASE_PASSWORD:-notsecurepassword}

until PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USER" -d postgres -c '\q' 2>/dev/null; do
  echo "等待数据库 $DB_HOST ..."
  sleep 2
done
echo "✅ 数据库连接成功"

# 设置环境变量
export L1_CHAIN_ID=${L1_CHAIN_ID:-97}
export L1_RPC_URL=${L1_RPC_URL:-http://13.212.114.138:10575}

# 进入 ecosystem 目录
cd /app/tmai_ecosystem

# 启动服务器
echo "启动 ZKsync Server..."
echo "Chain: tmai_chain"
echo "L1 RPC: $L1_RPC_URL"
echo ""

exec zkstack server --chain tmai_chain
