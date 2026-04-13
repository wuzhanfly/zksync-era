#!/bin/bash

set -e

echo "=== 本地构建 Docker 镜像 ==="
echo ""

# 检查是否已编译
if [ ! -f "core/target/release/zksync_server" ]; then
    echo "❌ zksync_server 未编译"
    echo "请先运行: cargo build --manifest-path ./core/Cargo.toml --release --bin zksync_server"
    exit 1
fi

# 检查 zkstack
if ! command -v zkstack &> /dev/null; then
    echo "❌ zkstack 未安装"
    echo "请先运行: cargo install --path zkstack_cli/crates/zkstack --locked"
    exit 1
fi

echo "✅ 二进制文件检查通过"
echo ""

# 复制二进制文件到 target/release（Docker 期望的位置）
echo "准备文件..."
mkdir -p target/release
cp core/target/release/zksync_server target/release/
cp $(which zkstack) target/release/

# 构建 Docker 镜像
echo "构建 Docker 镜像..."
docker build -f docker/Dockerfile.prebuilt -t tmai-server:latest .

echo ""
echo "✅ Docker 镜像构建完成"
echo ""

# 显示镜像信息
docker images | grep tmai-server

echo ""
echo "镜像标签: tmai-server:latest"
echo ""
echo "下一步:"
echo "  1. 保存镜像: ./local/save_docker.sh"
echo "  2. 上传到服务器"
echo "  3. 在服务器加载并运行"
echo ""
