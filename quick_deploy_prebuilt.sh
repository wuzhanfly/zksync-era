#!/bin/bash

# 🚀 ZKStack BSC 预编译二进制快速部署脚本
# 使用本机编译的二进制文件快速部署到服务器

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

# 检查预编译文件
check_prebuilt_binaries() {
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
        log_error "缺少预编译文件，请先编译:"
        for file in "${missing_files[@]}"; do
            echo "  ❌ $file"
        done
        echo
        log_info "编译命令:"
        echo "  cd zkstack_cli && cargo build --release"
        echo "  cd core && cargo build --release --bin zksync_server"
        exit 1
    fi
    
    # 显示文件信息
    for file in "${required_files[@]}"; do
        local size=$(du -h "$file" | cut -f1)
        local arch=$(file "$file" | grep -o 'x86-64\|aarch64\|ARM' || echo "unknown")
        echo "  ✅ $file ($size, $arch)"
    done
    
    log_success "预编译文件检查完成"
}

# 创建环境配置
setup_environment() {
    log_info "设置环境配置..."
    
    if [[ ! -f .env ]]; then
        log_info "创建 .env 文件..."
        cp .env.example .env
        
        # 生成随机密码
        local db_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        sed -i "s/your_very_secure_password_here/$db_password/g" .env
        
        log_warning "⚠️  请编辑 .env 文件设置你的私钥!"
        log_warning "特别重要: OPERATOR_PRIVATE_KEY 和 GOVERNOR_PRIVATE_KEY"
        
        read -p "是否现在编辑 .env 文件? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} .env
        fi
    else
        log_info ".env 文件已存在"
    fi
    
    # 验证关键配置
    source .env
    if [[ -z "$OPERATOR_PRIVATE_KEY" || "$OPERATOR_PRIVATE_KEY" == "0x1234567890abcdef..." ]]; then
        log_error "请在 .env 文件中设置有效的 OPERATOR_PRIVATE_KEY"
        exit 1
    fi
    
    log_success "环境配置完成"
}

# 创建数据库初始化脚本
create_db_init() {
    log_info "创建数据库初始化脚本..."
    
    cat > init-db.sql << 'EOF'
-- 创建 BSC 数据库
CREATE DATABASE zk_bsc_testnet;
CREATE DATABASE zk_bsc_mainnet;

-- 显示创建的数据库
\l
EOF

    log_success "数据库初始化脚本创建完成"
}

# 构建和启动服务
deploy_with_docker() {
    log_info "使用 Docker 部署服务..."
    
    # 检查 Docker
    if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
        log_error "请先安装 Docker 和 Docker Compose"
        exit 1
    fi
    
    # 停止可能存在的服务
    docker-compose -f docker-compose.prebuilt.yml down 2>/dev/null || true
    
    # 构建镜像
    log_info "构建 ZKSync 镜像 (使用预编译二进制)..."
    docker-compose -f docker-compose.prebuilt.yml build --no-cache
    
    # 启动服务
    log_info "启动服务..."
    docker-compose -f docker-compose.prebuilt.yml up -d
    
    log_success "服务启动完成"
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务启动..."
    
    # 等待数据库
    local timeout=60
    while ! docker-compose -f docker-compose.prebuilt.yml exec -T postgres pg_isready -U postgres &> /dev/null; do
        sleep 2
        timeout=$((timeout - 2))
        if [[ $timeout -le 0 ]]; then
            log_error "PostgreSQL 启动超时"
            docker-compose -f docker-compose.prebuilt.yml logs postgres
            exit 1
        fi
        echo -n "."
    done
    echo
    log_success "PostgreSQL 已就绪"
    
    # 等待 ZKSync 服务
    log_info "等待 ZKSync 服务启动..."
    timeout=180  # 增加超时时间，因为初始化可能需要更长时间
    while ! curl -s http://localhost:3081/health &> /dev/null; do
        sleep 5
        timeout=$((timeout - 5))
        if [[ $timeout -le 0 ]]; then
            log_error "ZKSync 服务启动超时"
            log_info "查看服务日志:"
            docker-compose -f docker-compose.prebuilt.yml logs zksync-server
            exit 1
        fi
        echo -n "."
    done
    echo
    log_success "ZKSync 服务已就绪"
}

