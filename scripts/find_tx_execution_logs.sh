#!/bin/bash

SERVER="ubuntu@54.255.184.251"
KEY="~/zk_gas.pem"

echo "🔍 查找单笔交易执行日志"
echo "========================================"

ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node

echo ""
echo "1️⃣ 查找'finished tx'日志:"
docker compose logs --tail=2000 tmai-server 2>&1 | grep "finished tx" | tail -20

echo ""
echo "2️⃣ 查找'Decided to seal'日志:"
docker compose logs --tail=2000 tmai-server 2>&1 | grep "Decided to seal" | tail -20

echo ""
echo "3️⃣ 查找包含交易hash的日志:"
docker compose logs --tail=2000 tmai-server 2>&1 | grep "0x2af81ccb\|0x20f11dc4\|0xa52ba067" | head -30

echo ""
echo "4️⃣ 查找state_keeper相关的DEBUG日志:"
docker compose logs --tail=2000 tmai-server 2>&1 | grep "state_keeper" | grep -i "debug\|trace" | tail -30

echo ""
echo "5️⃣ 查找L2 block seal相关日志:"
docker compose logs --tail=2000 tmai-server 2>&� | grep -E "seal.*L2 block|miniblock.*seal" | tail -20

EOF

echo ""
echo "✅ 完成"
