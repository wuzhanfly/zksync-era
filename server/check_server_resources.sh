#!/bin/bash

SERVER="ubuntu@54.255.184.251"
KEY="~/zk_gas.pem"

echo "🖥️  服务器资源状态 (2核4G)"
echo "========================================"

ssh -i $KEY $SERVER << 'EOF'
echo ""
echo "📊 CPU 和内存使用:"
echo "---"
top -bn1 | head -5

echo ""
echo "💾 内存详情:"
echo "---"
free -h

echo ""
echo "💿 磁盘使用:"
echo "---"
df -h /home/ubuntu/node

echo ""
echo "🐳 Docker 容器状态:"
echo "---"
cd /home/ubuntu/node
docker-compose ps

echo ""
echo "📈 Docker 容器资源使用:"
echo "---"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

echo ""
echo "🔍 PostgreSQL 连接数:"
echo "---"
docker exec postgres psql -U postgres -d zksync_server_bsc_testnet_tmai_chain -c "SELECT count(*) as connections FROM pg_stat_activity;" 2>/dev/null || echo "无法查询"

echo ""
echo "📝 最近日志 (最后20行):"
echo "---"
docker-compose logs --tail=20 tmai-server 2>&1 | tail -20
EOF

echo ""
echo "✅ 检查完成"
