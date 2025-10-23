#!/bin/bash

# 🚀 ZKStack BSC 服务器自动部署脚本
# 使用方法: ./deploy_bsc_server.sh [mainnet|testnet]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查参数
NETWORK=${1:-testnet}
if [[ "$NETWORK" != "mainnet" && "$NETWORK" != "testnet" ]]; then
    log_error "无效的网络参数。使用: mainnet 或 testnet"
    exit 1
fi

log_info "开始部署 ZKStack BSC $NETWORK 节点..."

# 设置网络特定的配置
if [[ "$NETWORK" == "mainnet" ]]; then
    CHAIN_ID=56
    RPC_URL="https://bsc-dataseed.binance.org/"
    DB_NAME="zk_bsc_mainnet"
else
    CHAIN_ID=97
    RPC_URL="https://bsc-testnet-dataseed.bnbchain.org"
    DB_NAME="zk_bsc_testnet"
fi

log_info "网络配置: Chain ID $CHAIN_ID, RPC: $RPC_URL"

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查内存
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $MEMORY_GB -lt 16 ]]; then
        log_warning "内存不足 ${MEMORY_GB}GB，推荐至少32GB"
    fi
    
    # 检查磁盘空间
    DISK_GB=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $DISK_GB -lt 500 ]]; then
        log_warning "磁盘空间不足 ${DISK_GB}GB，推荐至少1TB"
    fi
    
    # 检查必要命令
    for cmd in git curl wget docker docker-compose; do
        if ! command -v $cmd &> /dev/null; then
            log_error "$cmd 未安装"
            exit 1
        fi
    done
    
    log_success "系统要求检查完成"
}

# 安装依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    # 更新系统
    sudo apt update && sudo apt upgrade -y
    
    # 安装基础工具
    sudo apt install -y git curl wget build-essential pkg-config libssl-dev \
        postgresql-client jq htop nginx certbot python3-certbot-nginx
    
    # 安装Rust (如果未安装)
    if ! command -v rustc &> /dev/null; then
        log_info "安装 Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
    fi
    
    # 安装Node.js (如果未安装)
    if ! command -v node &> /dev/null; then
        log_info "安装 Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
    
    log_success "依赖安装完成"
}

# 设置数据库
setup_database() {
    log_info "设置 PostgreSQL 数据库..."
    
    # 生成随机密码
    DB_PASSWORD=$(openssl rand -base64 32)
    
    # 启动PostgreSQL容器
    docker run -d \
        --name zksync-postgres-$NETWORK \
        --restart unless-stopped \
        -e POSTGRES_DB=postgres \
        -e POSTGRES_USER=postgres \
        -e POSTGRES_PASSWORD="$DB_PASSWORD" \
        -p 5432:5432 \
        -v postgres_data_$NETWORK:/var/lib/postgresql/data \
        postgres:14
    
    # 等待数据库启动
    log_info "等待数据库启动..."
    sleep 15
    
    # 创建应用数据库
    docker exec zksync-postgres-$NETWORK psql -U postgres -c "CREATE DATABASE $DB_NAME;"
    
    # 保存数据库密码
    echo "$DB_PASSWORD" > ~/.zksync_db_password_$NETWORK
    chmod 600 ~/.zksync_db_password_$NETWORK
    
    log_success "数据库设置完成"
}

# 编译ZKStack
build_zkstack() {
    log_info "编译 ZKStack..."
    
    # 确保在正确的目录
    if [[ ! -d "zkstack_cli" ]]; then
        log_error "请在 zksync-era 根目录运行此脚本"
        exit 1
    fi
    
    # 编译zkstack CLI
    log_info "编译 zkstack CLI..."
    cd zkstack_cli
    cargo build --release
    cd ..
    
    # 编译核心服务
    log_info "编译核心服务..."
    cd core
    cargo build --release --bin zksync_server
    cd ..
    
    log_success "ZKStack 编译完成"
}

# 创建配置文件
create_config() {
    log_info "创建配置文件..."
    
    DB_PASSWORD=$(cat ~/.zksync_db_password_$NETWORK)
    
    # 创建环境配置
    cat > .env.$NETWORK << EOF
# BSC $NETWORK 网络配置
L1_CHAIN_ID=$CHAIN_ID
L1_RPC_URL=$RPC_URL

# 数据库配置
DATABASE_URL=postgres://postgres:$DB_PASSWORD@localhost:5432/$DB_NAME

# 服务配置
API_WEB3_JSON_RPC_HTTP_PORT=3050
API_WEB3_JSON_RPC_WS_PORT=3051
API_PROMETHEUS_PORT=3312
API_HEALTHCHECK_PORT=3081

# 日志配置
RUST_LOG=info
RUST_BACKTRACE=1
EOF

    log_success "配置文件创建完成"
}

