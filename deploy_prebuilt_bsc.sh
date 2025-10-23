#!/bin/bash

# 🚀 ZKStack BSC 预编译二进制部署脚本
# 使用本机编译的二进制文件直接部署到服务器

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
BACKUP_DIR="/opt/zksync-backup"

# 网络配置
if [[ "$NETWORK" == "mainnet" ]]; then
    CHAIN_ID=56
    RPC_URL="https://bsc-dataseed.binance.org/"
    DB_NAME="zk_bsc_mainnet"
else
    CHAIN_ID=97
    RPC_URL="https://bsc-testnet-dataseed.bnbchain.org"
    DB_NAME="zk_bsc_testnet"
fi

log_info "开始部署 ZKStack BSC $NETWORK 节点 (使用预编译二进制)..."

# 检查本机编译文件
check_binaries() {
    log_info "检查预编译二进制文件..."
    
    local missing_files=()
    
    # 检查 zkstack CLI
    if [[ ! -f "zkstack_cli/target/release/zkstack" ]]; then
        missing_files+=("zkstack_cli/target/release/zkstack")
    fi
    
    # 检查 zksync_server
    if [[ ! -f "core/target/release/zksync_server" ]]; then
        missing_files+=("core/target/release/zksync_server")
    fi
    
    # 检查其他可能需要的二进制文件
    for binary in zksync_external_node zksync_contract_verifier; do
        if [[ -f "core/target/release/$binary" ]]; then
            log_info "发现可选二进制文件: $binary"
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "缺少以下预编译文件:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        log_error "请先在本机编译这些文件:"
        echo "  cd zkstack_cli && cargo build --release"
        echo "  cd core && cargo build --release --bin zksync_server"
        exit 1
    fi
    
    log_success "预编译二进制文件检查完成"
}

# 检查系统架构兼容性
check_architecture() {
    log_info "检查系统架构兼容性..."
    
    local local_arch=$(uname -m)
    local target_arch=$(file zkstack_cli/target/release/zkstack | grep -o 'x86-64\|aarch64\|ARM' || echo "unknown")
    
    log_info "本机架构: $local_arch"
    log_info "二进制目标架构: $target_arch"
    
    # 简单的架构兼容性检查
    if [[ "$local_arch" == "x86_64" && "$target_arch" == *"x86-64"* ]]; then
        log_success "架构兼容性检查通过"
    elif [[ "$local_arch" == "aarch64" && "$target_arch" == *"aarch64"* ]]; then
        log_success "架构兼容性检查通过"
    else
        log_warning "架构可能不兼容，请确保目标服务器架构匹配"
    fi
}

