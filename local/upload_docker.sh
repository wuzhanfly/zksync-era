#!/bin/bash

set -e

SERVER="ubuntu@54.255.184.251"
KEY="/home/jerry/zk_gas.pem"
REMOTE_PATH="/home/ubuntu/node"
IMAGE_FILE="tmai-server.tar.gz"

echo "=== 上传 Docker 镜像到服务器 ==="
echo ""

# 检查镜像文件
if [ ! -f "$IMAGE_FILE" ]; then
    echo "❌ 镜像文件不存在: $IMAGE_FILE"
    echo "请先运行: ./local/save_docker.sh"
    exit 1
fi

# 检查 SSH 密钥
if [ ! -f "$KEY" ]; then
    echo "❌ SSH 密钥不存在: $KEY"
    exit 1
fi

chmod 600 $KEY

echo "上传镜像文件 ($(du -h $IMAGE_FILE | cut -f1))..."
echo "这可能需要几分钟..."
scp -i $KEY $IMAGE_FILE $SERVER:$REMOTE_PATH/

echo ""
echo "在服务器上加载镜像..."
ssh -i $KEY $SERVER << EOF
cd $REMOTE_PATH
echo "解压并加载镜像..."
docker load < $IMAGE_FILE
rm $IMAGE_FILE
echo "✅ 镜像已加载"
docker images | grep tmai-server
EOF

echo ""
echo "========================================="
echo "  ✅ Docker 镜像已部署到服务器！"
echo "========================================="
echo ""
echo "下一步:"
echo "  1. 上传 tmai_ecosystem: ./local/upload_ecosystem.sh"
echo "  2. 启动服务器: ssh 到服务器运行 start.sh"
echo ""
