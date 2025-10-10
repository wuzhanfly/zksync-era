#!/bin/bash

# 拉取浏览器 Docker 镜像脚本

echo "🚀 开始拉取 ZKStack 浏览器镜像..."

IMAGES=(
    "matterlabs/block-explorer-api:v2.73.1"
    "matterlabs/block-explorer-data-fetcher:v2.73.1"
    "matterlabs/block-explorer-worker:v2.73.1"
)

for image in "${IMAGES[@]}"; do
    echo ""
    echo "📦 拉取镜像: $image"
    if docker pull "$image"; then
        echo "✅ 成功拉取: $image"
    else
        echo "❌ 拉取失败: $image"
    fi
done

echo ""
echo "🔍 检查已拉取的镜像:"
docker images | grep block-explorer

echo ""
echo "🎉 镜像拉取完成！"