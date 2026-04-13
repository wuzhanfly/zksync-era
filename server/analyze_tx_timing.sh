#!/bin/bash

SERVER="ubuntu@54.255.184.251"
KEY="~/zk_gas.pem"

echo "⏱️  分析交易处理时间"
echo "========================================"

ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node

echo ""
echo "1️⃣ 最近的交易执行日志 (execute_tx):"
echo "---"
docker-compose logs --tail=200 tmai-server 2>&1 | grep -i "execute_tx\|finished tx\|execution_metrics" | tail -20

echo ""
echo "2️⃣ State Keeper 处理时间:"
echo "---"
docker-compose logs --tail=200 tmai-server 2>&1 | grep -i "state_keeper\|process_block\|seal" | tail -20

echo ""
echo "3️⃣ 数据库操作时间:"
echo "---"
docker-compose logs --tail=200 tmai-server 2>&1 | grep -i "postgres\|db\|storage" | tail -15

echo ""
echo "4️⃣ VM 执行时间:"
echo "---"
docker-compose logs --tail=200 tmai-server 2>&1 | grep -i "vm\|bootloader\|execution" | tail -15

echo ""
echo "5️⃣ 区块封装时间:"
echo "---"
docker-compose logs --tail=200 tmai-server 2>&1 | grep -i "seal.*block\|commit.*block" | tail -15

echo ""
echo "6️⃣ 查看最近的性能指标:"
echo "---"
docker-compose logs --tail=500 tmai-server 2>&1 | grep -E "took|duration|latency|ms|seconds" | tail -20

EOF

echo ""
echo "✅ 分析完成"
