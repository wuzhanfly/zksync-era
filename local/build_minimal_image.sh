#!/bin/bash

# 构建最小化的 tmai-server Docker 镜像

set -e

echo "=== 构建最小化 tmai-server 镜像 ==="
echo ""

# 检查 Dockerfile 是否存在
if [ ! -f "docker/server-v2/Dockerfile.minimal" ]; then
    echo "❌ 错误: docker/server-v2/Dockerfile.minimal 不存在"
    exit 1
fi

echo "📦 开始构建 Docker 镜像..."
echo "   Dockerfile: docker/server-v2/Dockerfile.minimal"
echo "   镜像名称: tmai-server:minimal"
echo ""

# 构建镜像
docker build \
    -f docker/server-v2/Dockerfile.minimal \
    -t tmai-server:minimal \
    .

echo ""
echo "✅ 镜像构建完成！"
echo ""

# 显示镜像信息
echo "📊 镜像信息："
docker images | grep -E "REPOSITORY|tmai-server"

echo ""
echo "========================================="
echo "  构建完成"
echo "========================================="
echo ""
echo "下一步："
echo "1. 保存镜像: docker save tmai-server:minimal | gzip > tmai-server-minimal.tar.gz"
echo "2. 上传到服务器: scp -i zk_gas.pem tmai-server-minimal.tar.gz ubuntu@54.255.184.251:~/node/"
echo "3. 在服务器加载: docker load < tmai-server-minimal.tar.gz"
echo "4. 标记镜像: docker tag tmai-server:minimal tmai-server:latest"

