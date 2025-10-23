#!/bin/bash

# BSC优化应用脚本
# 用于将BSC优化配置应用到ZKStack链的general.yaml文件

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示使用说明
show_usage() {
    echo "BSC优化应用脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -c, --chain CHAIN_NAME     指定链名称 (可选，默认使用当前链)"
    echo "  -n, --network NETWORK      网络类型 (mainnet|testnet)"
    echo "  -b, --backup              创建配置备份"
    echo "  -v, --validate            应用后验证配置"
    echo "  -h, --help                显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --network mainnet --backup --validate"
    echo "  $0 -c my_chain -n testnet -b -v"
}

# 默认参数
CHAIN_NAME=""
NETWORK_TYPE=""
CREATE_BACKUP=false
VALIDATE_CONFIG=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--chain)
            CHAIN_NAME="$2"
            shift 2
            ;;
        -n|--network)
            NETWORK_TYPE="$2"
            shift 2
            ;;
        -b|--backup)
            CREATE_BACKUP=true
            shift
            ;;
        -v|--validate)
            VALIDATE_CONFIG=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "未知参数: $1"
            show_usage
            exit 1
            ;;
    esac
done

# 检查必需参数
if [[ -z "$NETWORK_TYPE" ]]; then
    print_error "必须指定网络类型 (-n|--network)"
    show_usage
    exit 1
fi

# 验证网络类型
if [[ "$NETWORK_TYPE" != "mainnet" && "$NETWORK_TYPE" != "testnet" ]]; then
    print_error "网络类型必须是 'mainnet' 或 'testnet'"
    exit 1
fi

print_info "开始BSC优化配置应用..."
print_info "网络类型: $NETWORK_TYPE"

if [[ -n "$CHAIN_NAME" ]]; then
    print_info "目标链: $CHAIN_NAME"
else
    print_info "使用当前链"
fi

# 检查zkstack命令是否可用
if ! command -v zkstack &> /dev/null; then
    print_error "zkstack命令未找到，请确保已正确安装ZKStack CLI"
    exit 1
fi

# 构建zkstack命令
ZKSTACK_CMD="zkstack chain optimize-for-bsc --network-type $NETWORK_TYPE --apply"

if [[ -n "$CHAIN_NAME" ]]; then
    ZKSTACK_CMD="$ZKSTACK_CMD --chain $CHAIN_NAME"
fi

print_info "执行命令: $ZKSTACK_CMD"

# 执行BSC优化
if $ZKSTACK_CMD; then
    print_success "BSC优化配置已成功应用!"
else
    print_error "BSC优化配置应用失败"
    exit 1
fi

# 验证配置 (如果请求)
if $VALIDATE_CONFIG; then
    print_info "验证BSC配置..."
    
    VALIDATE_CMD="zkstack chain validate-bsc --detailed"
    if [[ -n "$CHAIN_NAME" ]]; then
        VALIDATE_CMD="$VALIDATE_CMD --chain $CHAIN_NAME"
    fi
    
    if $VALIDATE_CMD; then
        print_success "BSC配置验证通过!"
    else
        print_warning "BSC配置验证发现问题，请检查配置"
    fi
fi

# 显示后续步骤
print_info ""
print_info "🎉 BSC优化应用完成!"
print_info ""
print_info "📋 后续步骤:"
print_info "1. 重启ZKStack服务器以使配置生效:"
if [[ -n "$CHAIN_NAME" ]]; then
    print_info "   zkstack server --chain $CHAIN_NAME"
else
    print_info "   zkstack server"
fi
print_info ""
print_info "2. 监控服务器日志确认优化生效:"
print_info "   tail -f logs/zksync_server.log | grep -i bsc"
print_info ""
print_info "3. 验证费用优化效果:"
print_info "   - 检查交易确认时间"
print_info "   - 监控Gas费用使用情况"
print_info "   - 观察批次提交频率"
print_info ""
print_info "4. 如需回滚配置，使用备份文件:"
print_info "   find . -name '*.bsc_backup.*' -type f"

print_success "BSC优化脚本执行完成! 🚀"