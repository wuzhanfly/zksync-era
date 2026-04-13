#!/bin/bash
# 从主节点导出数据库

set -e

MAIN_NODE_IP="54.255.184.251"
MAIN_NODE_SSH_KEY="$HOME/zk_gas.pem"

echo "=== 从主节点导出数据库 ==="
echo ""

# 在主节点上导出数据库
echo "1️⃣ 连接到主节点并导出数据库..."
ssh -i $MAIN_NODE_SSH_KEY ubuntu@$MAIN_NODE_IP << 'ENDSSH'
cd /home/ubuntu/node

echo "导出数据库..."
docker exec tmai-postgres pg_dump -U postgres -Fc postgres_postgres_notsecurepassword_54_255_184_251_5432_zksync_ > /tmp/tmai_db_export.dump

echo "压缩导出文件..."
gzip /tmp/tmai_db_export.dump

ls -lh /tmp/tmai_db_export.dump.gz
ENDSSH

echo "✅ 数据库已导出"
echo ""

# 下载到本地
echo "2️⃣ 下载数据库到本地..."
scp -i $MAIN_NODE_SSH_KEY ubuntu@$MAIN_NODE_IP:/tmp/tmai_db_export.dump.gz /tmp/
echo "✅ 下载完成"

# 清理主节点临时文件
ssh -i $MAIN_NODE_SSH_KEY ubuntu@$MAIN_NODE_IP "rm /tmp/tmai_db_export.dump.gz"

echo ""
echo "========================================="
echo "  ✅ 导出完成！"
echo "========================================="
echo ""
echo "数据库文件: /tmp/tmai_db_export.dump.gz"
echo ""
echo "下一步:"
echo "  bash external_node/import_db_to_external_node.sh"
