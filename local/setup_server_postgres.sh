#!/bin/bash

set -e

SERVER="ubuntu@54.255.184.251"
KEY="zk_gas.pem"
REMOTE_PATH="/home/ubuntu/node"

echo "=== 设置服务器 PostgreSQL ==="
echo ""

# 检查 SSH 密钥
if [ ! -f "$KEY" ]; then
    echo "❌ SSH 密钥不存在: $KEY"
    exit 1
fi

chmod 600 $KEY

echo "1️⃣ 上传 PostgreSQL docker-compose 文件..."
scp -i $KEY server/docker-compose.postgres.yml $SERVER:$REMOTE_PATH/
scp -i $KEY server/setup_postgres.sh $SERVER:$REMOTE_PATH/
ssh -i $KEY $SERVER "chmod +x $REMOTE_PATH/setup_postgres.sh"
echo "✅ 文件已上传"
echo ""

echo "2️⃣ 在服务器上启动 PostgreSQL..."
ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node
./setup_postgres.sh
EOF
echo ""

echo "3️⃣ 测试连接..."
sleep 5
./local/test_postgres_connection.sh

echo ""
echo "========================================="
echo "  ✅ PostgreSQL 设置完成！"
echo "========================================="
echo ""
echo "下一步:"
echo "  运行合约部署: ./local/deploy_contracts.sh"
echo ""

