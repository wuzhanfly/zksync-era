#!/bin/bash

# 简化的浏览器部署脚本

set -e

echo "🚀 部署 ZKStack 浏览器组件..."

CHAIN_NAME="era"
EXPLORER_DB_NAME="era_explorer"
DB_URL="postgres://postgres:notsecurepassword@localhost:5432"

echo "📋 部署参数:"
echo "============"
echo "链名称: $CHAIN_NAME"
echo "浏览器数据库: $EXPLORER_DB_NAME"
echo "数据库 URL: $DB_URL"

# 检查 ZKsync 节点是否运行
echo ""
echo "🔍 检查 ZKsync 节点状态..."
if curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   http://localhost:3050 | grep -q "result"; then
    echo "✅ ZKsync 节点正在运行"
    NODE_RUNNING=true
else
    echo "❌ ZKsync 节点未运行"
    NODE_RUNNING=false
fi

# 检查数据库连接
echo ""
echo "🔍 检查数据库连接..."
if psql -h localhost -U postgres -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ 数据库连接正常"
else
    echo "❌ 数据库连接失败"
    echo "💡 请确保 PostgreSQL 正在运行"
    exit 1
fi

# 检查是否存在冲突的数据库
echo ""
echo "🔍 检查数据库冲突..."
EXISTING_DB=$(psql -h localhost -U postgres -d postgres -t -c "SELECT datname FROM pg_database WHERE datname = '$EXPLORER_DB_NAME';" | xargs)

if [ "$EXISTING_DB" = "$EXPLORER_DB_NAME" ]; then
    echo "⚠️  浏览器数据库已存在: $EXPLORER_DB_NAME"
    echo "🔧 删除现有数据库..."
    dropdb -h localhost -U postgres $EXPLORER_DB_NAME 2>/dev/null || echo "数据库删除失败或不存在"
fi

# 创建浏览器数据库
echo ""
echo "🗄️ 创建浏览器数据库..."
createdb -h localhost -U postgres $EXPLORER_DB_NAME
echo "✅ 数据库创建成功: $EXPLORER_DB_NAME"

# 准备自动化输入
echo ""
echo "🤖 准备自动化浏览器初始化..."

# 创建期望脚本
cat > /tmp/explorer_init_expect.sh << EOF
#!/bin/bash
./zkstack_cli/target/release/zkstack explorer init --chain $CHAIN_NAME << 'INPUTS'
$DB_URL
$EXPLORER_DB_NAME
n
INPUTS
EOF

chmod +x /tmp/explorer_init_expect.sh

echo "📝 自动化输入准备完成"
echo "数据库 URL: $DB_URL"
echo "数据库名称: $EXPLORER_DB_NAME"
echo "Prividium 模式: No"

echo ""
echo "🚀 执行浏览器初始化..."
echo "======================"

# 执行初始化
if /tmp/explorer_init_expect.sh; then
    echo "✅ 浏览器初始化成功！"
else
    echo "❌ 浏览器初始化失败"
    echo ""
    echo "💡 手动执行步骤:"
    echo "================"
    echo "1. 运行: ./zkstack_cli/target/release/zkstack explorer init --chain $CHAIN_NAME"
    echo "2. 数据库 URL: $DB_URL"
    echo "3. 数据库名称: $EXPLORER_DB_NAME"
    echo "4. Prividium 模式: n"
    exit 1
fi

# 启动后端服务
echo ""
echo "🔧 启动浏览器后端服务..."
echo "========================"

if [ "$NODE_RUNNING" = true ]; then
    echo "启动后端服务..."
    ./zkstack_cli/target/release/zkstack explorer backend --chain $CHAIN_NAME &
    BACKEND_PID=$!
    
    echo "⏳ 等待后端服务启动 (30秒)..."
    sleep 30
    
    # 检查后端服务状态
    if curl -s http://localhost:3020/health | grep -q "ok\|healthy"; then
        echo "✅ 后端服务启动成功"
        
        echo ""
        echo "🌐 启动前端应用..."
        echo "=================="
        ./zkstack_cli/target/release/zkstack explorer run --chain $CHAIN_NAME &
        FRONTEND_PID=$!
        
        echo "⏳ 等待前端应用启动 (20秒)..."
        sleep 20
        
        echo ""
        echo "🎉 浏览器部署完成！"
        echo "=================="
        echo "🌐 浏览器地址: http://localhost:3010"
        echo "🔧 API 接口: http://localhost:3020"
        echo "📊 健康检查: http://localhost:3020/health"
        
        echo ""
        echo "🔍 服务状态:"
        echo "==========="
        echo "后端服务 PID: $BACKEND_PID"
        echo "前端应用 PID: $FRONTEND_PID"
        
        echo ""
        echo "⚠️ 注意:"
        echo "======="
        echo "1. 浏览器需要一些时间来同步数据"
        echo "2. 首次访问可能显示较少的数据"
        echo "3. 按 Ctrl+C 停止服务"
        
        # 等待用户中断
        echo ""
        echo "按 Ctrl+C 停止所有服务..."
        wait
        
    else
        echo "❌ 后端服务启动失败"
        kill $BACKEND_PID 2>/dev/null || true
    fi
else
    echo "⚠️ ZKsync 节点未运行，请先启动节点"
    echo "启动命令: zkstack server --chain $CHAIN_NAME"
fi

# 清理
rm -f /tmp/explorer_init_expect.sh

echo ""
echo "🧹 清理完成"