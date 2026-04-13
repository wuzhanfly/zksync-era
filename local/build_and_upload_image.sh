#!/bin/bash

# 构建 Docker 镜像并上传到服务器

set -e

SERVER_IP="54.255.184.251"
SSH_KEY="zk_gas.pem"
SERVER_USER="ubuntu"
SERVER_PATH="/home/ubuntu/node"

echo "=== 构建并上传 tMai Server 镜像 ==="
echo ""

# 1. 构建镜像
echo "1️⃣ 构建 Docker 镜像..."
echo "   这可能需要 10-20 分钟..."
echo ""

docker build \
    -f docker/server-v2/Dockerfile.minimal \
    -t tmai-server:minimal \
    .

if [ $? -ne 0 ]; then
    echo "❌ 镜像构建失败"
    exit 1
fi

echo ""
echo "✅ 镜像构建完成"

# 2. 显示镜像信息
echo ""
echo "2️⃣ 镜像信息："
docker images | grep -E "REPOSITORY|tmai-server"

# 3. 保存镜像
echo ""
echo "3️⃣ 保存镜像到文件..."
docker save tmai-server:minimal | gzip > tmai-server.tar.gz

IMAGE_SIZE=$(du -h tmai-server.tar.gz | cut -f1)
echo "✅ 镜像已保存: tmai-server.tar.gz ($IMAGE_SIZE)"

# 4. 上传到服务器
echo ""
echo "4️⃣ 上传镜像到服务器..."
echo "   服务器: $SERVER_USER@$SERVER_IP"
echo "   路径: $SERVER_PATH"
echo ""

scp -i $SSH_KEY tmai-server.tar.gz $SERVER_USER@$SERVER_IP:$SERVER_PATH/

if [ $? -ne 0 ]; then
    echo "❌ 上传失败"
    exit 1
fi

echo ""
echo "✅ 上传完成"

# 5. 在服务器上加载镜像
echo ""
echo "5️⃣ 在服务器上加载镜像..."

ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP << 'ENDSSH'
cd /home/ubuntu/node

echo "加载 Docker 镜像..."
docker load < tmai-server.tar.gz

echo "标记镜像为 latest..."
docker tag tmai-server:minimal tmai-server:latest

echo "清理压缩文件..."
rm -f tmai-server.tar.gz

echo ""
echo "✅ 镜像加载完成"
echo ""
echo "📊 服务器上的镜像："
docker images | grep -E "REPOSITORY|tmai-server"
ENDSSH

# 6. 清理本地文件
echo ""
echo "6️⃣ 清理本地文件..."
rm -f tmai-server.tar.gz
echo "✅ 本地文件已清理"

echo ""
echo "========================================="
echo "  ✅ 镜像构建并上传完成！"
echo "========================================="
echo ""
echo "下一步："
echo "  ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP"
echo "  cd $SERVER_PATH"
echo "  bash check_and_start.sh"

