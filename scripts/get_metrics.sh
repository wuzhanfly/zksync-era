#!/bin/bash

SERVER="ubuntu@54.255.184.251"
KEY="~/zk_gas.pem"

echo "📊 获取Prometheus性能指标"
echo "========================================"

ssh -i $KEY $SERVER << 'EOF'
echo ""
echo "1️⃣ 交易执行时间 (tx_execution_time):"
curl -s http://localhost:3314/metrics | grep "server_state_keeper_tx_execution_time" | grep -v "#"

echo ""
echo "2️⃣ 批处理执行器响应时间 (batch_executor_command_response_time):"
curl -s http://localhost:3314/metrics | grep "state_keeper_batch_executor_command_response_time" | grep -v "#" | grep "execute_tx"

echo ""
echo "3️⃣ 存储交互时间 (batch_storage_interaction_duration):"
curl -s http://localhost:3314/metrics | grep "state_keeper_batch_storage_interaction_duration" | grep -v "#"

echo ""
echo "4️⃣ 区块封装时间 (sealed_time):"
curl -s http://localhost:3314/metrics | grep "sealed_time" | grep -v "#" | head -20

echo ""
echo "5️⃣ 外部执行时间 (execute_tx_outer_time):"
curl -s http://localhost:3314/metrics | grep "execute_tx_outer_time" | grep -v "#"

echo ""
echo "6️⃣ Gas使用统计:"
curl -s http://localhost:3314/metrics | grep "computational_gas" | grep -v "#"

EOF

echo ""
echo "✅ 完成"
