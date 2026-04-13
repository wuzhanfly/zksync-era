#!/bin/bash

# 构建 External Node Docker 镜像

set -e

echo "=== 构建 tMai External Node 镜像 ==="
echo ""

# 检查是否在项目根目录
if [ ! -f "docker/external-node/Dockerfile" ]; then
    echo "❌ 请在项目根目录运行此脚本"
    exit 1
fi

# 构建镜像
echo "📦 开始构建 External Node 镜像..."
echo "   这可能需要 20-30 分钟..."
echo ""

# 使用修复版 Dockerfile (包含 git)
docker build \
    -f docker/external-node/Dockerfile.fixed \
    -t tmai-external-node:latest \
    .

echo ""
echo "✅ 镜像构建完成！"
echo ""
echo "镜像信息:"
docker images | grep tmai-external-node

echo ""
echo "下一步:"
echo "  bash external_node/deploy_official_external_node.sh"