# 初始化生态系统
init_ecosystem() {
    log_info "初始化 ZKStack 生态系统..."
    
    DB_PASSWORD=$(cat ~/.zksync_db_password_$NETWORK)
    
    # 设置环境变量
    export L1_CHAIN_ID=$CHAIN_ID
    export L1_RPC_URL=$RPC_URL
    
    # 运行生态系统初始化
    ./zkstack_cli/target/release/zkstack ecosystem init \
        --l1-rpc-url "$RPC_URL" \
        --server-db-url "postgres://postgres:$DB_PASSWORD@localhost:5432" \
        --server-db-name "$DB_NAME" \
        --deploy-ecosystem true \
        --deploy-erc20 true \
        --deploy-paymaster true \
        --timeout 1200 \
        --retries 10 \
        --observability true
    
    log_success "生态系统初始化完成"
}

# 创建系统服务
create_service() {
    log_info "创建系统服务..."
    
    # 创建zksync用户
    if ! id "zksync" &>/dev/null; then
        sudo useradd -r -s /bin/false zksync
    fi
    
    # 创建生产目录
    sudo mkdir -p /opt/zksync-era
    sudo cp -r . /opt/zksync-era/
    sudo chown -R zksync:zksync /opt/zksync-era
    
    # 创建systemd服务文件
    sudo tee /etc/systemd/system/zksync-server-$NETWORK.service > /dev/null << EOF
[Unit]
Description=ZKSync Server for BSC $NETWORK
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=zksync
Group=zksync
WorkingDirectory=/opt/zksync-era
Environment=L1_CHAIN_ID=$CHAIN_ID
Environment=L1_RPC_URL=$RPC_URL
EnvironmentFile=/opt/zksync-era/.env.$NETWORK
ExecStart=/opt/zksync-era/core/target/release/zksync_server \\
    --genesis-path /opt/zksync-era/chains/${NETWORK}_chain/configs/genesis.yaml \\
    --config-path /opt/zksync-era/chains/${NETWORK}_chain/configs/general.yaml \\
    --wallets-path /opt/zksync-era/chains/${NETWORK}_chain/configs/wallets.yaml \\
    --secrets-path /opt/zksync-era/chains/${NETWORK}_chain/configs/secrets.yaml \\
    --contracts-config-path /opt/zksync-era/chains/${NETWORK}_chain/configs/contracts.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=zksync-server-$NETWORK

[Install]
WantedBy=multi-user.target
EOF

    # 启用服务
    sudo systemctl daemon-reload
    sudo systemctl enable zksync-server-$NETWORK
    
    log_success "系统服务创建完成"
}

