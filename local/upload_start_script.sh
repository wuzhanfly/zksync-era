#!/bin/bash

# 上传启动脚本和配置到服务器

set -e

SERVER_IP="54.255.184.251"
SSH_KEY="/home/jerry/zk_gas.pem"
SERVER_USER="ubuntu"
SERVER_PATH="/home/ubuntu/node"

echo "=== 上传启动脚本到服务器 ==="
echo ""

# 1. 上传 docker-compose.yml
echo "1️⃣ 上传 docker-compose.yml..."
scp -i $SSH_KEY server/docker-compose.yml $SERVER_USER@$SERVER_IP:$SERVER_PATH/

# 2. 上传启动脚本
echo "2️⃣ 上传启动脚本..."
scp -i $SSH_KEY server/start_tmai_server.sh $SERVER_USER@$SERVER_IP:$SERVER_PATH/

# 3. 设置执行权限并启动
echo "3️⃣ 在服务器上设置权限并启动..."
ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP << 'ENDSSH'
cd /home/ubuntu/node

# 设置执行权限
chmod +x start_tmai_server.sh

echo ""
echo "✅ 文件已上传"
echo ""
echo "========================================="
echo "  准备启动 tMai Server"
echo "========================================="
echo ""

# 启动服务
bash start_tmai_server.sh
ENDSSH

echo ""
echo "========================================="
echo "  ✅ 完成！"
echo "========================================="
echo ""
echo "查看服务器日志:"
echo "  ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP"
echo "  docker logs -f tmai-server"

