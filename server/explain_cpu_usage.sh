#!/bin/bash

SERVER="ubuntu@54.255.184.251"
KEY="~/zk_gas.pem"

echo "🔍 详细CPU分析"
echo "========================================"

ssh -i $KEY $SERVER << 'EOF'
echo ""
echo "1️⃣ 系统整体CPU使用 (实际物理核心):"
echo "---"
mpstat 1 1 | tail -3

echo ""
echo "2️⃣ 每个CPU核心的使用率:"
echo "---"
mpstat -P ALL 1 1 | grep -E "CPU|Average"

echo ""
echo "3️⃣ 进程级别CPU使用 (Top 10):"
echo "---"
ps aux --sort=-%cpu | head -11

echo ""
echo "4️⃣ Docker容器线程数:"
echo "---"
echo "tmai-server 线程数: $(docker exec tmai-server ps -eLf 2>/dev/null | wc -l)"
echo "postgres 线程数: $(docker exec tmai-postgres ps -eLf 2>/dev/null | wc -l)"

echo ""
echo "5️⃣ 系统上下文切换和中断:"
echo "---"
vmstat 1 2 | tail -1

echo ""
echo "💡 解释:"
echo "Docker stats 显示的 CPU% 是所有线程的累计值"
echo "实际物理CPU使用率 = mpstat 显示的值"
echo "对于2核系统，Docker stats 可以显示到 200% 以上"
EOF

echo ""
echo "✅ 分析完成"