# 配置Nginx
setup_nginx() {
    log_info "配置 Nginx 反向代理..."
    
    # 创建Nginx配置
    sudo tee /etc/nginx/sites-available/zksync-bsc-$NETWORK > /dev/null << EOF
server {
    listen 80;
    server_name _;  # 替换为你的域名

    # JSON-RPC HTTP API
    location /api {
        proxy_pass http://localhost:3050;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # CORS headers
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
    }

    # WebSocket API
    location /ws {
        proxy_pass http://localhost:3051;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # 健康检查
    location /health {
        proxy_pass http://localhost:3081/health;
    }

    # Prometheus指标 (仅本地访问)
    location /metrics {
        proxy_pass http://localhost:3312/metrics;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

    # 启用站点
    sudo ln -sf /etc/nginx/sites-available/zksync-bsc-$NETWORK /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl restart nginx
    
    log_success "Nginx 配置完成"
}

# 创建监控脚本
create_monitoring() {
    log_info "创建监控脚本..."
    
    # 健康检查脚本
    cat > /opt/zksync-era/health_check_$NETWORK.sh << 'EOF'
#!/bin/bash

SERVICE_NAME="zksync-server-NETWORK_PLACEHOLDER"
API_PORT=3050
DB_PORT=5432

# 检查服务状态
if ! systemctl is-active --quiet $SERVICE_NAME; then
    echo "ERROR: $SERVICE_NAME is not running"
    exit 1
fi

# 检查API响应
if ! curl -s http://localhost:$API_PORT/health > /dev/null; then
    echo "ERROR: API not responding on port $API_PORT"
    exit 1
fi

# 检查数据库连接
if ! pg_isready -h localhost -p $DB_PORT > /dev/null 2>&1; then
    echo "ERROR: Database not accessible on port $DB_PORT"
    exit 1
fi

# 检查BSC网络连接
CHAIN_ID_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:$API_PORT/api | jq -r '.result')

if [[ "$CHAIN_ID_RESPONSE" == "null" || "$CHAIN_ID_RESPONSE" == "" ]]; then
    echo "ERROR: Cannot get chain ID from API"
    exit 1
fi

echo "OK: All services healthy (Chain ID: $CHAIN_ID_RESPONSE)"
EOF

    # 替换占位符
    sed -i "s/NETWORK_PLACEHOLDER/$NETWORK/g" /opt/zksync-era/health_check_$NETWORK.sh
    chmod +x /opt/zksync-era/health_check_$NETWORK.sh
    sudo chown zksync:zksync /opt/zksync-era/health_check_$NETWORK.sh
    
    log_success "监控脚本创建完成"
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."
    
    # 启用UFW
    sudo ufw --force enable
    
    # 基本规则
    sudo ufw allow ssh
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # 限制管理端口访问
    sudo ufw allow from 127.0.0.1 to any port 3312
    
    log_success "防火墙配置完成"
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    # 启动ZKSync服务
    sudo systemctl start zksync-server-$NETWORK
    
    # 等待服务启动
    sleep 10
    
    # 检查服务状态
    if systemctl is-active --quiet zksync-server-$NETWORK; then
        log_success "ZKSync 服务启动成功"
    else
        log_error "ZKSync 服务启动失败"
        sudo journalctl -u zksync-server-$NETWORK --no-pager -l
        exit 1
    fi
}

# 验证部署
verify_deployment() {
    log_info "验证部署..."
    
    # 检查健康状态
    if curl -s http://localhost:3081/health > /dev/null; then
        log_success "健康检查通过"
    else
        log_error "健康检查失败"
        exit 1
    fi
    
    # 检查API响应
    CHAIN_ID_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
      http://localhost:3050/api | jq -r '.result')
    
    EXPECTED_CHAIN_ID=$(printf "0x%x" $CHAIN_ID)
    
    if [[ "$CHAIN_ID_RESPONSE" == "$EXPECTED_CHAIN_ID" ]]; then
        log_success "API 响应正确 (Chain ID: $CHAIN_ID_RESPONSE)"
    else
        log_error "API 响应错误 (期望: $EXPECTED_CHAIN_ID, 实际: $CHAIN_ID_RESPONSE)"
        exit 1
    fi
    
    log_success "部署验证完成"
}

# 显示部署信息
show_deployment_info() {
    log_success "🎉 ZKStack BSC $NETWORK 节点部署完成！"
    echo
    echo "📊 部署信息:"
    echo "  网络: BSC $NETWORK (Chain ID: $CHAIN_ID)"
    echo "  RPC URL: $RPC_URL"
    echo "  数据库: $DB_NAME"
    echo
    echo "🔗 服务端点:"
    echo "  HTTP API: http://localhost:3050/api"
    echo "  WebSocket: ws://localhost:3051/ws"
    echo "  健康检查: http://localhost:3081/health"
    echo "  指标监控: http://localhost:3312/metrics"
    echo
    echo "🛠 管理命令:"
    echo "  查看状态: sudo systemctl status zksync-server-$NETWORK"
    echo "  查看日志: sudo journalctl -u zksync-server-$NETWORK -f"
    echo "  重启服务: sudo systemctl restart zksync-server-$NETWORK"
    echo "  健康检查: /opt/zksync-era/health_check_$NETWORK.sh"
    echo
    echo "⚠️  重要提醒:"
    echo "  1. 数据库密码保存在: ~/.zksync_db_password_$NETWORK"
    echo "  2. 请确保操作员地址有足够的 $([ "$NETWORK" == "mainnet" ] && echo "BNB" || echo "tBNB") 余额"
    echo "  3. 建议设置域名并配置SSL证书"
    echo "  4. 定期备份数据库和配置文件"
}

# 主函数
main() {
    log_info "开始 ZKStack BSC $NETWORK 节点部署..."
    
    check_requirements
    install_dependencies
    setup_database
    build_zkstack
    create_config
    init_ecosystem
    create_service
    setup_nginx
    create_monitoring
    setup_firewall
    start_services
    verify_deployment
    show_deployment_info
    
    log_success "部署完成！🚀"
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 运行主函数
main "$@"