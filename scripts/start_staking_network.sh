#!/bin/bash

# 启动质押网络

echo "🏦 启动 ZKsync Era 质押网络..."

# 检查配置
if [ ! -d "staking_network" ]; then
    echo "❌ 质押网络配置不存在，请先运行: bash scripts/setup_staking_network.sh"
    exit 1
fi

if [ ! -d "staking_keys" ]; then
    echo "❌ 质押密钥不存在，请先运行: bash scripts/generate_real_consensus_keys.sh"
    exit 1
fi

# 创建日志目录
mkdir -p logs/staking_network

echo "🔧 启动质押验证者节点..."

# 启动验证者1 (权重: 1000)
echo "启动验证者1 (权重: 1000)..."
./zkstack_cli/target/release/zkstack server \
  --config-path staking_network/validator1/general.yaml \
  --secrets-path staking_keys/validator1/secrets.yaml \
  --chain era > logs/staking_network/validator1.log 2>&1 &

VALIDATOR1_PID=$!
echo "验证者1 PID: $VALIDATOR1_PID"

# 等待启动
sleep 15

# 启动验证者2 (权重: 1500)
echo "启动验证者2 (权重: 1500)..."
./zkstack_cli/target/release/zkstack server \
  --config-path staking_network/validator2/general.yaml \
  --secrets-path staking_keys/validator2/secrets.yaml \
  --chain era > logs/staking_network/validator2.log 2>&1 &

VALIDATOR2_PID=$!
echo "验证者2 PID: $VALIDATOR2_PID"

# 等待启动
sleep 15

# 启动验证者3 (权重: 2000)
echo "启动验证者3 (权重: 2000)..."
./zkstack_cli/target/release/zkstack server \
  --config-path staking_network/validator3/general.yaml \
  --secrets-path staking_keys/validator3/secrets.yaml \
  --chain era > logs/staking_network/validator3.log 2>&1 &

VALIDATOR3_PID=$!
echo "验证者3 PID: $VALIDATOR3_PID"

# 保存PID
echo "$VALIDATOR1_PID" > logs/staking_network/validator1.pid
echo "$VALIDATOR2_PID" > logs/staking_network/validator2.pid
echo "$VALIDATOR3_PID" > logs/staking_network/validator3.pid

echo ""
echo "✅ 质押网络启动完成！"
echo ""
echo "🏦 质押验证者状态:"
echo "=================="
echo "验证者1: PID $VALIDATOR1_PID, 权重 1000 (22.2%)"
echo "验证者2: PID $VALIDATOR2_PID, 权重 1500 (33.3%)"
echo "验证者3: PID $VALIDATOR3_PID, 权重 2000 (44.4%)"
echo ""
echo "🌐 RPC 接口:"
echo "============"
echo "验证者1: http://localhost:3050"
echo "验证者2: http://localhost:3060"
echo "验证者3: http://localhost:3070"
echo ""
echo "📊 共识信息:"
echo "==========="
echo "总质押权重: 4500"
echo "共识阈值: 3000 (2/3+ 权重)"
echo "验证者3单独权重: 2000 (44.4%)"
echo "需要至少2个验证者同意才能确认区块"
echo ""
echo "🔍 监控命令:"
echo "============"
echo "查看验证者1: tail -f logs/staking_network/validator1.log"
echo "查看验证者2: tail -f logs/staking_network/validator2.log"
echo "查看验证者3: tail -f logs/staking_network/validator3.log"
echo "监控网络: bash scripts/monitor_staking_network.sh"
echo ""
echo "停止网络: bash scripts/stop_staking_network.sh"