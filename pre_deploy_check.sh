#!/bin/bash

# 🔍 ZKStack BSC 部署前检查脚本
# 验证系统环境和预编译文件

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✅]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠️]${NC} $1"; }
log_error() { echo -e "${RED}[❌]${NC} $1"; }

# 全局变量
ERRORS=0
WARNINGS=0

# 记录错误
record_error() {
    ERRORS=$((ERRORS + 1))
    log_error "$1"
}

# 记录警告
record_warning() {
    WARNINGS=$((WARNINGS + 1))
    log_warning "$1"
}

# 检查系统信息
check_system() {
    echo "🖥️  系统环境检查"
    echo "=================="
    
    # 操作系统
    if grep -q "Ubuntu" /etc/os-release; then
        local version=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
        if [[ "$version" == "24.04" ]]; then
            log_success "操作系统: Ubuntu 24.04"
        else
            record_warning "操作系统: Ubuntu $version (推荐 24.04)"
        fi
    else
        record_error "操作系统: 不是 Ubuntu 系统"
    fi
    
    # 系统架构
    local arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then
        log_success "系统架构: $arch"
    else
        record_warning "系统架构: $arch (推荐 x86_64)"
    fi
    
    # 内核版本
    local kernel=$(uname -r)
    log_info "内核版本: $kernel"
    
    echo
}

# 检查硬件资源
check_hardware() {
    echo "💾 硬件资源检查"
    echo "================"
    
    # CPU 核心数
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -ge 4 ]]; then
        log_success "CPU 核心: $cpu_cores 核"
    else
        record_warning "CPU 核心: $cpu_cores 核 (推荐 4+ 核)"
    fi
    
    # 内存大小
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $memory_gb -ge 8 ]]; then
        log_success "系统内存: ${memory_gb}GB"
    elif [[ $memory_gb -ge 4 ]]; then
        record_warning "系统内存: ${memory_gb}GB (推荐 8GB+)"
    else
        record_error "系统内存: ${memory_gb}GB (最低需要 4GB)"
    fi
    
    # 磁盘空间
    local disk_gb=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $disk_gb -ge 100 ]]; then
        log_success "可用磁盘: ${disk_gb}GB"
    elif [[ $disk_gb -ge 50 ]]; then
        record_warning "可用磁盘: ${disk_gb}GB (推荐 100GB+)"
    else
        record_error "可用磁盘: ${disk_gb}GB (最低需要 50GB)"
    fi
    
    echo
}

# 检查网络连接
check_network() {
    echo "🌐 网络连接检查"
    echo "================"
    
    # 检查互联网连接
    if curl -s --connect-timeout 5 https://www.google.com >/dev/null; then
        log_success "互联网连接: 正常"
    else
        record_error "互联网连接: 无法访问外网"
    fi
    
    # 检查 BSC RPC 连接
    local bsc_rpc="https://bsc-testnet-dataseed.bnbchain.org"
    if curl -s --connect-timeout 10 -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        "$bsc_rpc" | grep -q "0x61"; then
        log_success "BSC Testnet RPC: 连接正常"
    else
        record_error "BSC Testnet RPC: 连接失败"
    fi
    
    # 检查端口占用
    local ports=(80 3050 3051 3081 3312 5432)
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            record_warning "端口 $port: 已被占用"
        else
            log_success "端口 $port: 可用"
        fi
    done
    
    echo
}

