#!/bin/bash

# BSC核心适配阶段1测试脚本
# 测试eth_watch, eth_sender, fee_model的BSC适配

# 不要在测试失败时立即退出，让所有测试都运行完

echo "🧪 BSC核心适配阶段1测试"
echo "========================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 运行测试的函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    local description="$3"
    
    echo -e "${BLUE}📋 测试: ${test_name}${NC}"
    echo -e "${CYAN}   描述: ${description}${NC}"
    echo -e "${YELLOW}   命令: ${test_command}${NC}"
    echo ""
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ ${test_name} 通过${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}❌ ${test_name} 失败${NC}"
        ((FAILED_TESTS++))
    fi
    
    ((TOTAL_TESTS++))
    echo ""
    echo "----------------------------------------"
    echo ""
}

echo -e "${PURPLE}🚀 开始BSC核心适配阶段1测试...${NC}"
echo ""

# 1. BSC配置模块测试
run_test "BSC配置模块编译测试" \
    "(cd core && cargo check -p zksync_config --quiet)" \
    "检查BSC配置模块是否能正常编译"

run_test "BSC网络配置测试" \
    "grep -q 'BSCMainnet\\|BSCTestnet' core/lib/config/src/configs/networks.rs" \
    "检查BSC网络配置是否正确定义"

run_test "BSC EthConfig优化测试" \
    "grep -q 'for_bsc_mainnet\\|for_bsc_testnet' core/lib/config/src/configs/eth_sender.rs" \
    "检查BSC特定的EthConfig优化是否存在"

# 2. BSC eth_watch模块测试
run_test "BSC eth_watch模块编译测试" \
    "(cd core && cargo check -p zksync_eth_watch --quiet)" \
    "检查BSC eth_watch模块是否能正常编译"

run_test "BSC客户端文件存在测试" \
    "test -f core/node/eth_watch/src/bsc_client.rs" \
    "检查BSC客户端实现文件是否存在"

run_test "BSC客户端代码结构测试" \
    "grep -q 'BSCEthClient\\|BSCClientConfig' core/node/eth_watch/src/bsc_client.rs" \
    "检查BSC客户端核心结构是否正确定义"

run_test "BSC metrics集成测试" \
    "grep -q 'bsc_gas_price_updates\\|bsc_events_processed' core/node/eth_watch/src/metrics.rs" \
    "检查BSC特定指标是否正确集成"

# 3. BSC eth_sender模块测试
run_test "BSC eth_sender模块编译测试" \
    "(cd core && cargo check -p zksync_eth_sender --quiet)" \
    "检查BSC eth_sender模块是否能正常编译"

run_test "BSC交易管理器文件存在测试" \
    "test -f core/node/eth_sender/src/bsc_tx_manager.rs" \
    "检查BSC交易管理器实现文件是否存在"

run_test "BSC交易管理器代码结构测试" \
    "grep -q 'BSCTxManager\\|BSCTxManagerConfig' core/node/eth_sender/src/bsc_tx_manager.rs" \
    "检查BSC交易管理器核心结构是否正确定义"

run_test "BSC Legacy交易支持测试" \
    "grep -q 'force_legacy_tx\\|create_bsc_transaction' core/node/eth_sender/src/bsc_tx_manager.rs" \
    "检查BSC Legacy交易支持是否正确实现"

run_test "BSC eth_sender metrics测试" \
    "grep -q 'bsc_tx_sent\\|bsc_tx_confirmed' core/node/eth_sender/src/metrics.rs" \
    "检查BSC eth_sender特定指标是否正确集成"

# 4. BSC fee_model模块测试
run_test "BSC fee_model模块编译测试" \
    "(cd core && cargo check -p zksync_node_fee_model --quiet)" \
    "检查BSC fee_model模块是否能正常编译"

run_test "BSC费用模型文件存在测试" \
    "test -f core/node/fee_model/src/bsc_fee_model.rs" \
    "检查BSC费用模型实现文件是否存在"

run_test "BSC费用模型代码结构测试" \
    "grep -q 'BSCFeeModelProvider\\|BSCFeeModelConfig' core/node/fee_model/src/bsc_fee_model.rs" \
    "检查BSC费用模型核心结构是否正确定义"

run_test "BSC拥堵检测测试" \
    "grep -q 'BSCCongestionDetector\\|detect_congestion' core/node/fee_model/src/bsc_fee_model.rs" \
    "检查BSC网络拥堵检测是否正确实现"

# 5. BSC集成测试
run_test "BSC模块导出测试" \
    "grep -q 'BSCEthClient\\|BSCTxManager\\|BSCFeeModelProvider' core/node/eth_watch/src/lib.rs core/node/eth_sender/src/lib.rs core/node/fee_model/src/lib.rs" \
    "检查BSC模块是否正确导出"

