#!/bin/bash

# BSC CLI功能演示脚本
# 展示zkstack BSC集成的各种功能

echo "🚀 zkstack BSC CLI功能演示"
echo "=========================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

ZKSTACK_BIN="zkstack_cli/target/release/zkstack"

if [ ! -f "$ZKSTACK_BIN" ]; then
    echo "❌ zkstack二进制文件未找到"
    echo "请先运行: cd zkstack_cli && cargo build --release"
    exit 1
fi

echo -e "${BLUE}📋 1. 显示BSC主命令帮助${NC}"
echo "命令: zkstack bsc --help"
echo ""
$ZKSTACK_BIN bsc --help
echo ""
echo "----------------------------------------"
echo ""

echo -e "${BLUE}📋 2. 显示BSC配置模板${NC}"
echo "命令: zkstack bsc templates"
echo ""
$ZKSTACK_BIN bsc templates
echo ""
echo "----------------------------------------"
echo ""

echo -e "${BLUE}📋 3. 显示生态系统BSC命令帮助${NC}"
echo "命令: zkstack ecosystem bsc --help"
echo ""
$ZKSTACK_BIN ecosystem bsc --help
echo ""
echo "----------------------------------------"
echo ""

echo -e "${BLUE}📋 4. 显示快速启动帮助${NC}"
echo "命令: zkstack bsc quick-start --help"
echo ""
$ZKSTACK_BIN bsc quick-start --help
echo ""
echo "----------------------------------------"
echo ""

echo -e "${BLUE}📋 5. 显示网络验证帮助${NC}"
echo "命令: zkstack bsc verify --help"
echo ""
$ZKSTACK_BIN bsc verify --help
echo ""
echo "----------------------------------------"
echo ""

echo -e "${GREEN}🎉 BSC CLI功能演示完成！${NC}"
echo ""
echo -e "${CYAN}💡 可用的BSC命令:${NC}"
echo -e "${YELLOW}  zkstack bsc wizard           # 启动BSC配置向导${NC}"
echo -e "${YELLOW}  zkstack bsc quick-start      # 快速创建BSC生态系统${NC}"
echo -e "${YELLOW}  zkstack bsc templates        # 显示配置模板${NC}"
echo -e "${YELLOW}  zkstack bsc verify           # 验证BSC网络连接${NC}"
echo -e "${YELLOW}  zkstack ecosystem bsc wizard # 生态系统BSC向导${NC}"
echo ""
echo -e "${CYAN}🚀 开始使用:${NC}"
echo -e "${GREEN}  zkstack bsc wizard           # 交互式配置向导${NC}"
echo -e "${GREEN}  zkstack bsc quick-start --name my-bsc-project${NC}"
echo ""
echo -e "${CYAN}💰 BSC优势:${NC}"
echo -e "${GREEN}  • 交易费用降低 95%+ (相比以太坊)${NC}"
echo -e "${GREEN}  • 交易确认提升 4倍 (3秒 vs 12秒)${NC}"
echo -e "${GREEN}  • 更高的网络吞吐量和稳定性${NC}"
echo ""