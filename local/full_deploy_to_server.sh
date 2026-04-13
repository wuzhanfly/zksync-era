#!/bin/bash

set -e

SERVER="ubuntu@54.255.184.251"
KEY="zk_gas.pem"
REMOTE_PATH="/home/ubuntu/node"

echo "========================================="
echo "  完整服务器部署流程"
echo "========================================="
echo ""

# 检查 SSH 密钥
if [ ! -f "$KEY" ]; then
    echo "❌ SSH 密钥不存在: $KEY"
    exit 1
fi

chmod 600 $KEY

echo "步骤 1/6: 上传 docker-compose.yml 和脚本"
echo "========================================="
scp -i $KEY server/docker-compose.postgres.yml $SERVER:$REMOTE_PATH/
scp -i $KEY server/docker-compose.yml $SERVER:$REMOTE_PATH/
scp -i $KEY server/setup_postgres.sh $SERVER:$REMOTE_PATH/
scp -i $KEY server/start_server.sh $SERVER:$REMOTE_PATH/
ssh -i $KEY $SERVER "chmod +x $REMOTE_PATH/*.sh"
echo "✅ 文件已上传"
echo ""

echo "步骤 2/6: 在服务器上启动 PostgreSQL"
echo "========================================="
ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node
./setup_postgres.sh
EOF
echo "✅ PostgreSQL 已启动"
echo ""

echo "步骤 3/6: 测试 PostgreSQL 连接"
echo "========================================="
./local/test_postgres_connection.sh
echo ""

echo "步骤 4/6: 删除旧的 tmai_ecosystem (如果存在)"
echo "========================================="
if [ -d "tmai_ecosystem" ]; then
    echo "删除旧的 tmai_ecosystem..."
    rm -rf tmai_ecosystem
fi
echo "✅ 准备就绪"
echo ""

echo "步骤 5/6: 部署合约并创建 ecosystem"
echo "========================================="
echo "这将需要几分钟时间..."
./local/deploy_contracts.sh
echo ""

echo "步骤 6/6: 上传 tmai_ecosystem 到服务器"
echo "========================================="
./local/upload_ecosystem.sh
echo ""

echo "========================================="
echo "  🎉 部署完成！"
echo "========================================="
echo ""
echo "服务器文件结构:"
echo "  /home/ubuntu/node/"
echo "  ├── docker-compose.yml"
echo "  ├── setup_postgres.sh"
echo "  ├── start_server.sh"
echo "  └── tmai_ecosystem/"
echo ""
echo "下一步 - 启动服务器:"
echo "  ssh -i $KEY $SERVER"
echo "  cd $REMOTE_PATH"
echo "  ./start_server.sh"
echo ""
echo "或者远程启动:"
echo "  ssh -i $KEY $SERVER 'cd $REMOTE_PATH && ./start_server.sh'"
echo ""

