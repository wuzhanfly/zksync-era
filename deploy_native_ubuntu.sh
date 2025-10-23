#!/bin/bash

# 🚀 ZKStack BSC Ubuntu 24.04 原生部署脚本
# 直接使用可执行文件部署，无需 Docker

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

# 配置变量
NETWORK=${1:-testnet}
DEPLOY_DIR="/opt/zksync-era"
SERVICE_USER="zksync"
DATA_DIR="/var/lib/zksync"
LOG_DIR="/var/log/zksync"

# 网络配置
if [[ "$NETWORK" == "mainnet" ]]; then
    CHAIN_ID=56
    RPC_URL="https://bsc-dataseed.binance.org/"
    DB_NAME="zk_bsc_mainnet"
    SERVICE_NAME="zksync-bsc-mainnet"
else
    CHAIN_ID=97
    RPC_URL="https://bsc-testnet-dataseed.bnbchain.org"
    DB_NAME="zk_bsc_testnet"
    SERVICE_NAME="zksync-bsc-testnet"
fi

log_info "开始在 Ubuntu 24.04 上原生部署 ZKStack BSC $NETWORK 节点..."

# 检查系统版本
check_system() {
    log_info "检查系统环境..."
    
    # 检查 Ubuntu 版本
    if ! grep -q "Ubuntu 24.04" /etc/os-release; then
        log_warning "系统不是 Ubuntu 24.04，可能存在兼容性问题"
    fi
    
    # 检查架构
    local arch=$(uname -m)
    log_info "系统架构: $arch"
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 sudo 运行此脚本"
        exit 1
    fi
    
    log_success "系统环境检查完成"
}

# 检查预编译文件
check_binaries() {
    log_info "检查预编译二进制文件..."
    
    local required_files=(
        "zkstack_cli/target/release/zkstack"
        "core/target/release/zksync_server"
    )
    
    local missing_files=()
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "缺少预编译文件:"
        for file in "${missing_files[@]}"; do
            echo "  ❌ $file"
        done
        log_error "请先在本机编译或从构建服务器获取二进制文件"
        exit 1
    fi
    
    # 检查文件权限和架构
    for file in "${required_files[@]}"; do
        if [[ ! -x "$file" ]]; then
            chmod +x "$file"
        fi
        
        local file_info=$(file "$file")
        log_info "✅ $file - $(echo "$file_info" | grep -o 'x86-64\|aarch64\|ARM' || echo 'unknown arch')"
    done
    
    log_success "二进制文件检查完成"
}

# 安装系统依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    # 更新包列表
    apt update
    
    # 安装运行时依赖
    apt install -y \
        curl \
        wget \
        jq \
        htop \
        nginx \
        postgresql-14 \
        postgresql-client-14 \
        postgresql-contrib-14 \
        ca-certificates \
        openssl \
        libc6 \
        libssl3 \
        libpq5 \
        systemd \
        logrotate \
        ufw
    
    log_success "系统依赖安装完成"
}

# 创建用户和目录
setup_user_and_directories() {
    log_info "创建用户和目录..."
    
    # 创建系统用户
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd -r -s /bin/false -d "$DATA_DIR" "$SERVICE_USER"
        log_info "创建用户: $SERVICE_USER"
    fi
    
    # 创建目录结构
    mkdir -p "$DEPLOY_DIR"/{bin,configs,chains,scripts}
    mkdir -p "$DATA_DIR"/{data,logs,backups}
    mkdir -p "$LOG_DIR"
    mkdir -p /etc/zksync
    
    # 设置目录权限
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DEPLOY_DIR" "$DATA_DIR" "$LOG_DIR"
    chmod 755 "$DEPLOY_DIR" "$DATA_DIR"
    chmod 750 "$LOG_DIR"
    
    log_success "用户和目录创建完成"
}