# 检查预编译文件
check_binaries() {
    echo "📦 预编译文件检查"
    echo "=================="
    
    local required_files=(
        "zkstack_cli/target/release/zkstack"
        "core/target/release/zksync_server"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            # 检查文件大小
            local size=$(du -h "$file" | cut -f1)
            
            # 检查架构
            local arch=$(file "$file" | grep -o 'x86-64\|aarch64\|ARM' || echo "unknown")
            
            # 检查权限
            if [[ -x "$file" ]]; then
                log_success "$file ($size, $arch, 可执行)"
            else
                record_warning "$file ($size, $arch, 不可执行)"
            fi
        else
            record_error "$file: 文件不存在"
        fi
    done
    
    # 检查可选文件
    local optional_files=(
        "core/target/release/zksync_external_node"
        "core/target/release/zksync_contract_verifier"
    )
    
    for file in "${optional_files[@]}"; do
        if [[ -f "$file" ]]; then
            local size=$(du -h "$file" | cut -f1)
            log_info "可选文件: $file ($size)"
        fi
    done
    
    echo
}

# 检查配置文件
check_configs() {
    echo "⚙️  配置文件检查"
    echo "================"
    
    # 检查链配置
    if [[ -d "chains" ]]; then
        log_success "链配置目录: 存在"
        local chain_count=$(find chains -name "*.yaml" | wc -l)
        log_info "配置文件数量: $chain_count"
    else
        record_warning "链配置目录: 不存在 (将在初始化时创建)"
    fi
    
    # 检查环境配置
    if [[ -f ".env.example" ]]; then
        log_success "环境配置模板: 存在"
    else
        record_warning "环境配置模板: 不存在"
    fi
    
    # 检查 Nginx 配置
    if [[ -f "nginx.conf" ]]; then
        log_success "Nginx 配置: 存在"
    else
        record_warning "Nginx 配置: 不存在 (将使用默认配置)"
    fi
    
    echo
}

# 检查系统权限
check_permissions() {
    echo "🔐 权限检查"
    echo "==========="
    
    # 检查 root 权限
    if [[ $EUID -eq 0 ]]; then
        log_success "管理员权限: 已获取"
    else
        record_error "管理员权限: 需要 sudo 权限运行部署脚本"
    fi
    
    # 检查 systemd
    if systemctl --version >/dev/null 2>&1; then
        log_success "systemd: 可用"
    else
        record_error "systemd: 不可用"
    fi
    
    # 检查包管理器
    if command -v apt >/dev/null 2>&1; then
        log_success "包管理器: apt 可用"
    else
        record_error "包管理器: apt 不可用"
    fi
    
    echo
}

# 检查已安装的软件
check_installed_software() {
    echo "📋 已安装软件检查"
    echo "=================="
    
    local software=(
        "curl:curl"
        "wget:wget"
        "jq:jq"
        "nginx:nginx"
        "postgresql:postgresql"
        "systemctl:systemd"
    )
    
    for item in "${software[@]}"; do
        local cmd="${item%%:*}"
        local pkg="${item##*:}"
        
        if command -v "$cmd" >/dev/null 2>&1; then
            local version=$($cmd --version 2>/dev/null | head -n1 || echo "unknown")
            log_success "$pkg: 已安装 ($version)"
        else
            log_info "$pkg: 未安装 (将自动安装)"
        fi
    done
    
    echo
}

# 生成部署建议
generate_recommendations() {
    echo "💡 部署建议"
    echo "==========="
    
    if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
        log_success "系统完全满足部署要求，可以直接部署"
        echo
        echo "推荐部署命令:"
        echo "  sudo ./ubuntu_quick_deploy.sh"
        echo "  或"
        echo "  sudo ./deploy_native_ubuntu.sh testnet"
    elif [[ $ERRORS -eq 0 ]]; then
        log_warning "系统基本满足要求，但有 $WARNINGS 个警告"
        echo
        echo "建议:"
        echo "  - 解决上述警告后再部署"
        echo "  - 或者继续部署但需要注意性能"
        echo
        echo "部署命令:"
        echo "  sudo ./ubuntu_quick_deploy.sh"
    else
        log_error "系统不满足部署要求，有 $ERRORS 个错误"
        echo
        echo "必须解决的问题:"
        echo "  - 修复上述所有错误"
        echo "  - 确保有足够的系统资源"
        echo "  - 检查网络连接"
    fi
    
    echo
    echo "部署前准备清单:"
    echo "  □ 确保操作员钱包有足够的 tBNB"
    echo "  □ 准备好私钥 (OPERATOR_PRIVATE_KEY)"
    echo "  □ 配置防火墙规则"
    echo "  □ 备份重要数据"
    
    echo
}

# 主函数
main() {
    echo "🔍 ZKStack BSC 部署前检查"
    echo "=========================="
    echo "检查时间: $(date)"
    echo
    
    check_system
    check_hardware
    check_network
    check_binaries
    check_configs
    check_permissions
    check_installed_software
    generate_recommendations
    
    echo "📊 检查结果汇总"
    echo "================"
    echo "错误: $ERRORS 个"
    echo "警告: $WARNINGS 个"
    echo
    
    if [[ $ERRORS -eq 0 ]]; then
        echo "✅ 系统检查通过，可以开始部署！"
        exit 0
    else
        echo "❌ 系统检查失败，请解决错误后重试"
        exit 1
    fi
}

# 帮助信息
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "ZKStack BSC 部署前检查脚本"
    echo
    echo "此脚本会检查系统环境是否满足 ZKStack BSC 节点的部署要求。"
    echo
    echo "使用方法:"
    echo "  $0"
    echo
    echo "检查项目:"
    echo "  - 系统环境 (Ubuntu 24.04)"
    echo "  - 硬件资源 (CPU, 内存, 磁盘)"
    echo "  - 网络连接 (互联网, BSC RPC)"
    echo "  - 预编译文件"
    echo "  - 配置文件"
    echo "  - 系统权限"
    echo "  - 已安装软件"
    echo
    echo "注意: 此脚本不会修改系统，仅进行检查。"
    exit 0
fi

# 运行检查
main "$@"