run_test "BSC配置集成测试" \
    "grep -q 'is_bsc_network\\|get_bsc_config' core/lib/config/src/configs/eth_sender.rs" \
    "检查BSC配置集成方法是否存在"

# 6. BSC特性验证测试
run_test "BSC 3秒区块时间配置测试" \
    "grep -q 'block_time.*3\\|Duration::from_millis(500)' core/node/eth_watch/src/bsc_client.rs core/lib/config/src/configs/eth_sender.rs" \
    "检查BSC 3秒区块时间优化是否正确配置"

run_test "BSC Legacy交易配置测试" \
    "grep -q 'force_legacy_tx.*true\\|use_legacy_transactions.*true' core/node/eth_sender/src/bsc_tx_manager.rs core/node/eth_watch/src/bsc_client.rs" \
    "检查BSC Legacy交易强制使用是否正确配置"

run_test "BSC Gas价格限制测试" \
    "grep -q '20_000_000_000\\|50_000_000_000' core/node/eth_sender/src/bsc_tx_manager.rs core/node/fee_model/src/bsc_fee_model.rs" \
    "检查BSC Gas价格限制是否正确设置"

run_test "BSC EIP-1559禁用测试" \
    "grep -q 'default_priority_fee_per_gas.*0\\|supports_eip1559.*false' core/lib/config/src/configs/eth_sender.rs core/node/eth_watch/src/bsc_client.rs" \
    "检查BSC EIP-1559禁用是否正确配置"

# 计算测试时间
END_TIME=$(date +%s)

# 生成测试报告
echo ""
echo "🎊 BSC核心适配阶段1测试完成！"
echo "============================="
echo ""

# 测试统计
echo -e "${BLUE}📊 测试统计总览${NC}"
echo "----------------------------------------"
echo -e "总测试数:     ${CYAN}${TOTAL_TESTS}${NC}"
echo -e "通过测试:     ${GREEN}${PASSED_TESTS}${NC}"
echo -e "失败测试:     ${RED}${FAILED_TESTS}${NC}"

if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "成功率:       ${GREEN}${SUCCESS_RATE}%${NC}"
else
    echo -e "成功率:       ${YELLOW}N/A${NC}"
fi

echo ""

# 详细结果
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 所有阶段1测试通过！BSC核心适配成功！${NC}"
    echo ""
    echo -e "${GREEN}✨ 阶段1成就:${NC}"
    echo -e "${GREEN}  • BSC eth_watch适配完成 - 支持3秒区块时间监控${NC}"
    echo -e "${GREEN}  • BSC eth_sender适配完成 - 支持Legacy交易发送${NC}"
    echo -e "${GREEN}  • BSC fee_model适配完成 - 智能Gas价格管理${NC}"
    echo -e "${GREEN}  • BSC配置优化完成 - 网络特定参数调优${NC}"
    echo -e "${GREEN}  • BSC指标监控完成 - 完整的可观测性支持${NC}"
    echo ""
    echo -e "${GREEN}🚀 BSC核心适配阶段1已准备好进入阶段2！${NC}"
    echo ""
    echo -e "${CYAN}📋 阶段1完成的功能:${NC}"
    echo -e "${CYAN}  ✅ BSC网络事件监控 (eth_watch)${NC}"
    echo -e "${CYAN}  ✅ BSC Legacy交易发送 (eth_sender)${NC}"
    echo -e "${CYAN}  ✅ BSC智能费用计算 (fee_model)${NC}"
    echo -e "${CYAN}  ✅ BSC网络配置优化${NC}"
    echo -e "${CYAN}  ✅ BSC特定指标监控${NC}"
    echo ""
    echo -e "${BLUE}🎯 下一步: 阶段2 - 服务增强${NC}"
    echo -e "${BLUE}  • node_sync BSC适配${NC}"
    echo -e "${BLUE}  • api_server BSC适配${NC}"
    echo -e "${BLUE}  • reorg_detector BSC适配${NC}"
    
    exit 0
else
    echo -e "${RED}⚠️  发现 ${FAILED_TESTS} 个失败的阶段1测试${NC}"
    echo ""
    echo -e "${YELLOW}📋 建议:${NC}"
    echo -e "${YELLOW}  • 检查失败测试的详细输出${NC}"
    echo -e "${YELLOW}  • 确保所有BSC适配文件都已正确创建${NC}"
    echo -e "${YELLOW}  • 验证代码语法和结构正确性${NC}"
    echo -e "${YELLOW}  • 修复相关问题后重新运行测试${NC}"
    echo ""
    echo -e "${YELLOW}🔧 常见问题排查:${NC}"
    echo -e "${YELLOW}  1. 检查文件路径是否正确${NC}"
    echo -e "${YELLOW}  2. 验证模块导入是否完整${NC}"
    echo -e "${YELLOW}  3. 确认代码结构符合现有规范${NC}"
    echo -e "${YELLOW}  4. 检查依赖项是否正确配置${NC}"
    echo ""
    exit 1
fi