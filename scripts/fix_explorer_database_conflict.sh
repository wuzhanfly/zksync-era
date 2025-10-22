#!/bin/bash

# 修复浏览器数据库冲突的脚本

set -e

echo "🔧 修复浏览器数据库冲突问题..."

DB_NAME="zksync_server_bsc_testnet_bsc_test_chain"
EXPLORER_DB_NAME="bsc_test_chain_explorer"

echo "📋 问题分析:"
echo "============"
echo "❌ 错误: 数据库正在被其他用户访问"
echo "🔍 原因: ZKsync 节点正在使用该数据库"
echo "💡 解决: 使用不同的数据库名称或停止节点"

echo ""
echo "🔍 检查当前数据库连接..."
echo "=========================="

# 检查数据库连接
psql -h localhost -U postgres -d postgres -c "
SELECT datname, usename, application_name, state 
FROM pg_stat_activity 
WHERE datname = '$DB_NAME';" 2>/dev/null || echo "无法连接到数据库"

echo ""
echo "💡 解决方案选择:"
echo "================"
echo "方案1: 使用不同的数据库名称 (推荐)"
echo "方案2: 临时停止 ZKsync 节点"
echo "方案3: 强制终止数据库连接 (风险较高)"

echo ""
echo "🚀 方案1: 使用专用的浏览器数据库名称"
echo "====================================="

echo "建议使用以下数据库名称:"
echo "数据库名称: $EXPLORER_DB_NAME"
echo ""
echo "重新运行浏览器初始化:"
echo "zkstack explorer init"
echo ""
echo "当提示输入数据库名称时，使用: $EXPLORER_DB_NAME"

echo ""
echo "🛠️ 方案2: 临时停止节点后初始化"
echo "=============================="

cat << 'EOF'
1. 停止 ZKsync 节点:
   pkill -f zksync_server
   # 或者在运行节点的终端按 Ctrl+C

2. 运行浏览器初始化:
   zkstack explorer init

3. 重新启动 ZKsync 节点:
   zkstack server --chain bsc_test_chain
EOF

echo ""
echo "⚠️ 方案3: 强制终止数据库连接 (谨慎使用)"
echo "======================================="

cat << EOF
# 强制终止所有连接到该数据库的会话
psql -h localhost -U postgres -d postgres -c "
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"

# 然后删除数据库
dropdb -h localhost -U postgres $DB_NAME

# 重新运行浏览器初始化
zkstack explorer init
EOF

echo ""
echo "🎯 推荐操作步骤:"
echo "================"
echo "1. 重新运行: zkstack explorer init"
echo "2. 数据库 URL: postgres://postgres:notsecurepassword@localhost:5432"
echo "3. 数据库名称: $EXPLORER_DB_NAME"
echo "4. Prividium 模式: No"

echo ""
echo "📊 数据库名称说明:"
echo "=================="
echo "主节点数据库: $DB_NAME (ZKsync 节点使用)"
echo "浏览器数据库: $EXPLORER_DB_NAME (浏览器专用)"
echo ""
echo "这样可以避免冲突，两个服务使用不同的数据库。"

echo ""
echo "🔍 验证数据库状态:"
echo "=================="
echo "检查现有数据库:"
echo "psql -h localhost -U postgres -l"
echo ""
echo "检查数据库连接:"
echo "psql -h localhost -U postgres -d postgres -c \"SELECT datname, usename FROM pg_stat_activity WHERE datname LIKE '%bsc%';\""