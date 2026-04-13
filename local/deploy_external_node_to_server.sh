#!/bin/bash

# 在服务器上部署外部节点

set -e

SERVER_IP="54.255.184.251"
SSH_KEY="zk_gas.pem"
SERVER_USER="ubuntu"
SERVER_PATH="/home/ubuntu/node"

echo "=== 部署外部节点到服务器 ==="
echo ""

# 1. 上传部署脚本
echo "1️⃣ 上传部署脚本..."
scp -i $SSH_KEY server/deploy_external_node.sh $SERVER_USER@$SERVER_IP:$SERVER_PATH/

echo ""
echo "2️⃣ 在服务器上执行部署..."
ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP << 'ENDSSH'
cd /home/ubuntu/node

# 设置执行权限
chmod +x deploy_external_node.sh

# 执行部署
bash deploy_external_node.sh
ENDSSH

echo ""
echo "========================================="
echo "  ✅ 部署完成！"
echo "========================================="
echo ""
echo "外部节点已部署到服务器"
echo ""
echo "访问外部节点:"
echo "  HTTP RPC: http://54.255.184.251:4050"
echo "  WS RPC:   ws://54.255.184.251:4051"
echo ""
echo "查看日志:"
echo "  ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP"
echo "  docker logs -f tmai-external-node"