# 复制二进制文件和配置
install_binaries() {
    log_info "安装二进制文件..."
    
    # 复制二进制文件
    cp zkstack_cli/target/release/zkstack "$DEPLOY_DIR/bin/"
    cp core/target/release/zksync_server "$DEPLOY_DIR/bin/"
    
    # 复制其他可选二进制文件
    for binary in zksync_external_node zksync_contract_verifier; do
        if [[ -f "core/target/release/$binary" ]]; then
            cp "core/target/release/$binary" "$DEPLOY_DIR/bin/"
            log_info "复制可选二进制: $binary"
        fi
    done
    
    # 复制配置文件
    if [[ -d "chains" ]]; then
        cp -r chains/* "$DEPLOY_DIR/chains/" 2>/dev/null || true
    fi
    if [[ -d "etc" ]]; then
        cp -r etc "$DEPLOY_DIR/" 2>/dev/null || true
    fi
    
    # 设置权限
    chmod +x "$DEPLOY_DIR/bin"/*
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DEPLOY_DIR"
    
    log_success "二进制文件安装完成"
}

# 配置 PostgreSQL
setup_postgresql() {
    log_info "配置 PostgreSQL..."
    
    # 启动 PostgreSQL 服务
    systemctl enable postgresql
    systemctl start postgresql
    
    # 等待服务启动
    sleep 5
    
    # 生成数据库密码
    local db_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    echo "$db_password" > /etc/zksync/db_password
    chmod 600 /etc/zksync/db_password
    
    # 创建数据库用户和数据库
    sudo -u postgres psql << EOF
-- 创建用户
CREATE USER zksync WITH PASSWORD '$db_password';

-- 创建数据库
CREATE DATABASE $DB_NAME OWNER zksync;

-- 授权
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO zksync;

-- 显示结果
\l
EOF

    # 配置 PostgreSQL 连接
    local pg_version="14"
    local pg_config="/etc/postgresql/$pg_version/main/postgresql.conf"
    local pg_hba="/etc/postgresql/$pg_version/main/pg_hba.conf"
    
    # 优化 PostgreSQL 配置
    cat >> "$pg_config" << EOF

# ZKSync 优化配置
max_connections = 200
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB
EOF

    # 配置认证
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" "$pg_config"
    
    # 重启 PostgreSQL
    systemctl restart postgresql
    
    log_success "PostgreSQL 配置完成"
}

# 创建配置文件
create_configuration() {
    log_info "创建配置文件..."
    
    local db_password=$(cat /etc/zksync/db_password)
    
    # 创建主配置文件
    cat > "$DEPLOY_DIR/configs/config.yaml" << EOF
# ZKStack BSC $NETWORK 配置文件
network:
  chain_id: $CHAIN_ID
  l1_rpc_url: "$RPC_URL"
  network_name: "BSC $([ "$NETWORK" == "mainnet" ] && echo "Mainnet" || echo "Testnet")"

database:
  url: "postgres://zksync:$db_password@localhost:5432/$DB_NAME"
  max_connections: 50

api:
  http_port: 3050
  ws_port: 3051
  health_port: 3081
  metrics_port: 3312
  bind_address: "0.0.0.0"

logging:
  level: "info"
  file: "$LOG_DIR/zksync.log"
  max_size: "100MB"
  max_files: 10

paths:
  data_dir: "$DATA_DIR/data"
  chains_dir: "$DEPLOY_DIR/chains"
EOF

    # 创建环境变量文件
    cat > "$DEPLOY_DIR/.env" << EOF
# BSC $NETWORK 网络配置
L1_CHAIN_ID=$CHAIN_ID
L1_RPC_URL=$RPC_URL

# 数据库配置
DATABASE_URL=postgres://zksync:$db_password@localhost:5432/$DB_NAME

# 服务配置
API_WEB3_JSON_RPC_HTTP_PORT=3050
API_WEB3_JSON_RPC_WS_PORT=3051
API_PROMETHEUS_PORT=3312
API_HEALTHCHECK_PORT=3081

# 路径配置
DATA_DIR=$DATA_DIR
LOG_DIR=$LOG_DIR

# 日志配置
RUST_LOG=info
RUST_BACKTRACE=1
EOF

    # 设置权限
    chown "$SERVICE_USER:$SERVICE_USER" "$DEPLOY_DIR/configs/config.yaml" "$DEPLOY_DIR/.env"
    chmod 640 "$DEPLOY_DIR/.env"
    
    log_success "配置文件创建完成"
}

# 初始化生态系统
initialize_ecosystem() {
    log_info "初始化 ZKStack 生态系统..."
    
    local db_password=$(cat /etc/zksync/db_password)
    
    # 设置环境变量
    export L1_CHAIN_ID=$CHAIN_ID
    export L1_RPC_URL=$RPC_URL
    
    # 切换到部署目录
    cd "$DEPLOY_DIR"
    
    # 使用 zksync 用户运行初始化
    sudo -u "$SERVICE_USER" -E ./bin/zkstack ecosystem init \
        --l1-rpc-url "$RPC_URL" \
        --server-db-url "postgres://zksync:$db_password@localhost:5432" \
        --server-db-name "$DB_NAME" \
        --deploy-ecosystem true \
        --deploy-erc20 true \
        --deploy-paymaster true \
        --timeout 1200 \
        --retries 10 \
        --observability true
    
    log_success "生态系统初始化完成"
}

# 创建 systemd 服务
create_systemd_service() {
    log_info "创建 systemd 服务..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=ZKSync BSC $NETWORK Server
Documentation=https://docs.zksync.io/
After=network.target postgresql.service
Wants=postgresql.service
StartLimitIntervalSec=0

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$DEPLOY_DIR

# 环境变量
Environment=L1_CHAIN_ID=$CHAIN_ID
Environment=L1_RPC_URL=$RPC_URL
Environment=DATA_DIR=$DATA_DIR
Environment=LOG_DIR=$LOG_DIR
EnvironmentFile=$DEPLOY_DIR/.env

# 启动命令
ExecStart=$DEPLOY_DIR/bin/zksync_server \\
    --genesis-path $DEPLOY_DIR/chains/${NETWORK}_chain/configs/genesis.yaml \\
    --config-path $DEPLOY_DIR/chains/${NETWORK}_chain/configs/general.yaml \\
    --wallets-path $DEPLOY_DIR/chains/${NETWORK}_chain/configs/wallets.yaml \\
    --secrets-path $DEPLOY_DIR/chains/${NETWORK}_chain/configs/secrets.yaml \\
    --contracts-config-path $DEPLOY_DIR/chains/${NETWORK}_chain/configs/contracts.yaml

# 重启策略
Restart=always
RestartSec=10
StartLimitBurst=3

# 资源限制
LimitNOFILE=65536
LimitNPROC=4096
LimitMEMLOCK=infinity

# 安全设置
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR $LOG_DIR

# 日志配置
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载 systemd 配置
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    log_success "systemd 服务创建完成"
}

# 配置 Nginx
setup_nginx() {
    log_info "配置 Nginx..."
    
    # 创建 Nginx 配置
    cat > "/etc/nginx/sites-available/$SERVICE_NAME" << EOF
# ZKSync BSC $NETWORK Nginx 配置
upstream zksync_api {
    server 127.0.0.1:3050;
    keepalive 32;
}

upstream zksync_ws {
    server 127.0.0.1:3051;
}

# 限流配置
limit_req_zone \$binary_remote_addr zone=api:10m rate=100r/s;
limit_req_zone \$binary_remote_addr zone=ws:10m rate=50r/s;

server {
    listen 80;
    server_name _;
    
    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # CORS 配置
    add_header Access-Control-Allow-Origin "*" always;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;
    
    # OPTIONS 请求处理
    if (\$request_method = 'OPTIONS') {
        return 204;
    }
    
    # JSON-RPC API
    location /api {
        limit_req zone=api burst=200 nodelay;
        
        proxy_pass http://zksync_api;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # WebSocket API
    location /ws {
        limit_req zone=ws burst=100 nodelay;
        
        proxy_pass http://zksync_ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket 超时
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 3600s;
    }
    
    # 健康检查
    location /health {
        proxy_pass http://127.0.0.1:3081/health;
        access_log off;
    }
    
    # 指标监控 (限制访问)
    location /metrics {
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        allow 192.168.0.0/16;
        deny all;
        
        proxy_pass http://127.0.0.1:3312/metrics;
    }
    
    # 状态页面
    location / {
        return 200 '{"service":"zksync-bsc-$NETWORK","status":"running","timestamp":"\$time_iso8601"}';
        add_header Content-Type application/json;
    }
}
EOF

    # 启用站点
    ln -sf "/etc/nginx/sites-available/$SERVICE_NAME" "/etc/nginx/sites-enabled/"
    
    # 删除默认站点
    rm -f /etc/nginx/sites-enabled/default
    
    # 测试配置
    nginx -t
    
    # 启动 Nginx
    systemctl enable nginx
    systemctl restart nginx
    
    log_success "Nginx 配置完成"
}

# 配置日志轮转
setup_log_rotation() {
    log_info "配置日志轮转..."
    
    cat > "/etc/logrotate.d/zksync" << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
    postrotate
        systemctl reload $SERVICE_NAME 2>/dev/null || true
    endscript
}
EOF

    log_success "日志轮转配置完成"
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."
    
    # 启用 UFW
    ufw --force enable
    
    # 基本规则
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # 限制内部端口
    ufw allow from 127.0.0.1 to any port 3050
    ufw allow from 127.0.0.1 to any port 3051
    ufw allow from 127.0.0.1 to any port 3081
    ufw allow from 127.0.0.1 to any port 3312
    
    log_success "防火墙配置完成"
}

# 创建管理脚本
create_management_scripts() {
    log_info "创建管理脚本..."
    
    # 健康检查脚本
    cat > "$DEPLOY_DIR/scripts/health_check.sh" << EOF
#!/bin/bash
# ZKSync BSC $NETWORK 健康检查脚本

SERVICE_NAME="$SERVICE_NAME"
API_PORT=3050
HEALTH_PORT=3081

echo "=== ZKSync BSC $NETWORK 健康检查 ==="
echo "时间: \$(date)"
echo

# 检查服务状态
if systemctl is-active --quiet "\$SERVICE_NAME"; then
    echo "✅ 服务状态: 运行中"
else
    echo "❌ 服务状态: 已停止"
    exit 1
fi

# 检查端口
if netstat -tlnp | grep -q ":\$API_PORT "; then
    echo "✅ API 端口: \$API_PORT 正常"
else
    echo "❌ API 端口: \$API_PORT 未监听"
    exit 1
fi

# 检查健康接口
HEALTH_RESPONSE=\$(curl -s http://localhost:\$HEALTH_PORT/health 2>/dev/null || echo "FAILED")
if [[ "\$HEALTH_RESPONSE" == *"ok"* ]]; then
    echo "✅ 健康检查: 通过"
else
    echo "❌ 健康检查: 失败 (\$HEALTH_RESPONSE)"
    exit 1
fi

# 检查 API 响应
CHAIN_ID=\$(curl -s -X POST -H "Content-Type: application/json" \\
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \\
  http://localhost:\$API_PORT/api | jq -r '.result' 2>/dev/null || echo "FAILED")

if [[ "\$CHAIN_ID" =~ ^0x[0-9a-fA-F]+\$ ]]; then
    CHAIN_ID_DEC=\$((CHAIN_ID))
    NETWORK_NAME="Unknown"
    case \$CHAIN_ID_DEC in
        56) NETWORK_NAME="BSC Mainnet" ;;
        97) NETWORK_NAME="BSC Testnet" ;;
    esac
    echo "✅ API 响应: 正常 - \$NETWORK_NAME (Chain ID: \$CHAIN_ID)"
else
    echo "❌ API 响应: 异常 (\$CHAIN_ID)"
    exit 1
fi

echo
echo "🎉 所有检查通过！"
EOF

    # 备份脚本
    cat > "$DEPLOY_DIR/scripts/backup.sh" << EOF
#!/bin/bash
# ZKSync BSC $NETWORK 数据备份脚本

BACKUP_DIR="$DATA_DIR/backups"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
DB_PASSWORD=\$(cat /etc/zksync/db_password)

mkdir -p "\$BACKUP_DIR"

echo "开始备份数据库..."
PGPASSWORD="\$DB_PASSWORD" pg_dump -h localhost -U zksync $DB_NAME > "\$BACKUP_DIR/${DB_NAME}_\$TIMESTAMP.sql"

echo "压缩备份文件..."
gzip "\$BACKUP_DIR/${DB_NAME}_\$TIMESTAMP.sql"

echo "备份配置文件..."
tar -czf "\$BACKUP_DIR/configs_\$TIMESTAMP.tar.gz" -C "$DEPLOY_DIR" configs chains .env

echo "备份完成:"
ls -lh "\$BACKUP_DIR"/*\$TIMESTAMP*

# 清理7天前的备份
find "\$BACKUP_DIR" -name "*.gz" -mtime +7 -delete
find "\$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "旧备份已清理"
EOF

    # 监控脚本
    cat > "$DEPLOY_DIR/scripts/monitor.sh" << EOF
#!/bin/bash
# ZKSync BSC $NETWORK 监控脚本

echo "=== ZKSync BSC $NETWORK 系统监控 ==="
echo "时间: \$(date)"
echo

echo "📊 服务状态:"
systemctl status $SERVICE_NAME --no-pager -l
echo

echo "💾 资源使用:"
echo "CPU: \$(top -bn1 | grep "Cpu(s)" | awk '{print \$2}' | cut -d'%' -f1)%"
echo "内存: \$(free -h | awk '/^Mem:/ {print \$3 "/" \$2}')"
echo "磁盘: \$(df -h $DATA_DIR | awk 'NR==2 {print \$3 "/" \$2 " (" \$5 ")"}')"
echo

echo "🌐 网络连接:"
netstat -tlnp | grep -E ":(3050|3051|3081|3312) "
echo

echo "📝 最近日志 (最后10行):"
journalctl -u $SERVICE_NAME --no-pager -n 10
EOF

    # 更新脚本
    cat > "$DEPLOY_DIR/scripts/update.sh" << EOF
#!/bin/bash
# ZKSync BSC $NETWORK 更新脚本

if [[ \$EUID -ne 0 ]]; then
   echo "请使用 sudo 运行此脚本"
   exit 1
fi

echo "停止服务..."
systemctl stop $SERVICE_NAME

echo "备份当前版本..."
./backup.sh

echo "请将新的二进制文件复制到 $DEPLOY_DIR/bin/ 目录"
echo "然后运行: systemctl start $SERVICE_NAME"
echo
echo "验证更新: ./health_check.sh"
EOF

    # 设置权限
    chmod +x "$DEPLOY_DIR/scripts"/*.sh
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DEPLOY_DIR/scripts"
    
    log_success "管理脚本创建完成"
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    # 启动 ZKSync 服务
    systemctl start "$SERVICE_NAME"
    
    # 等待服务启动
    sleep 15
    
    # 检查服务状态
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "ZKSync 服务启动成功"
    else
        log_error "ZKSync 服务启动失败"
        journalctl -u "$SERVICE_NAME" --no-pager -l
        exit 1
    fi
}

# 验证部署
verify_deployment() {
    log_info "验证部署..."
    
    # 运行健康检查
    if "$DEPLOY_DIR/scripts/health_check.sh"; then
        log_success "部署验证通过"
    else
        log_error "部署验证失败"
        exit 1
    fi
}

# 显示部署信息
show_deployment_info() {
    log_success "🎉 ZKStack BSC $NETWORK 节点部署完成！"
    echo
    echo "📊 部署信息:"
    echo "  系统: Ubuntu 24.04 (原生部署)"
    echo "  网络: BSC $NETWORK (Chain ID: $CHAIN_ID)"
    echo "  部署目录: $DEPLOY_DIR"
    echo "  数据目录: $DATA_DIR"
    echo "  日志目录: $LOG_DIR"
    echo "  服务名称: $SERVICE_NAME"
    echo
    echo "🔗 服务端点:"
    echo "  HTTP API: http://localhost/api"
    echo "  WebSocket: ws://localhost/ws"
    echo "  健康检查: http://localhost/health"
    echo "  服务状态: http://localhost/"
    echo
    echo "🛠 管理命令:"
    echo "  查看状态: systemctl status $SERVICE_NAME"
    echo "  查看日志: journalctl -u $SERVICE_NAME -f"
    echo "  重启服务: sudo systemctl restart $SERVICE_NAME"
    echo "  停止服务: sudo systemctl stop $SERVICE_NAME"
    echo
    echo "📋 管理脚本:"
    echo "  健康检查: $DEPLOY_DIR/scripts/health_check.sh"
    echo "  数据备份: $DEPLOY_DIR/scripts/backup.sh"
    echo "  系统监控: $DEPLOY_DIR/scripts/monitor.sh"
    echo "  服务更新: sudo $DEPLOY_DIR/scripts/update.sh"
    echo
    echo "📁 重要文件:"
    echo "  配置文件: $DEPLOY_DIR/.env"
    echo "  数据库密码: /etc/zksync/db_password"
    echo "  Nginx 配置: /etc/nginx/sites-available/$SERVICE_NAME"
    echo "  systemd 服务: /etc/systemd/system/$SERVICE_NAME.service"
    echo
    echo "⚠️  重要提醒:"
    echo "  1. 确保操作员地址有足够的 $([ "$NETWORK" == "mainnet" ] && echo "BNB" || echo "tBNB") 余额"
    echo "  2. 定期运行备份脚本: $DEPLOY_DIR/scripts/backup.sh"
    echo "  3. 监控服务状态: $DEPLOY_DIR/scripts/monitor.sh"
    echo "  4. 生产环境建议配置 HTTPS 和域名"
}

# 主函数
main() {
    log_info "开始 Ubuntu 24.04 原生部署..."
    
    check_system
    check_binaries
    install_dependencies
    setup_user_and_directories
    install_binaries
    setup_postgresql
    create_configuration
    initialize_ecosystem
    create_systemd_service
    setup_nginx
    setup_log_rotation
    setup_firewall
    create_management_scripts
    start_services
    verify_deployment
    show_deployment_info
    
    log_success "原生部署完成！🚀"
}

# 错误处理
trap 'log_error "部署失败，请检查日志"; exit 1' ERR

# 检查参数
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "ZKStack BSC Ubuntu 24.04 原生部署脚本"
    echo
    echo "使用方法: sudo $0 [mainnet|testnet]"
    echo
    echo "参数:"
    echo "  mainnet  - 部署到 BSC 主网"
    echo "  testnet  - 部署到 BSC 测试网 (默认)"
    echo
    echo "前置要求:"
    echo "  - Ubuntu 24.04 系统"
    echo "  - sudo 权限"
    echo "  - 预编译的二进制文件"
    echo
    echo "示例:"
    echo "  sudo $0 testnet"
    exit 0
fi

# 运行主函数
main "$@"