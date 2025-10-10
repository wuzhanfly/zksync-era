#!/bin/bash

# 检查挑战期配置

echo "🔍 检查挑战期配置..."
echo "====================="

echo ""
echo "📋 当前配置文件设置:"
echo "===================="
grep "validator_timelock_execution_delay" configs/initial_deployments.yaml

DELAY=$(grep "validator_timelock_execution_delay" configs/initial_deployments.yaml | awk '{print $2}')

echo ""
echo "⏰ 挑战期时间解析:"
echo "=================="
echo "配置值: $DELAY 秒"

if [ "$DELAY" -eq 0 ]; then
    echo "挑战期: 立即执行 (测试模式)"
elif [ "$DELAY" -eq 300 ]; then
    echo "挑战期: 5 分钟"
elif [ "$DELAY" -eq 3600 ]; then
    echo "挑战期: 1 小时"
elif [ "$DELAY" -eq 86400 ]; then
    echo "挑战期: 24 小时 (标准)"
elif [ "$DELAY" -eq 604800 ]; then
    echo "挑战期: 7 天"
else
    echo "挑战期: $DELAY 秒 ($(($DELAY / 60)) 分钟)"
fi

echo ""
echo "💡 提示:"
echo "======="
echo "- 修改后需要重新部署 L1 合约才能生效"
echo "- 测试环境建议使用较短的挑战期"
echo "- 生产环境建议使用 24 小时或更长"