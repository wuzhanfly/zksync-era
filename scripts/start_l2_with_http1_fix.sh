#!/bin/bash

# 使用 HTTP/1.1 修复的 L2 启动脚本

set -e
export ETH_WATCHER_EVENT_EXPIRATION_BLOCKS=1000
export L1_CHAIN_ID=97

echo "🚀 启动 ZKsync Era L2 服务 (HTTP/1.1 修复版)"
echo "============================================="

# 配置
ECOSYSTEM_DIR="/home/wuzhanfly/bsc-testnet-demo/bsc_testnet_demo"
CHAIN_NAME="bsc_test_chain"
ZKSTACK_BIN="/home/wuzhanfly/git/zkstck_cliv0.2.1/zkstack_cli/target/release/zkstack"

# 应用环境变量修复
if [ -f "/tmp/bsc_env_fix.sh" ]; then
    source /tmp/bsc_env_fix.sh
else
    echo "⚠️  环境变量修复文件不存在，创建中..."
    
    cat > /tmp/bsc_env_fix.sh << 'EOF'
#!/bin/bash

# 强制使用 HTTP/1.1
export HYPER_HTTP_VERSION="1.1"

# 设置更长的超时时间
export RUST_LOG="info,hyper=debug,reqwest=debug"

# 禁用 HTTP/2
export CURL_HTTP_VERSION="1.1"

# 设置重试参数
export ETH_CLIENT_RETRY_COUNT="5"
export ETH_CLIENT_RETRY_INTERVAL="2"

# 设置连接池参数
export ETH_CLIENT_POOL_SIZE="5"
export ETH_CLIENT_TIMEOUT="60"

echo "✅ 环境变量已设置"
EOF
    
    chmod +x /tmp/bsc_env_fix.sh
    source /tmp/bsc_env_fix.sh
fi

# 切换到生态系统目录
cd "$ECOSYSTEM_DIR"

echo "📋 配置信息"
echo "==========="
echo "生态系统目录: $ECOSYSTEM_DIR"
echo "链名称: $CHAIN_NAME"
echo "HTTP 版本: 1.1 (强制)"
echo "重试机制: 启用"
echo ""

# 设置环境变量
export DATABASE_URL="postgres://postgres:notsecurepassword@localhost:5432/zksync_server_bsc_testnet_bsc_test_chain"
export RUST_LOG="info,hyper=warn,reqwest=warn"
export ZKSYNC_HOME="$PWD"

# 强制使用 HTTP/1.1
export HYPER_HTTP_VERSION="1.1"

echo "🔧 网络配置"
echo "==========="
echo "强制 HTTP/1.1: ✅"
echo "重试机制: ✅"
echo "连接超时: 60s"
echo "请求超时: 60s"
echo ""

echo "🚀 启动 L2 服务"
echo "=============="

# 启动服务
"$ZKSTACK_BIN" server run --chain "$CHAIN_NAME"