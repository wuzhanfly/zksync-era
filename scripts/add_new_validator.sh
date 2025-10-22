#!/bin/bash

# 添加新验证者到质押网络

echo "🏦 添加新验证者到 ZKsync Era 质押网络..."

# 参数检查
if [ $# -lt 3 ]; then
    echo "用法: $0 <验证者名称> <质押权重> <节点端口>"
    echo "示例: $0 validator4 1200 3057"
    exit 1
fi

VALIDATOR_NAME=$1
STAKE_WEIGHT=$2
NODE_PORT=$3
RPC_PORT=$((NODE_PORT + 1000))  # RPC端口 = 共识端口 + 1000
HEALTH_PORT=$((NODE_PORT + 2000))  # 健康检查端口 = 共识端口 + 2000

echo "📋 新验证者信息:"
echo "================"
echo "验证者名称: $VALIDATOR_NAME"
echo "质押权重: $STAKE_WEIGHT"
echo "共识端口: $NODE_PORT"
echo "RPC端口: $RPC_PORT"
echo "健康检查端口: $HEALTH_PORT"

# 创建验证者目录
mkdir -p staking_keys/$VALIDATOR_NAME
mkdir -p staking_network/$VALIDATOR_NAME

echo ""
echo "🔐 生成验证者密钥..."

# 生成新的验证者密钥
VALIDATOR_SECRET=$(openssl rand -hex 32)
NODE_SECRET=$(openssl rand -hex 32)

cat > staking_keys/$VALIDATOR_NAME/secrets.yaml << EOF
# $VALIDATOR_NAME - 质押权重: $STAKE_WEIGHT
validator_key: "validator:secret:bls12_381:${VALIDATOR_SECRET}"
node_key: "node:secret:ed25519:${NODE_SECRET}"
EOF

echo "✅ 密钥生成完成: staking_keys/$VALIDATOR_NAME/secrets.yaml"

echo ""
echo "📝 创建节点配置..."

# 创建节点配置文件
cat > staking_network/$VALIDATOR_NAME/general.yaml << EOF
# $VALIDATOR_NAME - 质押权重 $STAKE_WEIGHT
consensus:
  port: $NODE_PORT
  server_addr: 127.0.0.1:$NODE_PORT
  public_addr: 127.0.0.1:$NODE_PORT
  max_payload_size: 2500000
  gossip_dynamic_inbound_limit: 100
  
  # 验证者注册合约地址 (需要填入实际地址)
  registry_address: "0x0000000000000000000000000000000000000000"
  
  genesis_spec:
    chain_id: 9701
    protocol_version: 1
    validators: []
    # 连接到现有验证者
    seed_peers:
      "node:public:ed25519:EXISTING_VALIDATOR1_KEY": "127.0.0.1:3054"
      "node:public:ed25519:EXISTING_VALIDATOR2_KEY": "127.0.0.1:3055"
      "node:public:ed25519:EXISTING_VALIDATOR3_KEY": "127.0.0.1:3056"

# API 配置
api:
  web3_json_rpc:
    http_port: $RPC_PORT
    ws_port: $((RPC_PORT + 1))
  healthcheck:
    port: $HEALTH_PORT
  merkle_tree:
    port: $((HEALTH_PORT + 1))

# 数据库配置
db:
  state_keeper_db_path: "./staking_network/$VALIDATOR_NAME/db/state_keeper"
  merkle_tree:
    path: "./staking_network/$VALIDATOR_NAME/db/tree"
EOF

echo "✅ 配置文件创建完成: staking_network/$VALIDATOR_NAME/general.yaml"

echo ""
echo "📜 创建注册脚本..."

# 创建验证者注册脚本
cat > scripts/register_$VALIDATOR_NAME.sh << EOF
#!/bin/bash

# 注册 $VALIDATOR_NAME 到质押合约

echo "🏦 注册 $VALIDATOR_NAME 到 ConsensusRegistry 合约..."

# 合约配置
REGISTRY_CONTRACT="\${REGISTRY_CONTRACT:-0x0000000000000000000000000000000000000000}"
OWNER_ADDRESS="\${OWNER_ADDRESS:-0x1234567890123456789012345678901234567890}"
PRIVATE_KEY="\${PRIVATE_KEY:-your_private_key_here}"

# 验证者信息 (需要从实际密钥获取公钥)
VALIDATOR_PUBKEY="validator:public:bls12_381:..."  # 需要从密钥文件计算
VALIDATOR_WEIGHT=$STAKE_WEIGHT

echo "验证者信息:"
echo "=========="
echo "名称: $VALIDATOR_NAME"
echo "权重: \$VALIDATOR_WEIGHT"
echo "所有者: \$OWNER_ADDRESS"
echo "合约: \$REGISTRY_CONTRACT"

# 检查合约地址
if [ "\$REGISTRY_CONTRACT" = "0x0000000000000000000000000000000000000000" ]; then
    echo "❌ 请设置 REGISTRY_CONTRACT 环境变量"
    echo "export REGISTRY_CONTRACT=<实际合约地址>"
    exit 1
fi

# 检查私钥
if [ "\$PRIVATE_KEY" = "your_private_key_here" ]; then
    echo "❌ 请设置 PRIVATE_KEY 环境变量"
    echo "export PRIVATE_KEY=<你的私钥>"
    exit 1
fi

echo ""
echo "🔐 注册验证者到合约..."

# 注册验证者 (需要实际的公钥和所有权证明)
cast send \$REGISTRY_CONTRACT \\
  "add(address,bool,uint32,(bytes32,bytes32,bytes32),(bytes32,bytes16))" \\
  \$OWNER_ADDRESS \\
  true \\
  \$VALIDATOR_WEIGHT \\
  "(\$VALIDATOR_PUBKEY)" \\
  "(proof_of_possession)" \\
  --rpc-url http://localhost:3050 \\
  --private-key \$PRIVATE_KEY

if [ \$? -eq 0 ]; then
    echo "✅ $VALIDATOR_NAME 注册成功！"
    echo ""
    echo "📋 下一步:"
    echo "========="
    echo "1. 等待管理员调用 commitValidatorCommittee()"
    echo "2. 启动验证者节点: bash scripts/start_$VALIDATOR_NAME.sh"
    echo "3. 监控节点状态"
else
    echo "❌ 注册失败，请检查参数和网络连接"
fi
EOF

chmod +x scripts/register_$VALIDATOR_NAME.sh

echo ""
echo "🚀 创建启动脚本..."

# 创建验证者启动脚本
cat > scripts/start_$VALIDATOR_NAME.sh << EOF
#!/bin/bash

# 启动 $VALIDATOR_NAME 验证者节点

echo "🚀 启动 $VALIDATOR_NAME 验证者节点..."

# 检查配置文件
if [ ! -f "staking_network/$VALIDATOR_NAME/general.yaml" ]; then
    echo "❌ 配置文件不存在"
    exit 1
fi

if [ ! -f "staking_keys/$VALIDATOR_NAME/secrets.yaml" ]; then
    echo "❌ 密钥文件不存在"
    exit 1
fi

# 创建日志目录
mkdir -p logs/staking_network

echo "启动 $VALIDATOR_NAME (权重: $STAKE_WEIGHT)..."

# 启动节点
./zkstack_cli/target/release/zkstack server \\
  --config-path staking_network/$VALIDATOR_NAME/general.yaml \\
  --secrets-path staking_keys/$VALIDATOR_NAME/secrets.yaml \\
  --chain era > logs/staking_network/$VALIDATOR_NAME.log 2>&1 &

VALIDATOR_PID=\$!
echo "\$VALIDATOR_PID" > logs/staking_network/$VALIDATOR_NAME.pid

echo "✅ $VALIDATOR_NAME 启动完成！"
echo ""
echo "📊 节点信息:"
echo "============"
echo "PID: \$VALIDATOR_PID"
echo "共识端口: $NODE_PORT"
echo "RPC端口: $RPC_PORT"
echo "权重: $STAKE_WEIGHT"
echo "日志: logs/staking_network/$VALIDATOR_NAME.log"
echo ""
echo "🔍 监控命令:"
echo "============"
echo "查看日志: tail -f logs/staking_network/$VALIDATOR_NAME.log"
echo "检查RPC: curl -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' http://localhost:$RPC_PORT"
echo "停止节点: kill \$VALIDATOR_PID"
EOF

chmod +x scripts/start_$VALIDATOR_NAME.sh

echo ""
echo "✅ $VALIDATOR_NAME 验证者设置完成！"
echo ""
echo "📋 文件创建列表:"
echo "================"
echo "✅ 密钥文件: staking_keys/$VALIDATOR_NAME/secrets.yaml"
echo "✅ 配置文件: staking_network/$VALIDATOR_NAME/general.yaml"
echo "✅ 注册脚本: scripts/register_$VALIDATOR_NAME.sh"
echo "✅ 启动脚本: scripts/start_$VALIDATOR_NAME.sh"
echo ""
echo "🚀 质押流程:"
echo "==========="
echo "1. 设置环境变量:"
echo "   export REGISTRY_CONTRACT=<合约地址>"
echo "   export OWNER_ADDRESS=<你的地址>"
echo "   export PRIVATE_KEY=<你的私钥>"
echo ""
echo "2. 注册验证者:"
echo "   bash scripts/register_$VALIDATOR_NAME.sh"
echo ""
echo "3. 等待管理员确认验证者委员会"
echo ""
echo "4. 启动验证者节点:"
echo "   bash scripts/start_$VALIDATOR_NAME.sh"
echo ""
echo "💡 注意事项:"
echo "==========="
echo "- 需要先部署 ConsensusRegistry 合约"
echo "- 需要从密钥文件计算实际的公钥"
echo "- 需要生成所有权证明 (Proof of Possession)"
echo "- 管理员需要调用 commitValidatorCommittee() 激活新验证者"