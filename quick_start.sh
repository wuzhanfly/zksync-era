#!/bin/bash

# 🚀 ZKStack BSC 快速启动脚本
# 使用 Docker Compose 快速部署

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

# 检查 Docker 和 Docker Compose
check_docker() {
    log_info "检查 Docker 环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未运行，请启动 Docker 服务"
        exit 1
    fi
    
    log_success "Docker 环境检查通过"
}

# 创建环境配置
setup_env() {
    log_info "设置环境配置..."
    
    if [[ ! -f .env ]]; then
        log_info "创建 .env 文件..."
        cp .env.example .env
        
        # 生成随机密码
        DB_PASSWORD=$(openssl rand -base64 32)
        sed -i "s/your_very_secure_password_here/$DB_PASSWORD/g" .env
        
        log_warning "请编辑 .env 文件，设置你的私钥和其他配置"
        log_warning "特别注意设置 OPERATOR_PRIVATE_KEY 和 GOVERNOR_PRIVATE_KEY"
        
        read -p "是否现在编辑 .env 文件? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} .env
        fi
    else
        log_info ".env 文件已存在，跳过创建"
    fi
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录..."
    
    mkdir -p chains/bsc_chain/configs
    mkdir -p configs
    mkdir -p ssl
    mkdir -p grafana/dashboards
    mkdir -p grafana/datasources
    
    log_success "目录创建完成"
}

# 初始化数据库
init_database() {
    log_info "创建数据库初始化脚本..."
    
    cat > init-db.sql << 'EOF'
-- 创建 BSC 测试网数据库
CREATE DATABASE zk_bsc_testnet;

-- 创建 BSC 主网数据库
CREATE DATABASE zk_bsc_mainnet;

-- 创建应用用户 (可选)
-- CREATE USER zksync WITH PASSWORD 'secure_password';
-- GRANT ALL PRIVILEGES ON DATABASE zk_bsc_testnet TO zksync;
-- GRANT ALL PRIVILEGES ON DATABASE zk_bsc_mainnet TO zksync;
EOF

    log_success "数据库初始化脚本创建完成"
}

# 启动服务
start_services() {
    log_info "启动 ZKStack BSC 服务..."
    
    # 拉取镜像
    log_info "拉取 Docker 镜像..."
    docker-compose -f docker-compose.bsc.yml pull
    
    # 构建自定义镜像
    log_info "构建 ZKSync 服务镜像..."
    docker-compose -f docker-compose.bsc.yml build
    
    # 启动服务
    log_info "启动所有服务..."
    docker-compose -f docker-compose.bsc.yml up -d
    
    log_success "服务启动完成"
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务启动..."
    
    # 等待数据库
    log_info "等待 PostgreSQL 启动..."
    timeout=60
    while ! docker-compose -f docker-compose.bsc.yml exec -T postgres pg_isready -U postgres &> /dev/null; do
        sleep 2
        timeout=$((timeout - 2))
        if [[ $timeout -le 0 ]]; then
            log_error "PostgreSQL 启动超时"
            exit 1
        fi
    done
    log_success "PostgreSQL 已就绪"
    
    # 等待 ZKSync 服务
    log_info "等待 ZKSync 服务启动..."
    timeout=120
    while ! curl -s http://localhost:3081/health &> /dev/null; do
        sleep 5
        timeout=$((timeout - 5))
        if [[ $timeout -le 0 ]]; then
            log_error "ZKSync 服务启动超时"
            docker-compose -f docker-compose.bsc.yml logs zksync-server
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
    if curl -s http://localhost/health | grep -q "ok"; then
        log_success "健康检查通过"
    else
        log_error "健康检查失败"
        return 1
    fi
    
    # 检查 API
    CHAIN_ID=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        http://localhost/api | jq -r '.result' 2>/dev/null)
    
    if [[ "$CHAIN_ID" =~ ^0x[0-9a-fA-F]+$ ]]; then
        log_success "API 响应正常 (Chain ID: $CHAIN_ID)"
    else
        log_error "API 响应异常"
        return 1
    fi
    
    log_success "部署验证完成"
}

# 显示服务信息
show_info() {
    log_success "🎉 ZKStack BSC 节点部署完成！"
    echo
    echo "📊 服务信息:"
    echo "  HTTP API: http://localhost/api"
    echo "  WebSocket: ws://localhost/ws"
    echo "  健康检查: http://localhost/health"
    echo "  Grafana: http://localhost:3000 (admin/admin)"
    echo "  Prometheus: http://localhost:9090"
    echo
    echo "🛠 管理命令:"
    echo "  查看状态: docker-compose -f docker-compose.bsc.yml ps"
    echo "  查看日志: docker-compose -f docker-compose.bsc.yml logs -f"
    echo "  重启服务: docker-compose -f docker-compose.bsc.yml restart"
    echo "  停止服务: docker-compose -f docker-compose.bsc.yml down"
    echo
    echo "📋 下一步:"
    echo "  1. 确保操作员地址有足够的 BNB/tBNB 余额"
    echo "  2. 配置域名和 SSL 证书 (生产环境)"
    echo "  3. 设置监控告警"
    echo "  4. 定期备份数据"
}

# 清理函数
cleanup() {
    log_info "停止服务..."
    docker-compose -f docker-compose.bsc.yml down
}

# 主函数
main() {
    log_info "开始 ZKStack BSC 快速部署..."
    
    check_docker
    setup_env
    create_directories
    init_database
    start_services
    wait_for_services
    verify_deployment
    show_info
    
    log_success "快速部署完成！🚀"
}

# 错误处理
trap 'log_error "部署失败，正在清理..."; cleanup; exit 1' ERR

# 处理中断信号
trap 'log_info "收到中断信号，正在清理..."; cleanup; exit 0' INT TERM

# 检查参数
case "${1:-}" in
    "start")
        main
        ;;
    "stop")
        log_info "停止 ZKStack BSC 服务..."
        docker-compose -f docker-compose.bsc.yml down
        log_success "服务已停止"
        ;;
    "restart")
        log_info "重启 ZKStack BSC 服务..."
        docker-compose -f docker-compose.bsc.yml restart
        log_success "服务已重启"
        ;;
    "logs")
        docker-compose -f docker-compose.bsc.yml logs -f
        ;;
    "status")
        docker-compose -f docker-compose.bsc.yml ps
        ;;
    *)
        echo "使用方法: $0 {start|stop|restart|logs|status}"
        echo
        echo "命令说明:"
        echo "  start   - 启动所有服务"
        echo "  stop    - 停止所有服务"
        echo "  restart - 重启所有服务"
        echo "  logs    - 查看实时日志"
        echo "  status  - 查看服务状态"
        exit 1
        ;;
esac