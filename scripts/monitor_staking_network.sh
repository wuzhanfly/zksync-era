#!/bin/bash

# 监控质押网络状态

echo "🏦 监控 ZKsync Era 质押网络状态..."
echo "=================================="

# 检查验证者1 (权重: 1000)
echo ""
echo "📊 验证者1 (权重: 1000, 22.2%) - 端口 3050:"
if curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   http://localhost:3050 | grep -q "result"; then
    BLOCK_NUMBER_1=$(curl -s -X POST -H "Content-Type: application/json" \
       --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
       http://localhost:3050 | jq -r '.result')
    echo "✅ 正常运行 - 当前区块: $BLOCK_NUMBER_1"
else
    echo "❌ 无法连接"
fi

# 检查验证者2 (权重: 1500)
echo ""
echo "📊 验证者2 (权重: 1500, 33.3%) - 端口 3060:"
if curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   http://localhost:3060 | grep -q "result"; then
    BLOCK_NUMBER_2=$(curl -s -X POST -H "Content-Type: application/json" \
       --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
       http://localhost:3060 | jq -r '.result')
    echo "✅ 正常运行 - 当前区块: $BLOCK_NUMBER_2"
else
    echo "❌ 无法连接"
fi

# 检查验证者3 (权重: 2000)
echo ""
echo "📊 验证者3 (权重: 2000, 44.4%) - 端口 3070:"
if curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   http://localhost:3070 | grep -q "result"; then
    BLOCK_NUMBER_3=$(curl -s -X POST -H "Content-Type: application/json" \
       --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
       http://localhost:3070 | jq -r '.result')
    echo "✅ 正常运行 - 当前区块: $BLOCK_NUMBER_3"
else
    echo "❌ 无法连接"
fi

# 检查共识端口
echo ""
echo "🔗 共识网络端口状态:"
echo "==================="
echo "验证者1 (3054): $(netstat -tlnp 2>/dev/null | grep :3054 | wc -l) 个连接"
echo "验证者2 (3055): $(netstat -tlnp 2>/dev/null | grep :3055 | wc -l) 个连接"
echo "验证者3 (3056): $(netstat -tlnp 2>/dev/null | grep :3056 | wc -l) 个连接"

# 质押权重分析
echo ""
echo "🏦 质押权重分析:"
echo "================"
echo "验证者1: 1000 权重 (22.2%)"
echo "验证者2: 1500 权重 (33.3%)"
echo "验证者3: 2000 权重 (44.4%)"
echo "总权重: 4500"
echo "共识阈值: 3000 (66.7%)"
echo ""
echo "🔍 共识场景分析:"
echo "================"
echo "✅ 验证者2 + 验证者3 = 3500 权重 (77.8%) > 阈值"
echo "✅ 验证者1 + 验证者3 = 3000 权重 (66.7%) = 阈值"
echo "✅ 验证者1 + 验证者2 = 2500 权重 (55.6%) < 阈值"
echo "❌ 任何单个验证者都无法单独确认区块"

# 检查进程状态
echo ""
echo "⚙️ 验证者进程状态:"
echo "=================="
for i in {1..3}; do
    if [ -f "logs/staking_network/validator$i.pid" ]; then
        PID=$(cat logs/staking_network/validator$i.pid)
        if ps -p $PID > /dev/null; then
            echo "✅ 验证者$i 运行中 (PID: $PID)"
        else
            echo "❌ 验证者$i 已停止"
        fi
    else
        echo "❌ 验证者$i 未启动"
    fi
done

# 检查区块同步状态
echo ""
echo "🔄 区块同步状态:"
echo "================"
if [ -n "$BLOCK_NUMBER_1" ] && [ -n "$BLOCK_NUMBER_2" ] && [ -n "$BLOCK_NUMBER_3" ]; then
    if [ "$BLOCK_NUMBER_1" = "$BLOCK_NUMBER_2" ] && [ "$BLOCK_NUMBER_2" = "$BLOCK_NUMBER_3" ]; then
        echo "✅ 所有验证者区块高度同步: $BLOCK_NUMBER_1"
    else
        echo "⚠️  验证者区块高度不同步:"
        echo "   验证者1: $BLOCK_NUMBER_1"
        echo "   验证者2: $BLOCK_NUMBER_2"
        echo "   验证者3: $BLOCK_NUMBER_3"
    fi
fi

echo ""
echo "💡 有用的命令:"
echo "============="
echo "查看质押合约: cast call <REGISTRY_CONTRACT> 'getValidatorCommittee()'"
echo "发送测试交易: cast send --rpc-url http://localhost:3050 ..."
echo "查看验证者权重: cast call <REGISTRY_CONTRACT> 'validators(address)'"
echo "实时日志: tail -f logs/staking_network/validator1.log"