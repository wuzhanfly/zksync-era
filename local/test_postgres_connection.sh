#!/bin/bash

set -e

SERVER_IP="54.255.184.251"
DB_PORT="5432"
DB_USER="postgres"
DB_PASSWORD="notsecurepassword"

echo "=== 测试服务器 PostgreSQL 连接 ==="
echo ""
echo "服务器: $SERVER_IP:$DB_PORT"
echo "用户: $DB_USER"
echo ""

# 检查 psql 是否安装
if ! command -v psql &> /dev/null; then
    echo "❌ psql 未安装"
    echo ""
    echo "安装方法:"
    echo "  Ubuntu/Debian: sudo apt-get install postgresql-client"
    echo "  macOS: brew install postgresql"
    echo "  或使用 Docker: docker run --rm -it postgres:14 psql -h $SERVER_IP -U $DB_USER"
    exit 1
fi

echo "1️⃣ 测试连接..."
if PGPASSWORD=$DB_PASSWORD psql -h $SERVER_IP -p $DB_PORT -U $DB_USER -d postgres -c '\q' 2>/dev/null; then
    echo "✅ 连接成功！"
else
    echo "❌ 连接失败"
    echo ""
    echo "可能的原因:"
    echo "  1. 服务器上 PostgreSQL 未启动"
    echo "  2. 防火墙阻止了 5432 端口"
    echo "  3. PostgreSQL 未配置允许远程连接"
    echo ""
    echo "解决方法:"
    echo "  1. SSH 到服务器: ssh -i zk_gas.pem ubuntu@54.255.184.251"
    echo "  2. 进入目录: cd /home/ubuntu/node"
    echo "  3. 运行设置脚本: ./setup_postgres.sh"
    exit 1
fi

echo ""
echo "2️⃣ 列出数据库..."
PGPASSWORD=$DB_PASSWORD psql -h $SERVER_IP -p $DB_PORT -U $DB_USER -d postgres -c '\l'

echo ""
echo "3️⃣ 检查 ZKsync 数据库..."
DB_EXISTS=$(PGPASSWORD=$DB_PASSWORD psql -h $SERVER_IP -p $DB_PORT -U $DB_USER -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='zksync_server_bsc_testnet_tmai_chain'" 2>/dev/null || echo "")

if [ "$DB_EXISTS" = "1" ]; then
    echo "⚠️  数据库 'zksync_server_bsc_testnet_tmai_chain' 已存在"
    echo ""
    echo "如果需要重新部署，请先删除数据库:"
    echo "  PGPASSWORD=$DB_PASSWORD psql -h $SERVER_IP -p $DB_PORT -U $DB_USER -d postgres -c 'DROP DATABASE IF EXISTS zksync_server_bsc_testnet_tmai_chain;'"
else
    echo "✅ 数据库不存在，可以开始部署"
fi

echo ""
echo "========================================="
echo "  ✅ PostgreSQL 连接测试完成！"
echo "========================================="
echo ""
echo "连接字符串:"
echo "  postgres://$DB_USER:$DB_PASSWORD@$SERVER_IP:$DB_PORT/zksync_server_bsc_testnet_tmai_chain"
echo ""
echo "下一步:"
echo "  运行合约部署: ./local/deploy_contracts.sh"
echo ""

