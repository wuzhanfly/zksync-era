#!/bin/bash

echo "🚀 部署优化配置到服务器"

# 上传配置
scp -i ~/zk_gas.pem \
    tmai_ecosystem/chains/tmai_chain/configs/general.yaml \
    ubuntu@54.255.184.251:/home/ubuntu/node/tmai_ecosystem/chains/tmai_chain/configs/

# 重启节点
ssh -i ~/zk_gas.pem ubuntu@54.255.184.251 << 'EOF'
cd /home/ubuntu/node
echo "停止节点..."
docker-compose down
echo "启动节点..."
docker-compose up -d
echo "等待节点启动..."
sleep 30
echo "检查节点状态..."
curl -s http://localhost:3071/health | jq .
EOF

echo "✅ 部署完成！"
echo ""
echo "关键优化:"
echo "  • block_commit_deadline: 3000ms → 1000ms"
echo "  • miniblock_commit_deadline: 1000ms → 500ms"
echo "  • miniblock_seal_queue_capacity: 10 → 100"
echo "  • transaction_slots: 10000 → 50000"
echo "  • max_gas_per_batch: 200M → 500M"
echo "  • mempool capacity: 10M → 50M"
echo "  • max_connections: 200 → 500"
echo ""
echo "现在可以运行压测: cd stress-test && npm run seq"
