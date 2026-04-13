#!/bin/bash

set -e

echo "🚀 部署 BSC RPC 代理服务"
echo "================================"

# 创建日志目录
mkdir -p logs

# 检查 Docker 网络
if ! docker network inspect tmai-network >/dev/null 2>&1; then
    echo "📡 创建 Docker 网络: tmai-network"
    docker network create tmai-network
fi

# 停止旧容器
if docker ps -a | grep -q bsc-rpc-proxy; then
    echo "🛑 停止旧容器..."
    docker-compose down
fi

# 启动代理服务
echo "▶️  启动 RPC 代理服务..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 5

# 检查服务状态
if docker ps | grep -q bsc-rpc-proxy; then
    echo "✅ RPC 代理服务启动成功!"
    echo ""
    echo "📊 服务信息:"
    echo "  - HTTP 端口: 8545"
    echo "  - 健康检查: http://localhost:8545/health"
    echo "  - 日志目录: ./logs"
    echo ""
    echo "🔧 配置 zkSync 使用代理:"
    echo "  修改 secrets.yaml:"
    echo "  l1_rpc_url: http://bsc-rpc-proxy:8545"
    echo ""
    echo "📝 查看日志:"
    echo "  docker-compose logs -f"
    echo ""
    echo "🧪 测试 RPC:"
    echo "  curl -X POST http://localhost:8545 \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'"
else
    echo "❌ RPC 代理服务启动失败"
    echo "查看日志: docker-compose logs"
    exit 1
fi
