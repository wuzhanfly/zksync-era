#!/bin/bash

# 网络配置验证脚本
# 用于验证ZKStack链的网络优化配置是否正确应用

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

print_header() {
    echo -e "${PURPLE}[HEADER]${NC} $1"
}

# 显示使用说明
show_usage() {
    echo "网络配置验证脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -c, --chain CHAIN_NAME     指定链名称 (可选，默认使用当前链)"
    echo "  -d, --detailed             显示详细配置信息"
    echo "  -f, --file CONFIG_FILE     指定要检查的配置文件路径"
    echo "  -h, --help                 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --detailed"
    echo "  $0 -c my_chain -d"
    echo "  $0 -f /path/to/general.yaml"
}

# 默认参数
CHAIN_NAME=""
DETAILED=false
CONFIG_FILE=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--chain)
            CHAIN_NAME="$2"
            shift 2
            ;;
        -d|--detailed)
            DETAILED=true
            shift
            ;;
        -f|--file)
            CONFIG_FILE="$2"
            shift 2
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

print_header "🔍 ZKStack 网络配置验证"
echo "=================================="

# 确定配置文件路径
if [[ -n "$CONFIG_FILE" ]]; then
    GENERAL_CONFIG_PATH="$CONFIG_FILE"
    print_info "使用指定配置文件: $GENERAL_CONFIG_PATH"
else
    # 查找配置文件
    if [[ -n "$CHAIN_NAME" ]]; then
        GENERAL_CONFIG_PATH="chains/$CHAIN_NAME/configs/general.yaml"
    else
        # 尝试查找默认配置
        GENERAL_CONFIG_PATH=$(find . -name "general.yaml" -path "*/chains/*/configs/*" | head -1)
        if [[ -z "$GENERAL_CONFIG_PATH" ]]; then
            GENERAL_CONFIG_PATH="etc/env/file_based/general.yaml"
        fi
    fi
    print_info "使用配置文件: $GENERAL_CONFIG_PATH"
fi

# 检查配置文件是否存在
if [[ ! -f "$GENERAL_CONFIG_PATH" ]]; then
    print_error "配置文件不存在: $GENERAL_CONFIG_PATH"
    exit 1
fi

print_success "✅ 配置文件存在"

# 检测网络类型
print_info "🔍 检测网络配置类型..."

# 检查BSC优化配置
BSC_OPTIMIZED=false
ETH_OPTIMIZED=false

if grep -q "bsc_fee_optimization" "$GENERAL_CONFIG_PATH"; then
    BSC_OPTIMIZED=true
    print_success "✅ 检测到BSC优化配置"
elif grep -q "max_acceptable_priority_fee_in_gwei.*100000000000" "$GENERAL_CONFIG_PATH"; then
    ETH_OPTIMIZED=true
    print_success "✅ 检测到以太坊优化配置"
else
    print_warning "⚠️  未检测到特定网络优化配置"
fi

# 显示网络配置摘要
print_header "📊 网络配置摘要"

if $BSC_OPTIMIZED; then
    echo "🚀 网络类型: BSC 优化配置"
    echo ""
    
    # 检查BSC关键配置
    print_info "🔧 BSC关键配置检查:"
    
    # ETH Sender配置
    if grep -q "max_txs_in_flight.*50" "$GENERAL_CONFIG_PATH"; then
        print_success "  ✅ 并发交易数: 50"
    else
        print_warning "  ⚠️  并发交易数未优化"
    fi
    
    if grep -q "aggregated_block_commit_deadline.*3" "$GENERAL_CONFIG_PATH"; then
        print_success "  ✅ 批次提交间隔: 3秒"
    else
        print_warning "  ⚠️  批次提交间隔未优化"
    fi
    
    if grep -q "pubdata_sending_mode.*CALLDATA" "$GENERAL_CONFIG_PATH"; then
        print_success "  ✅ 数据发送模式: Calldata"
    else
        print_warning "  ⚠️  数据发送模式未优化"
    fi
    
    # ETH Watcher配置
    if grep -q "eth_node_poll_interval.*1500" "$GENERAL_CONFIG_PATH"; then
        print_success "  ✅ 轮询间隔: 1.5秒"
    else
        print_warning "  ⚠️  轮询间隔未优化"
    fi
    
    if grep -q "confirmations_for_eth_event.*2" "$GENERAL_CONFIG_PATH"; then
        print_success "  ✅ 事件确认数: 2个区块"
    else
        print_warning "  ⚠️  事件确认数未优化"
    fi
    
    # State Keeper配置
    if grep -q "block_commit_deadline_ms.*3000" "$GENERAL_CONFIG_PATH"; then
        print_success "  ✅ 状态提交间隔: 3秒"
    else
        print_warning "  ⚠️  状态提交间隔未优化"
    fi
    
    # BSC费用优化
    if grep -q "target_base_fee_gwei.*1" "$GENERAL_CONFIG_PATH"; then
        print_success "  ✅ 目标基础费用: 1 Gwei"
    else
        print_warning "  ⚠️  目标基础费用未设置"
    fi
    
