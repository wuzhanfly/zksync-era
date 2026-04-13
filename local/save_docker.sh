#!/bin/bash

set -e

echo "=== 保存 Docker 镜像 ==="
echo ""

IMAGE_NAME="tmai-server:latest"
OUTPUT_FILE="tmai-server.tar.gz"

# 检查镜像是否存在
if ! docker images | grep -q "tmai-server"; then
    echo "❌ 镜像不存在"
    echo "请先运行: ./local/build_docker.sh"
    exit 1
fi

echo "保存镜像到文件..."
docker save $IMAGE_NAME | gzip > $OUTPUT_FILE

echo ""
echo "✅ 镜像已保存"
echo ""
echo "文件: $OUTPUT_FILE"
echo "大小: $(du -h $OUTPUT_FILE | cut -f1)"
echo ""
echo "下一步:"
echo "  上传到服务器: ./local/upload_docker.sh"
echo ""
