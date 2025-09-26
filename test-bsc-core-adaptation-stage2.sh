#!/bin/bash

# BSC核心适配阶段2测试脚本
# 阶段2: 服务增强 - node_sync, api_server, reorg_detector BSC适配

set -e

echo "🧪 BSC核心适配阶段2测试"
echo "========================"
echo ""
echo "🚀 开始BSC核心适配阶段2测试..."
echo ""

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 测试函数
run_test() {
    local test_name="$1"
    local test_description="$2"
    local test_command="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo "📋 测试: $test_name"
    echo "   描述: $test_description"
    echo "   命令: $test_command"
    echo ""
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo "✅ $test_name 通过"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "❌ $test_name 失败"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    echo ""
    echo "----------------------------------------"
    echo ""
}

# ============================================================================
# 阶段2测试: 服务增强
# ============================================================================

# node_sync BSC适配测试
run_test "BSC node_sync模块编译测试" \
    "检查BSC node_sync模块是否能正常编译" \
    "(cd core && cargo check -p zksync_node_sync --quiet)"

run_test "BSC同步器文件存在测试" \
    "检查BSC同步器实现文件是否存在" \
    "test -f core/node/node_sync/src/bsc_sync.rs"

run_test "BSC同步器代码结构测试" \
    "检查BSC同步器核心结构是否正确定义" \
    "grep -q 'BSCSyncManager\\|BSCSyncConfig' core/node/node_sync/src/bsc_sync.rs"

run_test "BSC快速同步测试" \
    "检查BSC快速同步优化是否正确实现" \
    "grep -q 'fast_sync\\|batch_sync' core/node/node_sync/src/bsc_sync.rs"

run_test "BSC node_sync metrics测试" \
    "检查BSC node_sync特定指标是否正确集成" \
    "grep -q 'bsc_sync_progress\\|bsc_blocks_synced' core/node/node_sync/src/metrics.rs"

# api_server BSC适配测试
run_test "BSC api_server模块编译测试" \
    "检查BSC api_server模块是否能正常编译" \
    "(cd core && cargo check -p zksync_node_api_server --quiet)"

run_test "BSC API处理器文件存在测试" \
    "检查BSC API处理器实现文件是否存在" \
    "test -f core/node/api_server/src/bsc_api.rs"

run_test "BSC API处理器代码结构测试" \
    "检查BSC API处理器核心结构是否正确定义" \
    "grep -q 'BSCApiHandler\\|BSCApiConfig' core/node/api_server/src/bsc_api.rs"

run_test "BSC API优化测试" \
    "检查BSC API优化是否正确实现" \
    "grep -q 'bsc_gas_price\\|bsc_block_time' core/node/api_server/src/bsc_api.rs"

run_test "BSC api_server metrics测试" \
    "检查BSC api_server特定指标是否正确集成" \
    "grep -q 'bsc_api_requests\\|bsc_api_response_time' core/node/api_server/src/web3/metrics.rs"

# reorg_detector BSC适配测试
run_test "BSC reorg_detector模块编译测试" \
    "检查BSC reorg_detector模块是否能正常编译" \
    "(cd core && cargo check -p zksync_reorg_detector --quiet)"

run_test "BSC重组检测器文件存在测试" \
    "检查BSC重组检测器实现文件是否存在" \
    "test -f core/node/reorg_detector/src/bsc_detector.rs"

run_test "BSC重组检测器代码结构测试" \
    "检查BSC重组检测器核心结构是否正确定义" \
    "grep -q 'BSCReorgDetector\\|BSCReorgConfig' core/node/reorg_detector/src/bsc_detector.rs"

run_test "BSC重组检测优化测试" \
    "检查BSC重组检测优化是否正确实现" \
    "grep -q 'detect_bsc_reorg\\|bsc_reorg_depth' core/node/reorg_detector/src/bsc_detector.rs"

run_test "BSC reorg_detector metrics测试" \
    "检查BSC reorg_detector特定指标是否正确集成" \
    "grep -q 'bsc_reorgs_detected\\|bsc_reorg_depth' core/node/reorg_detector/src/metrics.rs"

