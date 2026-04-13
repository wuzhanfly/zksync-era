#!/bin/bash

set -e

echo "=== 编译 ZKsync Server ==="
echo ""

# 编译 zksync_server
echo "编译 zksync_server (这可能需要 20-30 分钟)..."
cargo build --manifest-path ./core/Cargo.toml --release --bin zksync_server

if [ $? -eq 0 ]; then
    echo "✅ zksync_server 编译完成"
    echo "位置: core/target/release/zksync_server"
else
    echo "❌ 编译失败"
    exit 1
fi

echo ""
echo "=== 安装 zkstack CLI ==="
cargo install --path zkstack_cli/crates/zkstack --locked

if [ $? -eq 0 ]; then
    echo "✅ zkstack 安装完成"
    echo "位置: $(which zkstack)"
else
    echo "❌ 安装失败"
    exit 1
fi

echo ""
echo "========================================="
echo "  ✅ 编译完成！"
echo "========================================="
echo ""
echo "下一步:"
echo "  构建 Docker 镜像: ./local/build_docker.sh"
echo ""
