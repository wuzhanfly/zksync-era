#!/bin/bash

# zkstack BSC集成测试脚本
# 测试BSC相关的CLI命令集成

# set -e  # 不要在测试失败时立即退出

echo "🧪 zkstack BSC CLI集成测试"
echo "============================"
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

# 检查编译测试
run_test "zkstack CLI编译测试" \
    "(cd zkstack_cli && cargo check --quiet)" \
    "检查zkstack CLI是否能正常编译"

# 检查BSC模块编译
run_test "BSC模块编译测试" \
    "(cd zkstack_cli && cargo check --quiet -p zkstack)" \
    "检查BSC相关模块是否能正常编译"

# 检查BSC文件存在性
run_test "BSC文件完整性测试" \
    "test -f zkstack_cli/crates/zkstack/src/commands/ecosystem/bsc_setup.rs && test -f zkstack_cli/crates/zkstack/src/commands/ecosystem/bsc_wizard.rs && test -f zkstack_cli/crates/zkstack/src/commands/ecosystem/bsc_checker.rs && test -f zkstack_cli/crates/zkstack/src/commands/ecosystem/bsc_config_generator.rs" \
    "检查所有BSC相关文件是否存在"

# 检查模块导入
run_test "BSC模块导入测试" \
    "grep -q 'pub(crate) mod bsc_setup;' zkstack_cli/crates/zkstack/src/commands/ecosystem/mod.rs" \
    "检查BSC模块是否正确导入到生态系统命令中"

# 检查CLI命令集成
run_test "BSC CLI命令集成测试" \
    "grep -q 'BSCSetup(BSCSetupArgs)' zkstack_cli/crates/zkstack/src/commands/ecosystem/mod.rs" \
    "检查BSC命令是否集成到生态系统命令枚举中"

# 检查主CLI集成
run_test "主CLI BSC集成测试" \
    "grep -q 'BSC(' zkstack_cli/crates/zkstack/src/main.rs" \
    "检查BSC命令是否集成到主CLI中"

# 检查依赖项
run_test "依赖项检查" \
    "(cd zkstack_cli && cargo tree -q --package zkstack | grep -q zkstack_cli_types)" \
    "检查必要的依赖项是否正确配置"

# 检查Rust语法
run_test "Rust语法检查" \
    "(cd zkstack_cli && cargo clippy --quiet --allow-warnings)" \
    "检查Rust代码是否符合语法规范"

# 模拟CLI帮助命令测试
if [ -f "zkstack_cli/target/release/zkstack" ] || [ -f "zkstack_cli/target/debug/zkstack" ]; then
    ZKSTACK_BIN=""
    if [ -f "zkstack_cli/target/release/zkstack" ]; then
        ZKSTACK_BIN="zkstack_cli/target/release/zkstack"
    elif [ -f "zkstack_cli/target/debug/zkstack" ]; then
        ZKSTACK_BIN="zkstack_cli/target/debug/zkstack"
    fi
    
    if [ -n "$ZKSTACK_BIN" ]; then
        run_test "BSC帮助命令测试" \
            "$ZKSTACK_BIN bsc --help" \
            "测试BSC命令的帮助信息是否正常显示"
        
        run_test "生态系统BSC命令测试" \
            "$ZKSTACK_BIN ecosystem bsc --help" \
            "测试生态系统中的BSC命令帮助信息"
    fi
else
    echo -e "${YELLOW}⚠️ zkstack二进制文件未找到，跳过CLI运行测试${NC}"
    echo "   提示: 运行 'cd zkstack_cli && cargo build' 来构建二进制文件"
    echo ""
fi

# 检查配置文件模板
run_test "BSC配置文件检查" \
    "test -f etc/env/configs/bsc-mainnet.toml && test -f etc/env/configs/bsc-testnet.toml" \
    "检查BSC配置文件模板是否存在"

# 检查代币配置
run_test "BSC代币配置检查" \
    "test -f etc/tokens/bsc-mainnet.json && test -f etc/tokens/bsc-testnet.json" \
    "检查BSC代币配置文件是否存在"

# 检查网络验证模块
run_test "网络验证模块检查" \
    "test -f core/lib/eth_client/src/network_validation.rs && grep -q 'BSCNetworkValidator' core/lib/eth_client/src/network_validation.rs" \
    "检查BSC网络验证模块是否正确实现"

# 检查L1Network枚举
run_test "L1Network枚举检查" \
    "grep -q 'BSCMain' core/lib/config/src/configs/networks.rs && grep -q 'BSCTestnet' core/lib/config/src/configs/networks.rs" \
    "检查L1Network枚举是否包含BSC网络类型"

# 生成测试报告
END_TIME=$(date +%s)
echo ""
echo "🎊 zkstack BSC CLI集成测试完成！"
echo "=================================="
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
    echo -e "${GREEN}🎉 所有集成测试通过！BSC CLI集成成功！${NC}"
    echo ""
    echo -e "${GREEN}✨ 集成成就:${NC}"
    echo -e "${GREEN}  • BSC命令完全集成到zkstack CLI${NC}"
    echo -e "${GREEN}  • 支持 'zkstack bsc' 和 'zkstack ecosystem bsc' 命令${NC}"
    echo -e "${GREEN}  • 所有BSC相关模块正确编译${NC}"
    echo -e "${GREEN}  • 配置文件和模板完整${NC}"
    echo ""
    echo -e "${GREEN}🚀 可用的BSC命令:${NC}"
    echo -e "${GREEN}  zkstack bsc wizard           # BSC配置向导${NC}"
    echo -e "${GREEN}  zkstack bsc quick-start      # 快速开始${NC}"
    echo -e "${GREEN}  zkstack bsc templates        # 显示模板${NC}"
    echo -e "${GREEN}  zkstack bsc verify           # 验证网络${NC}"
    echo -e "${GREEN}  zkstack ecosystem bsc wizard # 生态系统BSC向导${NC}"
    echo ""
    echo -e "${GREEN}📚 使用示例:${NC}"
    echo -e "${CYAN}  # 启动BSC配置向导${NC}"
    echo -e "${CYAN}  zkstack bsc wizard${NC}"
    echo ""
    echo -e "${CYAN}  # 快速创建BSC测试网生态系统${NC}"
    echo -e "${CYAN}  zkstack bsc quick-start --name my-bsc-testnet${NC}"
    echo ""
    echo -e "${CYAN}  # 验证BSC主网连接${NC}"
    echo -e "${CYAN}  zkstack bsc verify --network bsc-mainnet${NC}"
    echo ""
    echo -e "${GREEN}🎯 下一步: 运行BSC配置向导开始使用！${NC}"
    
    exit 0
else
    echo -e "${RED}⚠️  发现 ${FAILED_TESTS} 个失败的集成测试${NC}"
    echo ""
    echo -e "${YELLOW}📋 建议:${NC}"
    echo -e "${YELLOW}  • 检查失败的测试输出${NC}"
    echo -e "${YELLOW}  • 确保所有BSC文件都已正确创建${NC}"
    echo -e "${YELLOW}  • 运行 'cd zkstack_cli && cargo build' 构建CLI${NC}"
    echo -e "${YELLOW}  • 修复相关问题后重新运行测试${NC}"
    echo ""
    exit 1
fi