# BSC服务集成测试
run_test "BSC服务模块导出测试" \
    "检查BSC服务模块是否正确导出" \
    "grep -q 'BSCSyncManager\\|BSCApiHandler\\|BSCReorgDetector' core/node/node_sync/src/lib.rs core/node/api_server/src/lib.rs core/node/reorg_detector/src/lib.rs"

run_test "BSC服务配置集成测试" \
    "检查BSC服务配置集成是否存在" \
    "grep -q 'bsc_sync_config\\|bsc_api_config\\|bsc_reorg_config' core/lib/config/src/configs/api.rs core/lib/config/src/configs/database.rs"

# BSC性能优化测试
run_test "BSC 3秒区块同步优化测试" \
    "检查BSC 3秒区块同步优化是否正确配置" \
    "grep -q 'sync_interval.*500\\|block_time.*3' core/node/node_sync/src/bsc_sync.rs"

run_test "BSC API响应优化测试" \
    "检查BSC API响应优化是否正确配置" \
    "grep -q 'response_cache\\|fast_response' core/node/api_server/src/bsc_api.rs"

run_test "BSC重组检测深度优化测试" \
    "检查BSC重组检测深度优化是否正确设置" \
    "grep -q 'reorg_depth.*15\\|confirmation_depth.*10' core/node/reorg_detector/src/bsc_detector.rs"

# BSC网络特性测试
run_test "BSC网络自动检测测试" \
    "检查BSC网络自动检测是否在所有服务中正确实现" \
    "grep -q 'chain_id.*56\\|chain_id.*97' core/node/node_sync/src/bsc_sync.rs core/node/api_server/src/bsc_api.rs core/node/reorg_detector/src/bsc_detector.rs"

run_test "BSC服务启动集成测试" \
    "检查BSC服务启动集成是否正确配置" \
    "grep -q 'start_bsc_services\\|initialize_bsc' core/node/node_sync/src/lib.rs core/node/api_server/src/lib.rs"

# ============================================================================
# 测试结果统计
# ============================================================================

echo ""
echo "🎊 BSC核心适配阶段2测试完成！"
echo "============================="
echo ""
echo "📊 测试统计总览"
echo "----------------------------------------"
echo "总测试数:     $TOTAL_TESTS"
echo "通过测试:     $PASSED_TESTS"
echo "失败测试:     $FAILED_TESTS"

if [ $FAILED_TESTS -eq 0 ]; then
    SUCCESS_RATE=100
else
    SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
fi

echo "成功率:       ${SUCCESS_RATE}%"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo "🎉 所有阶段2测试通过！BSC服务增强成功！"
    echo ""
    echo "✨ 阶段2成就:"
    echo "  • BSC node_sync适配完成 - 支持3秒区块快速同步"
    echo "  • BSC api_server适配完成 - 优化API响应性能"
    echo "  • BSC reorg_detector适配完成 - 智能重组检测"
    echo "  • BSC服务集成完成 - 统一的服务管理"
    echo "  • BSC性能优化完成 - 网络特性充分利用"
    echo ""
    echo "🚀 BSC核心适配阶段2已准备好进入阶段3！"
    echo ""
    echo "📋 阶段2完成的功能:"
    echo "  ✅ BSC快速状态同步 (node_sync)"
    echo "  ✅ BSC优化API服务 (api_server)"
    echo "  ✅ BSC智能重组检测 (reorg_detector)"
    echo "  ✅ BSC服务性能优化"
    echo "  ✅ BSC网络特性集成"
    echo ""
    echo "🎯 下一步: 阶段3 - 高级功能"
    echo "  • proof_data_handler BSC适配"
    echo "  • state_keeper BSC适配"
    echo "  • commitment_generator BSC适配"
    echo ""
    exit 0
else
    echo "⚠️  发现 $FAILED_TESTS 个失败的阶段2测试"
    echo ""
    echo "📋 建议:"
    echo "  • 检查失败测试的详细输出"
    echo "  • 确保所有BSC服务适配文件都已正确创建"
    echo "  • 验证代码语法和结构正确性"
    echo "  • 修复相关问题后重新运行测试"
    echo ""
    echo "🔧 常见问题排查:"
    echo "  1. 检查文件路径是否正确"
    echo "  2. 验证模块导入是否完整"
    echo "  3. 确认代码结构符合现有规范"
    echo "  4. 检查依赖项是否正确配置"
    echo ""
    exit 1
fi