# 创建部署包
create_deployment_package() {
    log_info "创建部署包..."
    
    local package_name="zksync-bsc-${NETWORK}-$(date +%Y%m%d-%H%M%S).tar.gz"
    local temp_dir=$(mktemp -d)
    local package_dir="$temp_dir/zksync-era"
    
    # 创建包目录结构
    mkdir -p "$package_dir"/{bin,configs,chains,scripts}
    
    # 复制二进制文件
    log_info "打包二进制文件..."
    cp zkstack_cli/target/release/zkstack "$package_dir/bin/"
    cp core/target/release/zksync_server "$package_dir/bin/"
    
    # 复制其他可选二进制文件
    for binary in zksync_external_node zksync_contract_verifier; do
        if [[ -f "core/target/release/$binary" ]]; then
            cp "core/target/release/$binary" "$package_dir/bin/"
        fi
    done
    
    # 复制配置文件和脚本
    log_info "打包配置文件..."
    if [[ -d "chains" ]]; then
        cp -r chains/* "$package_dir/chains/" 2>/dev/null || true
    fi
    if [[ -d "etc" ]]; then
        cp -r etc "$package_dir/" 2>/dev/null || true
    fi
    
    # 复制部署脚本和配置
    cp deploy_prebuilt_bsc.sh "$package_dir/scripts/"
    cp nginx.conf "$package_dir/configs/" 2>/dev/null || true
    cp prometheus.yml "$package_dir/configs/" 2>/dev/null || true
    cp .env.example "$package_dir/configs/" 2>/dev/null || true
    
    # 创建版本信息
    cat > "$package_dir/VERSION" << EOF
ZKStack BSC $NETWORK Deployment Package
Build Date: $(date)
Git Commit: $(git rev-parse HEAD 2>/dev/null || echo "unknown")
Architecture: $(uname -m)
Network: $NETWORK (Chain ID: $CHAIN_ID)
EOF

    # 创建安装脚本
    cat > "$package_dir/install.sh" << 'EOF'
#!/bin/bash
# ZKStack BSC 安装脚本

set -e

DEPLOY_DIR="/opt/zksync-era"
SERVICE_USER="zksync"

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "请使用 sudo 运行此脚本"
   exit 1
fi

echo "开始安装 ZKStack BSC..."

# 创建用户
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /bin/false $SERVICE_USER
    echo "创建用户: $SERVICE_USER"
fi

# 创建目录
mkdir -p $DEPLOY_DIR
cp -r . $DEPLOY_DIR/
chown -R $SERVICE_USER:$SERVICE_USER $DEPLOY_DIR
chmod +x $DEPLOY_DIR/bin/*

echo "安装完成！"
echo "二进制文件位置: $DEPLOY_DIR/bin/"
echo "配置文件位置: $DEPLOY_DIR/configs/"
echo "请运行: $DEPLOY_DIR/scripts/deploy_prebuilt_bsc.sh setup"
EOF

    chmod +x "$package_dir/install.sh"
    
    # 打包
    log_info "压缩部署包..."
    cd "$temp_dir"
    tar -czf "$package_name" zksync-era/
    mv "$package_name" "$OLDPWD/"
    cd "$OLDPWD"
    
    # 清理临时目录
    rm -rf "$temp_dir"
    
    log_success "部署包创建完成: $package_name"
    echo "部署包大小: $(du -h $package_name | cut -f1)"
}

# 安装系统依赖 (无需编译工具)
install_runtime_dependencies() {
    log_info "安装运行时依赖..."
    
    # 更新系统
    apt update
    
    # 安装运行时依赖 (不包括编译工具)
    apt install -y \
        curl \
        wget \
        postgresql-client \
        nginx \
        jq \
        htop \
        systemd \
        ca-certificates \
        openssl \
        libc6 \
        libssl3 \
        libpq5
    
    log_success "运行时依赖安装完成"
}

# 设置数据库 (使用 Docker，避免复杂的 PostgreSQL 安装)
setup_database() {
    log_info "设置数据库..."
    
    # 安装 Docker (如果未安装)
    if ! command -v docker &> /dev/null; then
        log_info "安装 Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        systemctl enable docker
        systemctl start docker
    fi
    
    # 生成数据库密码
    local db_password=$(openssl rand -base64 32)
    echo "$db_password" > /root/.zksync_db_password_$NETWORK
    chmod 600 /root/.zksync_db_password_$NETWORK
    
    # 启动 PostgreSQL 容器
    docker run -d \
        --name zksync-postgres-$NETWORK \
        --restart unless-stopped \
        -e POSTGRES_DB=postgres \
        -e POSTGRES_USER=postgres \
        -e POSTGRES_PASSWORD="$db_password" \
        -p 5432:5432 \
        -v postgres_data_$NETWORK:/var/lib/postgresql/data \
        postgres:14
    
    # 等待数据库启动
    log_info "等待数据库启动..."
    sleep 15
    
    # 创建应用数据库
    docker exec zksync-postgres-$NETWORK psql -U postgres -c "CREATE DATABASE $DB_NAME;" || true
    
    log_success "数据库设置完成"
}

# 创建配置文件
create_configuration() {
    log_info "创建配置文件..."
    
    local db_password=$(cat /root/.zksync_db_password_$NETWORK)
    
    # 创建环境配置
    cat > "$DEPLOY_DIR/.env.$NETWORK" << EOF
# BSC $NETWORK 网络配置
L1_CHAIN_ID=$CHAIN_ID
L1_RPC_URL=$RPC_URL

# 数据库配置
DATABASE_URL=postgres://postgres:$db_password@localhost:5432/$DB_NAME

# 服务配置
API_WEB3_JSON_RPC_HTTP_PORT=3050
API_WEB3_JSON_RPC_WS_PORT=3051
API_PROMETHEUS_PORT=3312
API_HEALTHCHECK_PORT=3081

# 日志配置
RUST_LOG=info
RUST_BACKTRACE=1
EOF

    chown $SERVICE_USER:$SERVICE_USER "$DEPLOY_DIR/.env.$NETWORK"
    
    log_success "配置文件创建完成"
}

# 初始化生态系统
initialize_ecosystem() {
    log_info "初始化 ZKStack 生态系统..."
    
    local db_password=$(cat /root/.zksync_db_password_$NETWORK)
    
    # 设置环境变量
    export L1_CHAIN_ID=$CHAIN_ID
    export L1_RPC_URL=$RPC_URL
    
    # 使用预编译的 zkstack 二进制文件
    cd "$DEPLOY_DIR"
    sudo -u $SERVICE_USER ./bin/zkstack ecosystem init \
        --l1-rpc-url "$RPC_URL" \
        --server-db-url "postgres://postgres:$db_password@localhost:5432" \
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
    
    cat > /etc/systemd/system/zksync-server-$NETWORK.service << EOF
[Unit]
Description=ZKSync Server for BSC $NETWORK (Prebuilt)
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$DEPLOY_DIR
Environment=L1_CHAIN_ID=$CHAIN_ID
Environment=L1_RPC_URL=$RPC_URL
EnvironmentFile=$DEPLOY_DIR/.env.$NETWORK
ExecStart=$DEPLOY_DIR/bin/zksync_server \\
    --genesis-path $DEPLOY_DIR/chains/${NETWORK}_chain/configs/genesis.yaml \\
    --config-path $DEPLOY_DIR/chains/${NETWORK}_chain/configs/general.yaml \\
    --wallets-path $DEPLOY_DIR/chains/${NETWORK}_chain/configs/wallets.yaml \\
    --secrets-path $DEPLOY_DIR/chains/${NETWORK}_chain/configs/secrets.yaml \\
    --contracts-config-path $DEPLOY_DIR/chains/${NETWORK}_chain/configs/contracts.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=zksync-server-$NETWORK

# 资源限制
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable zksync-server-$NETWORK
    
    log_success "systemd 服务创建完成"
}

# 配置 Nginx
setup_nginx() {
    log_info "配置 Nginx..."
    
    # 复制 nginx 配置
    if [[ -f "$DEPLOY_DIR/configs/nginx.conf" ]]; then
        cp "$DEPLOY_DIR/configs/nginx.conf" /etc/nginx/sites-available/zksync-bsc-$NETWORK
    else
        # 创建基本的 nginx 配置
        cat > /etc/nginx/sites-available/zksync-bsc-$NETWORK << 'EOF'
server {
    listen 80;
    server_name _;

    location /api {
        proxy_pass http://localhost:3050;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
    }

    location /ws {
        proxy_pass http://localhost:3051;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /health {
        proxy_pass http://localhost:3081/health;
    }

    location /metrics {
        proxy_pass http://localhost:3312/metrics;
        allow 127.0.0.1;
        deny all;
    }
}
EOF
    fi
    
    # 启用站点
    ln -sf /etc/nginx/sites-available/zksync-bsc-$NETWORK /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx
    
    log_success "Nginx 配置完成"
}

# 创建管理脚本
create_management_scripts() {
    log_info "创建管理脚本..."
    
    # 健康检查脚本
    cat > "$DEPLOY_DIR/health_check.sh" << EOF
#!/bin/bash
SERVICE_NAME="zksync-server-$NETWORK"

# 检查服务状态
if ! systemctl is-active --quiet \$SERVICE_NAME; then
    echo "ERROR: \$SERVICE_NAME is not running"
    exit 1
fi

# 检查API响应
if ! curl -s http://localhost:3081/health > /dev/null; then
    echo "ERROR: Health check failed"
    exit 1
fi

# 检查链ID
CHAIN_ID_RESPONSE=\$(curl -s -X POST -H "Content-Type: application/json" \\
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \\
  http://localhost:3050/api | jq -r '.result' 2>/dev/null)

if [[ "\$CHAIN_ID_RESPONSE" == "null" || "\$CHAIN_ID_RESPONSE" == "" ]]; then
    echo "ERROR: Cannot get chain ID"
    exit 1
fi

echo "OK: All services healthy (Chain ID: \$CHAIN_ID_RESPONSE)"
EOF

    # 备份脚本
    cat > "$DEPLOY_DIR/backup.sh" << EOF
#!/bin/bash
BACKUP_DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/zksync_backup_\$BACKUP_DATE.sql"

mkdir -p $BACKUP_DIR

# 备份数据库
docker exec zksync-postgres-$NETWORK pg_dump -U postgres $DB_NAME > "\$BACKUP_FILE"

# 压缩备份
gzip "\$BACKUP_FILE"

echo "备份完成: \$BACKUP_FILE.gz"

# 清理旧备份 (保留7天)
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete
EOF

    # 更新脚本
    cat > "$DEPLOY_DIR/update.sh" << EOF
#!/bin/bash
# 更新预编译二进制文件

if [[ \$EUID -ne 0 ]]; then
   echo "请使用 sudo 运行此脚本"
   exit 1
fi

echo "停止服务..."
systemctl stop zksync-server-$NETWORK

echo "备份当前版本..."
cp -r $DEPLOY_DIR $BACKUP_DIR/zksync-era-backup-\$(date +%Y%m%d_%H%M%S)

echo "请将新的二进制文件复制到 $DEPLOY_DIR/bin/ 目录"
echo "然后运行: systemctl start zksync-server-$NETWORK"
EOF

    chmod +x "$DEPLOY_DIR"/*.sh
    chown $SERVICE_USER:$SERVICE_USER "$DEPLOY_DIR"/*.sh
    
    log_success "管理脚本创建完成"
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    systemctl start zksync-server-$NETWORK
    sleep 10
    
    if systemctl is-active --quiet zksync-server-$NETWORK; then
        log_success "ZKSync 服务启动成功"
    else
        log_error "ZKSync 服务启动失败"
        journalctl -u zksync-server-$NETWORK --no-pager -l
        exit 1
    fi
}

# 验证部署
verify_deployment() {
    log_info "验证部署..."
    
    # 运行健康检查
    if "$DEPLOY_DIR/health_check.sh"; then
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
    echo "  网络: BSC $NETWORK (Chain ID: $CHAIN_ID)"
    echo "  部署目录: $DEPLOY_DIR"
    echo "  服务用户: $SERVICE_USER"
    echo
    echo "🔗 服务端点:"
    echo "  HTTP API: http://localhost/api"
    echo "  WebSocket: ws://localhost/ws"
    echo "  健康检查: http://localhost/health"
    echo
    echo "🛠 管理命令:"
    echo "  查看状态: systemctl status zksync-server-$NETWORK"
    echo "  查看日志: journalctl -u zksync-server-$NETWORK -f"
    echo "  重启服务: systemctl restart zksync-server-$NETWORK"
    echo "  健康检查: $DEPLOY_DIR/health_check.sh"
    echo "  数据备份: $DEPLOY_DIR/backup.sh"
    echo "  更新服务: $DEPLOY_DIR/update.sh"
    echo
    echo "📁 重要文件:"
    echo "  二进制文件: $DEPLOY_DIR/bin/"
    echo "  配置文件: $DEPLOY_DIR/.env.$NETWORK"
    echo "  数据库密码: /root/.zksync_db_password_$NETWORK"
}

# 主函数
main() {
    case "${2:-deploy}" in
        "package")
            check_binaries
            check_architecture
            create_deployment_package
            ;;
        "setup")
            if [[ $EUID -ne 0 ]]; then
                log_error "请使用 sudo 运行 setup"
                exit 1
            fi
            install_runtime_dependencies
            setup_database
            create_configuration
            initialize_ecosystem
            create_systemd_service
            setup_nginx
            create_management_scripts
            start_services
            verify_deployment
            show_deployment_info
            ;;
        "deploy")
            check_binaries
            check_architecture
            create_deployment_package
            log_info "部署包已创建，请将其传输到目标服务器并运行:"
            echo "  tar -xzf zksync-bsc-*.tar.gz"
            echo "  cd zksync-era"
            echo "  sudo ./install.sh"
            echo "  sudo ./scripts/deploy_prebuilt_bsc.sh $NETWORK setup"
            ;;
        *)
            echo "使用方法: $0 [mainnet|testnet] [package|setup|deploy]"
            echo
            echo "命令说明:"
            echo "  package - 仅创建部署包"
            echo "  setup   - 在目标服务器上安装和配置 (需要 sudo)"
            echo "  deploy  - 创建部署包并显示部署说明 (默认)"
            exit 1
            ;;
    esac
}

# 错误处理
trap 'log_error "操作失败"; exit 1' ERR

# 运行主函数
main "$@"