# 验证部署
verify_deployment() {
    log_info "验证部署..."
    
    # 检查健康状态
    local health_response=$(curl -s http://localhost/health 2>/dev/null || echo "failed")
    if [[ "$health_response" == *"ok"* ]]; then
        log_success "✅ 健康检查通过"
    else
        log_error "❌ 健康检查失败: $health_response"
        return 1
    fi
    
    # 检查 API
    local chain_id_response=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        http://localhost/api 2>/dev/null | jq -r '.result' 2>/dev/null || echo "failed")
    
    if [[ "$chain_id_response" =~ ^0x[0-9a-fA-F]+$ ]]; then
        local chain_id_decimal=$((chain_id_response))
        local network_name="Unknown"
        case $chain_id_decimal in
            56) network_name="BSC Mainnet" ;;
            97) network_name="BSC Testnet" ;;
        esac
        log_success "✅ API 响应正常 - $network_name (Chain ID: $chain_id_response)"
    else
        log_error "❌ API 响应异常: $chain_id_response"
        return 1
    fi
    
    # 检查服务状态
    log_info "服务状态:"
    docker-compose -f docker-compose.prebuilt.yml ps
    
    log_success "部署验证完成"
}

# 显示部署信息
show_deployment_info() {
    source .env 2>/dev/null || true
    
    log_success "🎉 ZKStack BSC 节点部署完成!"
    echo
    echo "📊 部署信息:"
    echo "  网络: $([ "${L1_CHAIN_ID:-97}" == "56" ] && echo "BSC Mainnet" || echo "BSC Testnet") (Chain ID: ${L1_CHAIN_ID:-97})"
    echo "  RPC URL: ${L1_RPC_URL:-https://bsc-testnet-dataseed.bnbchain.org}"
    echo "  部署方式: Docker (预编译二进制)"
    echo
    echo "🔗 服务端点:"
    echo "  HTTP API: http://localhost/api"
    echo "  WebSocket: ws://localhost/ws"
    echo "  健康检查: http://localhost/health"
    echo "  Nginx 状态: http://localhost"
    echo
    echo "🛠 管理命令:"
    echo "  查看状态: docker-compose -f docker-compose.prebuilt.yml ps"
    echo "  查看日志: docker-compose -f docker-compose.prebuilt.yml logs -f"
    echo "  重启服务: docker-compose -f docker-compose.prebuilt.yml restart"
    echo "  停止服务: docker-compose -f docker-compose.prebuilt.yml down"
    echo "  进入容器: docker-compose -f docker-compose.prebuilt.yml exec zksync-server bash"
    echo
    echo "📋 测试命令:"
    echo "  健康检查: curl http://localhost/health"
    echo "  获取链ID: curl -X POST -H 'Content-Type: application/json' \\"
    echo "            --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}' \\"
    echo "            http://localhost/api"
    echo
    echo "⚠️  重要提醒:"
    echo "  1. 确保操作员地址有足够的 $([ "${L1_CHAIN_ID:-97}" == "56" ] && echo "BNB" || echo "tBNB") 余额"
    echo "  2. 生产环境请配置 HTTPS 和域名"
    echo "  3. 定期备份数据: docker-compose -f docker-compose.prebuilt.yml exec postgres pg_dump -U postgres ${DB_NAME:-zk_bsc_testnet}"
    echo "  4. 监控日志: docker-compose -f docker-compose.prebuilt.yml logs -f zksync-server"
}

