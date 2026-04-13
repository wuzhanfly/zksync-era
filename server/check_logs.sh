#!/bin/bash

SERVER="ubuntu@54.255.184.251"
KEY="~/zk_gas.pem"

echo "📋 查看服务器日志"
echo "========================================"

ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node

echo ""
echo "最近50行日志:"
echo "---"
docker compose logs --tail=50 --timestamps tmai-server 2>&1

EOF

echo ""
echo "✅ 完成"
