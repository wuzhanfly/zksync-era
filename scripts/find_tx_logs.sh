#!/bin/bash

SERVER="ubuntu@54.255.184.251"
KEY="~/zk_gas.pem"

echo "🔍 查找交易处理日志"
echo "========================================"

ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node

echo ""
echo "最近500行日志中包含'finished tx'的:"
docker compose logs --tail=500 tmai-server 2>&1 | grep -i "finished tx"

echo ""
echo "最近500行日志中包含'took'的:"
docker compose logs --tail=500 tmai-server 2>&1 | grep -i "took"

echo ""
echo "最近500行日志中包含'execution'的:"
docker compose logs --tail=500 tmai-server 2>&1 | grep -i "execution" | head -20

echo ""
echo "最近500行日志中包含'seal'的:"
docker compose logs --tail=500 tmai-server 2>&1 | grep -i "seal" | head -20

EOF

echo ""
echo "✅ 完成"
