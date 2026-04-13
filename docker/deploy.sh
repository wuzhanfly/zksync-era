#!/bin/bash

set -e

echo "=== tMai Chain 完整部署脚本 ==="
echo ""

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装"
    echo "安装: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose 未安装"
    exit 1
fi

echo "✅ Docker 环境检查通过"
echo ""

# 步骤 1: 构建镜像
echo "=== 步骤 1/4: 构建 Docker 镜像 ==="
echo "这可能需要 20-30 分钟..."
docker-compose -f docker-compose.tmai.yml build

echo ""
echo "=== 步骤 2/4: 启动数据库 ==="
docker-compose -f docker-compose.tmai.yml up -d postgres

echo "等待数据库启动..."
sleep 10

# 步骤 2: 初始化链
echo ""
echo "=== 步骤 3/4: 初始化链 ==="
echo "这将创建 ecosystem、部署合约、生成 genesis..."
docker-compose -f docker-compose.tmai.yml --profile init run --rm tmai-init

if [ $? -ne 0 ]; then
    echo "❌ 链初始化失败"
    echo "查看日志: docker-compose -f docker-compose.tmai.yml logs tmai-init"
    exit 1
fi

echo ""
echo "✅ 链初始化完成"

# 步骤 3: 启动服务器
echo ""
echo "=== 步骤 4/4: 启动 tMai Server ==="
docker-compose -f docker-compose.tmai.yml up -d tmai-server

echo ""
echo "等待服务启动（约 30 秒）..."
sleep 30

# 检查服务状态
echo ""
echo "=== 服务状态 ==="
docker-compose -f docker-compose.tmai.yml ps

echo ""
echo "=== 健康检查 ==="
for i in {1..30}; do
    if curl -s http://localhost:3071/health > /dev/null 2>&1; then
        echo "✅ 服务健康检查通过"
        break
    fi
    echo "等待服务就绪... ($i/30)"
    sleep 2
done

# 测试 RPC
echo ""
echo "=== 测试 RPC 端点 ==="
BLOCK=$(curl -s -X POST http://localhost:3050 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r .result 2>/dev/null)

if [ -n "$BLOCK" ] && [ "$BLOCK" != "null" ]; then
    echo "✅ RPC 正常，当前区块: $BLOCK"
else
    echo "⚠️  RPC 可能还未就绪，请稍后再试"
fi

echo ""
echo "========================================="
echo "  🎉 部署完成！"
echo "========================================="
echo ""
echo "服务访问:"
echo "  HTTP RPC:  http://localhost:3050"
echo "  WS RPC:    ws://localhost:3051"
echo "  Health:    http://localhost:3071/health"
echo "  Metrics:   http://localhost:3312/metrics"
echo ""
echo "管理命令:"
echo "  查看日志:   docker-compose -f docker-compose.tmai.yml logs -f tmai-server"
echo "  停止服务:   docker-compose -f docker-compose.tmai.yml down"
echo "  重启服务:   docker-compose -f docker-compose.tmai.yml restart tmai-server"
echo "  查看状态:   docker-compose -f docker-compose.tmai.yml ps"
echo ""
echo "测试交易:"
echo "  node scripts/test_simple_transfer.js"
echo ""
