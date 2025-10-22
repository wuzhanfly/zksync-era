#!/bin/bash

# 自动监控并完成提币的脚本

echo "🔍 监控待完成的提币..."

# 检查是否有待完成的提币
# 这里需要根据你的具体实现来调整

echo "⚠️  注意: 这个脚本需要手动触发"
echo "24小时挑战期后，运行以下命令完成提币:"
echo ""
echo "zksync-cli bridge finalize-withdraw --hash <your_withdrawal_hash>"
echo ""
echo "或者使用我们的测试脚本:"
echo "bash scripts/test_withdraw_to_l1.sh"