#!/bin/bash

set -e

echo "=== 构建优化的 server-v2 镜像 ==="
echo ""

# 检查合约是否已编译
if [ ! -d "contracts/system-contracts/zkout" ]; then
    echo "❌ 合约未编译"
    echo "请先运行: zkstack dev contracts"
    exit 1
fi

echo "✅ 合约已准备"
echo ""

# 下载 setup key（如果不存在）
if [ ! -f "setup_2^26.key" ]; then
    echo "下载 setup key..."
    curl -LO https://storage.googleapis.com/matterlabs-setup-keys-us/setup-keys/setup_2\^26.key
    echo "✅ Setup key 已下载"
else
    echo "✅ Setup key 已存在"
fi

echo ""
echo "开始构建 Docker 镜像..."
echo "这可能需要 10-30 分钟..."
echo ""

# 构建镜像
docker build \
    --file docker/server-v2/Dockerfile \
    --tag tmai-server:2.0 \
    --tag tmai-server:latest \
    .

echo ""
echo "========================================="
echo "  ✅ 镜像构建完成！"
echo "========================================="
echo ""

# 显示镜像信息
docker images | grep tmai-server

echo ""
echo "镜像标签:"
echo "  - tmai-server:2.0"
echo "  - tmai-server:latest"
echo ""
echo "镜像大小应该在 500-800MB 左右"
echo ""
echo "下一步:"
echo "  1. 保存镜像: docker save tmai-server:latest | gzip > tmai-server.tar.gz"
echo "  2. 上传到服务器: scp -i zk_gas.pem tmai-server.tar.gz ubuntu@54.255.184.251:/home/ubuntu/node/"
echo "  3. 在服务器加载: docker load < tmai-server.tar.gz"
echo ""

