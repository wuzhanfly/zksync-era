#!/bin/bash

echo "🔍 检查服务器状态"
echo "================================"

ssh -i ~/zk_gas.pem ubuntu@54.255.184.251 << 'EOF'
echo "1️⃣ Docker 容器状态:"
docker ps -a | grep tmai

echo ""
echo "2️⃣ 节点日志（最后20行）:"
docker logs tmai-server --tail 20

echo ""
echo "3️⃣ 系统资源:"
echo "CPU & 内存:"
top -bn1 | head -15

echo ""
echo "4️⃣ 网络连接:"
netstat -an | grep 3050 | head -10
EOF
