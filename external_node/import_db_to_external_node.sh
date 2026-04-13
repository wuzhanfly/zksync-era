#!/bin/bash
# 导入数据库到 External Node

set -e

EXTERNAL_NODE_IP="13.228.79.240"
EXTERNAL_NODE_SSH_KEY="$HOME/zk_node1.pem"

echo "=== 导入数据库到 External Node ==="
echo ""

# 上传数据库文件
echo "1️⃣ 上传数据库文件到外部节点..."
scp -i $EXTERNAL_NODE_SSH_KEY /tmp/tmai_db_export.dump.gz ubuntu@$EXTERNAL_NODE_IP:/tmp/
echo "✅ 上传完成"
echo ""

# 导入数据库
echo "2️⃣ 导入数据库..."
ssh -i $EXTERNAL_NODE_SSH_KEY ubuntu@$EXTERNAL_NODE_IP << 'ENDSSH'
cd /home/ubuntu/e-node1

echo "停止 External Node..."
docker compose stop external-node

echo "解压数据库文件..."
gunzip /tmp/tmai_db_export.dump.gz

echo "清空现有数据库..."
docker exec tmai-external-postgres psql -U postgres -c "DROP DATABASE IF EXISTS zksync_external_node;"
docker exec tmai-external-postgres psql -U postgres -c "CREATE DATABASE zksync_external_node;"

echo "导入数据库..."
docker exec -i tmai-external-postgres pg_restore -U postgres -d zksync_external_node < /tmp/tmai_db_export.dump

echo "清理临时文件..."
rm /tmp/tmai_db_export.dump

echo "✅ 数据库导入完成"
echo ""
echo "启动 External Node..."
docker compose start external-node

sleep 15
echo ""
echo "📊 容器状态:"
docker ps | grep tmai-external

echo ""
echo "📝 日志:"
docker logs --tail 30 tmai-external-node
ENDSSH

echo ""
echo "========================================="
echo "  ✅ 导入完成！"
echo "========================================="
echo ""
echo "验证:"
echo "  curl -X POST http://$EXTERNAL_NODE_IP:4050 \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'"
