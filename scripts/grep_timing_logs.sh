#!/bin/bash

SERVER="ubuntu@54.255.184.251"
KEY="~/zk_gas.pem"

echo "⏱️  提取所有带时间的日志"
echo "========================================"

ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node

echo ""
echo "1️⃣ Commitment generator (L1 batch处理):"
docker compose logs --tail=1000 tmai-server 2>&1 | grep "commitment_generator.*in.*s$" | tail -10

echo ""
echo "2️⃣ L2 block执行阶段:"
docker compose logs --tail=1000 tmai-server 2>&1 | grep "L2 block execution stage.*took" | tail -10

echo ""
echo "3️⃣ L1 batch执行阶段:"
docker compose logs --tail=1000 tmai-server 2>&1 | grep "L1 batch execution stage.*took" | tail -10

echo ""
echo "4️⃣ 所有包含'in.*s$'的日志:"
docker compose logs --tail=1000 tmai-server 2>&1 | grep -E "in [0-9]+\.[0-9]+.*s$" | tail -20

echo ""
echo "5️⃣ 所有包含'took.*ms'的日志:"
docker compose logs --tail=1000 tmai-server 2>&1 | grep -E "took.*[0-9]+ms" | tail -20

EOF

echo ""
echo "✅ 完成"
