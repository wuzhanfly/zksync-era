#!/bin/bash

# 🚀 ZKStack BSC Ubuntu 24.04 快速部署脚本
# 最简化的原生部署方案

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查环境
check_environment() {
    log_info "检查部署环境..."
    
    # 检查系统
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "此脚本仅支持 Ubuntu 系统"
        exit 1
    fi
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 sudo 运行: sudo $0"
        exit 1
    fi
    
    # 检查二进制文件
    if [[ ! -f "zkstack_cli/target/release/zkstack" ]] || [[ ! -f "core/target/release/zksync_server" ]]; then
        log_error "缺少预编译文件，请先编译:"
        echo "  cd zkstack_cli && cargo build --release"
        echo "  cd core && cargo build --release --bin zksync_server"
        exit 1
    fi
    
    log_success "环境检查通过"
}

# 快速安装依赖
quick_install_deps() {
    log_info "安装必要依赖..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # 更新包列表
    apt update -qq
    
    # 安装核心依赖
    apt install -y -qq \
        postgresql postgresql-client \
        nginx \
        curl jq \
        openssl \
        systemd
    
    log_success "依赖安装完成"
}

# 快速配置数据库
quick_setup_db() {
    log_info "配置数据库..."
    
    # 启动 PostgreSQL
    systemctl enable postgresql --quiet
    systemctl start postgresql
    
    # 生成密码
    DB_PASSWORD=$(openssl rand -base64 20 | tr -d "=+/")
    
    # 创建数据库
    sudo -u postgres psql -c "CREATE USER zksync WITH PASSWORD '$DB_PASSWORD';" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE DATABASE zk_bsc_testnet OWNER zksync;" 2>/dev/null || true
    
    # 保存密码
    echo "$DB_PASSWORD" > /tmp/zksync_db_pass
    
    log_success "数据库配置完成"
}