# 创建管理脚本
create_management_scripts() {
    log_info "创建管理脚本..."
    
    # 备份脚本
    cat > backup.sh << 'EOF'
#!/bin/bash
# ZKSync BSC 数据备份脚本

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "开始备份数据库..."
docker-compose -f docker-compose.prebuilt.yml exec -T postgres pg_dump -U postgres zk_bsc_testnet > "$BACKUP_DIR/zk_bsc_testnet_$TIMESTAMP.sql"
docker-compose -f docker-compose.prebuilt.yml exec -T postgres pg_dump -U postgres zk_bsc_mainnet > "$BACKUP_DIR/zk_bsc_mainnet_$TIMESTAMP.sql"

echo "压缩备份文件..."
gzip "$BACKUP_DIR"/*.sql

echo "备份完成: $BACKUP_DIR/"
ls -lh "$BACKUP_DIR"/*$TIMESTAMP*

# 清理7天前的备份
find "$BACKUP_DIR" -name "*.gz" -mtime +7 -delete
EOF

    # 更新脚本
    cat > update.sh << 'EOF'
#!/bin/bash
# ZKSync BSC 更新脚本

echo "停止服务..."
docker-compose -f docker-compose.prebuilt.yml down

echo "备份当前数据..."
./backup.sh

echo "重新构建镜像..."
docker-compose -f docker-compose.prebuilt.yml build --no-cache

echo "启动服务..."
docker-compose -f docker-compose.prebuilt.yml up -d

echo "等待服务启动..."
sleep 30

echo "验证服务..."
curl -s http://localhost/health && echo "✅ 服务正常" || echo "❌ 服务异常"
EOF

    # 监控脚本
    cat > monitor.sh << 'EOF'
#!/bin/bash
# ZKSync BSC 监控脚本

echo "=== ZKSync BSC 服务监控 ==="
echo "时间: $(date)"
echo

echo "📊 容器状态:"
docker-compose -f docker-compose.prebuilt.yml ps
echo

echo "🔍 健康检查:"
HEALTH=$(curl -s http://localhost/health 2>/dev/null || echo "FAILED")
echo "  健康状态: $HEALTH"

CHAIN_ID=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost/api 2>/dev/null | jq -r '.result' 2>/dev/null || echo "FAILED")
echo "  链ID: $CHAIN_ID"
echo

echo "💾 资源使用:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
echo

echo "📝 最近日志 (最后10行):"
docker-compose -f docker-compose.prebuilt.yml logs --tail=10 zksync-server
EOF

    chmod +x *.sh
    
    log_success "管理脚本创建完成"
}

# 主函数
main() {
    case "${1:-deploy}" in
        "deploy")
            log_info "🚀 开始 ZKStack BSC 预编译部署..."
            check_prebuilt_binaries
            setup_environment
            create_db_init
            deploy_with_docker
            wait_for_services
            verify_deployment
            create_management_scripts
            show_deployment_info
            log_success "部署完成! 🎉"
            ;;
        "start")
            log_info "启动 ZKStack BSC 服务..."
            docker-compose -f docker-compose.prebuilt.yml up -d
            wait_for_services
            verify_deployment
            log_success "服务启动完成!"
            ;;
        "stop")
            log_info "停止 ZKStack BSC 服务..."
            docker-compose -f docker-compose.prebuilt.yml down
            log_success "服务已停止"
            ;;
        "restart")
            log_info "重启 ZKStack BSC 服务..."
            docker-compose -f docker-compose.prebuilt.yml restart
            wait_for_services
            verify_deployment
            log_success "服务重启完成!"
            ;;
        "logs")
            docker-compose -f docker-compose.prebuilt.yml logs -f
            ;;
        "status")
            docker-compose -f docker-compose.prebuilt.yml ps
            echo
            ./monitor.sh 2>/dev/null || echo "运行 ./quick_deploy_prebuilt.sh deploy 创建监控脚本"
            ;;
        "backup")
            ./backup.sh 2>/dev/null || log_error "请先运行部署创建备份脚本"
            ;;
        *)
            echo "ZKStack BSC 预编译部署工具"
            echo
            echo "使用方法: $0 [命令]"
            echo
            echo "可用命令:"
            echo "  deploy  - 完整部署 (默认)"
            echo "  start   - 启动服务"
            echo "  stop    - 停止服务"
            echo "  restart - 重启服务"
            echo "  logs    - 查看日志"
            echo "  status  - 查看状态"
            echo "  backup  - 备份数据"
            echo
            echo "特点:"
            echo "  ✅ 使用预编译二进制文件，无需服务器编译"
            echo "  ✅ Docker 容器化部署，环境隔离"
            echo "  ✅ 自动 BSC 网络兼容性"
            echo "  ✅ 内置监控和管理工具"
            exit 1
            ;;
    esac
}

# 错误处理
trap 'log_error "操作失败"; exit 1' ERR

# 运行主函数
main "$@"