elif $ETH_OPTIMIZED; then
    echo "🔧 网络类型: 以太坊优化配置"
    echo ""
    
    print_info "🔧 以太坊关键配置检查:"
    
    if grep -q "max_acceptable_priority_fee_in_gwei.*100000000000" "$GENERAL_CONFIG_PATH"; then
        print_success "  ✅ 主网优先费用上限: 100 Gwei"
    elif grep -q "max_acceptable_priority_fee_in_gwei.*50000000000" "$GENERAL_CONFIG_PATH"; then
        print_success "  ✅ 测试网优先费用上限: 50 Gwei"
    fi
    
    if grep -q "aggregated_block_commit_deadline.*300" "$GENERAL_CONFIG_PATH"; then
        print_success "  ✅ 主网批次提交间隔: 5分钟"
    elif grep -q "aggregated_block_commit_deadline.*120" "$GENERAL_CONFIG_PATH"; then
        print_success "  ✅ 测试网批次提交间隔: 2分钟"
    fi
    
else
    echo "📋 网络类型: 默认配置"
    print_info "使用标准ZKStack配置，未应用特定网络优化"
fi

# 详细配置显示
if $DETAILED; then
    print_header "📋 详细配置信息"
    
    echo "🔧 ETH Sender配置:"
    grep -A 20 "^eth:" "$GENERAL_CONFIG_PATH" | grep -A 15 "sender:" | head -20 || echo "  未找到ETH Sender配置"
    
    echo ""
    echo "👁️  ETH Watcher配置:"
    grep -A 20 "^eth:" "$GENERAL_CONFIG_PATH" | grep -A 10 "watcher:" | head -10 || echo "  未找到ETH Watcher配置"
    
    echo ""
    echo "🏗️  State Keeper配置:"
    grep -A 15 "^state_keeper:" "$GENERAL_CONFIG_PATH" | head -15 || echo "  未找到State Keeper配置"
    
    if $BSC_OPTIMIZED; then
        echo ""
        echo "💰 BSC费用优化配置:"
        grep -A 10 "^bsc_fee_optimization:" "$GENERAL_CONFIG_PATH" | head -10 || echo "  未找到BSC费用优化配置"
    fi
fi

# 性能预期
print_header "📈 性能预期"

if $BSC_OPTIMIZED; then
    echo "🚀 BSC网络性能预期:"
    echo "  • 交易确认时间: ~6秒 (2个区块)"
    echo "  • 批次提交频率: 每3秒"
    echo "  • 事件同步延迟: ~1.5秒"
    echo "  • 平均Gas费用: ~1 Gwei"
    echo "  • 并发处理能力: 50个交易"
elif $ETH_OPTIMIZED; then
    echo "🔧 以太坊网络性能预期:"
    echo "  • 交易确认时间: ~30-60秒"
    echo "  • 批次提交频率: 每2-5分钟"
    echo "  • 事件同步延迟: ~5秒"
    echo "  • Gas费用管理: 智能调整"
else
    echo "📋 标准性能预期:"
    echo "  • 使用ZKStack默认配置"
    echo "  • 适用于测试和开发环境"
fi

# 建议
print_header "💡 优化建议"

if ! $BSC_OPTIMIZED && ! $ETH_OPTIMIZED; then
    echo "🔧 建议应用网络优化:"
    echo "  • 对于BSC网络: zkstack chain optimize-for-bsc --apply"
    echo "  • 对于以太坊网络: 配置会在init时自动应用"
fi

echo "📊 监控建议:"
echo "  • 定期检查交易确认时间"
echo "  • 监控Gas费用使用情况"
echo "  • 观察批次提交频率"
echo "  • 检查事件同步延迟"

print_success "🎉 网络配置验证完成!"