# 快速部署服务
quick_deploy_service() {
    log_info "部署 ZKSync 服务..."
    
    # 创建用户
    useradd -r -s /bin/false zksync 2>/dev/null || true
    
    # 创建目录
    mkdir -p /opt/zksync/{bin,data,logs}
    
    # 复制文件
    cp zkstack_cli/target/release/zkstack /opt/zksync/bin/
    cp core/target/release/zksync_server /opt/zksync/bin/
    chmod +x /opt/zksync/bin/*
    
    # 复制配置
    if [[ -d "chains" ]]; then
        cp -r chains /opt/zksync/ 2>/dev/null || true
    fi
    if [[ -d "etc" ]]; then
        cp -r etc /opt/zksync/ 2>/dev/null || true
    fi
    
    # 设置权限
    chown -R zksync:zksync /opt/zksync
    
    log_success "服务文件部署完成"
}

# 初始化生态系统
quick_init_ecosystem() {
    log_info "初始化生态系统..."
    
    DB_PASSWORD=$(cat /tmp/zksync_db_pass)
    
    # 设置环境变量
    export L1_CHAIN_ID=97
    export L1_RPC_URL="https://bsc-testnet-dataseed.bnbchain.org"
    
    # 切换到工作目录
    cd /opt/zksync
    
    # 运行初始化
    sudo -u zksync -E ./bin/zkstack ecosystem init \
        --l1-rpc-url "$L1_RPC_URL" \
        --server-db-url "postgres://zksync:$DB_PASSWORD@localhost:5432" \
        --server-db-name "zk_bsc_testnet" \
        --deploy-ecosystem true \
        --deploy-erc20 true \
        --deploy-paymaster true \
        --timeout 600 \
        --retries 5 \
        --observability true
    
    log_success "生态系统初始化完成"
}

# 创建系统服务
quick_create_service() {
    log_info "创建系统服务..."
    
    DB_PASSWORD=$(cat /tmp/zksync_db_pass)
    
    # 创建环境文件
    cat > /opt/zksync/.env << EOF
L1_CHAIN_ID=97
L1_RPC_URL=https://bsc-testnet-dataseed.bnbchain.org
DATABASE_URL=postgres://zksync:$DB_PASSWORD@localhost:5432/zk_bsc_testnet
RUST_LOG=info
EOF

    # 创建 systemd 服务
    cat > /etc/systemd/system/zksync-bsc.service << 'EOF'
[Unit]
Description=ZKSync BSC Testnet
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=zksync
Group=zksync
WorkingDirectory=/opt/zksync
EnvironmentFile=/opt/zksync/.env
ExecStart=/opt/zksync/bin/zksync_server \
    --genesis-path /opt/zksync/chains/testnet_chain/configs/genesis.yaml \
    --config-path /opt/zksync/chains/testnet_chain/configs/general.yaml \
    --wallets-path /opt/zksync/chains/testnet_chain/configs/wallets.yaml \
    --secrets-path /opt/zksync/chains/testnet_chain/configs/secrets.yaml \
    --contracts-config-path /opt/zksync/chains/testnet_chain/configs/contracts.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # 启用服务
    systemctl daemon-reload
    systemctl enable zksync-bsc
    
    log_success "系统服务创建完成"
}

# 配置 Nginx
quick_setup_nginx() {
    log_info "配置 Nginx..."
    
    # 创建简单的 Nginx 配置
    cat > /etc/nginx/sites-available/zksync-bsc << 'EOF'
server {
    listen 80;
    server_name _;
    
    # API 代理
    location /api {
        proxy_pass http://127.0.0.1:3050;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type";
    }
    
    # WebSocket 代理
    location /ws {
        proxy_pass http://127.0.0.1:3051;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
    
    # 健康检查
    location /health {
        proxy_pass http://127.0.0.1:3081/health;
    }
    
    # 默认页面
    location / {
        return 200 '{"service":"zksync-bsc-testnet","status":"running"}';
        add_header Content-Type application/json;
    }
}
EOF

    # 启用站点
    ln -sf /etc/nginx/sites-available/zksync-bsc /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # 启动 Nginx
    systemctl enable nginx
    systemctl restart nginx
    
    log_success "Nginx 配置完成"
}

# 启动和验证
quick_start_and_verify() {
    log_info "启动服务..."
    
    # 启动 ZKSync 服务
    systemctl start zksync-bsc
    
    # 等待启动
    log_info "等待服务启动 (可能需要1-2分钟)..."
    sleep 30
    
    # 检查服务状态
    if systemctl is-active --quiet zksync-bsc; then
        log_success "✅ ZKSync 服务运行正常"
    else
        log_error "❌ ZKSync 服务启动失败"
        journalctl -u zksync-bsc --no-pager -n 20
        exit 1
    fi
    
    # 验证 API
    log_info "验证 API 响应..."
    local retries=12
    while [[ $retries -gt 0 ]]; do
        if curl -s http://localhost/health >/dev/null 2>&1; then
            log_success "✅ API 响应正常"
            break
        fi
        sleep 10
        retries=$((retries - 1))
        echo -n "."
    done
    
    if [[ $retries -eq 0 ]]; then
        log_error "❌ API 响应超时"
        exit 1
    fi
    
    # 测试链ID
    local chain_id=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        http://localhost/api | jq -r '.result' 2>/dev/null || echo "failed")
    
    if [[ "$chain_id" == "0x61" ]]; then
        log_success "✅ BSC Testnet 连接正常 (Chain ID: $chain_id)"
    else
        log_warning "⚠️  链ID响应: $chain_id"
    fi
}

# 创建管理脚本
create_quick_scripts() {
    log_info "创建管理脚本..."
    
    # 状态检查脚本
    cat > /opt/zksync/status.sh << 'EOF'
#!/bin/bash
echo "=== ZKSync BSC 状态 ==="
echo "服务状态: $(systemctl is-active zksync-bsc)"
echo "API健康: $(curl -s http://localhost/health 2>/dev/null | jq -r '.status' 2>/dev/null || echo 'failed')"
echo "链ID: $(curl -s -X POST -H 'Content-Type: application/json' --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' http://localhost/api | jq -r '.result' 2>/dev/null || echo 'failed')"
echo
echo "最近日志:"
journalctl -u zksync-bsc --no-pager -n 5
EOF

    chmod +x /opt/zksync/status.sh
    chown zksync:zksync /opt/zksync/status.sh
    
    log_success "管理脚本创建完成"
}

# 显示结果
show_quick_result() {
    # 清理临时文件
    rm -f /tmp/zksync_db_pass
    
    log_success "🎉 ZKStack BSC Testnet 快速部署完成！"
    echo
    echo "📊 部署信息:"
    echo "  网络: BSC Testnet (Chain ID: 97)"
    echo "  部署目录: /opt/zksync"
    echo "  服务名称: zksync-bsc"
    echo
    echo "🔗 访问地址:"
    echo "  API: http://localhost/api"
    echo "  WebSocket: ws://localhost/ws"
    echo "  健康检查: http://localhost/health"
    echo
    echo "🛠 常用命令:"
    echo "  查看状态: /opt/zksync/status.sh"
    echo "  查看日志: journalctl -u zksync-bsc -f"
    echo "  重启服务: sudo systemctl restart zksync-bsc"
    echo "  停止服务: sudo systemctl stop zksync-bsc"
    echo
    echo "📋 测试命令:"
    echo "  curl http://localhost/health"
    echo "  curl -X POST -H 'Content-Type: application/json' \\"
    echo "    --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}' \\"
    echo "    http://localhost/api"
    echo
    echo "⚠️  重要提醒:"
    echo "  1. 确保操作员地址有足够的 tBNB 余额"
    echo "  2. 生产环境请配置 HTTPS 和防火墙"
    echo "  3. 定期备份数据库: pg_dump -U zksync zk_bsc_testnet"
}

# 主函数
main() {
    echo "🚀 ZKStack BSC Ubuntu 24.04 快速部署"
    echo "======================================"
    echo
    
    check_environment
    quick_install_deps
    quick_setup_db
    quick_deploy_service
    quick_init_ecosystem
    quick_create_service
    quick_setup_nginx
    quick_start_and_verify
    create_quick_scripts
    show_quick_result
    
    echo "🎉 部署完成！"
}

# 错误处理
trap 'log_error "部署失败，请检查错误信息"; exit 1' ERR

# 帮助信息
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "ZKStack BSC Ubuntu 24.04 快速部署脚本"
    echo
    echo "这是一个简化的部署脚本，适用于快速测试和开发环境。"
    echo
    echo "使用方法:"
    echo "  sudo $0"
    echo
    echo "前置要求:"
    echo "  - Ubuntu 24.04 系统"
    echo "  - sudo 权限"
    echo "  - 预编译的二进制文件:"
    echo "    * zkstack_cli/target/release/zkstack"
    echo "    * core/target/release/zksync_server"
    echo
    echo "部署内容:"
    echo "  - PostgreSQL 数据库"
    echo "  - ZKSync BSC Testnet 节点"
    echo "  - Nginx 反向代理"
    echo "  - systemd 服务"
    echo
    echo "注意: 此脚本仅部署到 BSC Testnet，适用于测试环境。"
    exit 0
fi

# 运行主函数
main "$@"