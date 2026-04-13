#!/bin/bash
set -e

echo "🔧 更新配置到远程服务器 (2核4G优化版)"

SERVER="ubuntu@54.255.184.251"
KEY="~/zk_gas.pem"
REMOTE_PATH="/home/ubuntu/node"

echo "📤 上传优化配置..."
scp -i $KEY tmai_ecosystem/chains/tmai_chain/configs/general.yaml \
    $SERVER:$REMOTE_PATH/tmai_ecosystem/chains/tmai_chain/configs/

echo "🔄 重启服务..."
ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node
docker compose down
docker compose up -d
echo "✅ 服务已重启"
EOF

echo ""
echo "⏳ 等待30秒让服务启动..."
sleep 30

echo ""
echo "🔍 检查服务状态..."
ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node
docker compose ps
docker compose logs --tail=50 tmai-server
EOF

echo ""
echo "✅ 配置更新完成！"
echo ""
echo "📊 测试命令："
echo "   node scripts/test_node_api.js"
echo "   node scripts/simple_stress_test.js"
