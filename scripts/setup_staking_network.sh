#!/bin/bash

# 设置质押网络配置

echo "🏦 设置 ZKsync Era 质押网络..."

# 创建质押网络配置目录
mkdir -p staking_network/{validator1,validator2,validator3}

# 验证者1配置 (权重: 1000)
echo "📝 创建验证者1配置 (权重: 1000)..."
cat > staking_network/validator1/general.yaml << 'EOF'
# 验证者1 - 质押权重 1000
consensus:
  port: 3054
  server_addr: 127.0.0.1:3054
  public_addr: 127.0.0.1:3054
  max_payload_size: 2500000
  gossip_dynamic_inbound_limit: 100
  
  # 验证者注册合约地址 (需要部署后填入)
  registry_address: "0x0000000000000000000000000000000000000000"
  
  genesis_spec:
    chain_id: 9701
    protocol_version: 1
    # 使用注册合约管理验证者，这里留空
    validators: []
    # 种子节点配置
    seed_peers:
      "node:public:ed25519:VALIDATOR2_NODE_PUBLIC_KEY": "127.0.0.1:3055"
      "node:public:ed25519:VALIDATOR3_NODE_PUBLIC_KEY": "127.0.0.1:3056"

# API 配置
api:
  web3_json_rpc:
    http_port: 3050
    ws_port: 3051
  healthcheck:
    port: 3071
  merkle_tree:
    port: 3072

# 数据库配置
db:
  state_keeper_db_path: "./staking_network/validator1/db/state_keeper"
  merkle_tree:
    path: "./staking_network/validator1/db/tree"
EOF

# 验证者2配置 (权重: 1500)
echo "📝 创建验证者2配置 (权重: 1500)..."
cat > staking_network/validator2/general.yaml << 'EOF'
# 验证者2 - 质押权重 1500
consensus:
  port: 3055
  server_addr: 127.0.0.1:3055
  public_addr: 127.0.0.1:3055
  max_payload_size: 2500000
  gossip_dynamic_inbound_limit: 100
  
  # 验证者注册合约地址 (需要部署后填入)
  registry_address: "0x0000000000000000000000000000000000000000"
  
  genesis_spec:
    chain_id: 9701
    protocol_version: 1
    validators: []
    seed_peers:
      "node:public:ed25519:VALIDATOR1_NODE_PUBLIC_KEY": "127.0.0.1:3054"
      "node:public:ed25519:VALIDATOR3_NODE_PUBLIC_KEY": "127.0.0.1:3056"

# API 配置 (不同端口)
api:
  web3_json_rpc:
    http_port: 3060
    ws_port: 3061
  healthcheck:
    port: 3081
  merkle_tree:
    port: 3082

# 数据库配置
db:
  state_keeper_db_path: "./staking_network/validator2/db/state_keeper"
  merkle_tree:
    path: "./staking_network/validator2/db/tree"
EOF

# 验证者3配置 (权重: 2000)
echo "📝 创建验证者3配置 (权重: 2000)..."
cat > staking_network/validator3/general.yaml << 'EOF'
# 验证者3 - 质押权重 2000
consensus:
  port: 3056
  server_addr: 127.0.0.1:3056
  public_addr: 127.0.0.1:3056
  max_payload_size: 2500000
  gossip_dynamic_inbound_limit: 100
  
  # 验证者注册合约地址 (需要部署后填入)
  registry_address: "0x0000000000000000000000000000000000000000"
  
  genesis_spec:
    chain_id: 9701
    protocol_version: 1
    validators: []
    seed_peers:
      "node:public:ed25519:VALIDATOR1_NODE_PUBLIC_KEY": "127.0.0.1:3054"
      "node:public:ed25519:VALIDATOR2_NODE_PUBLIC_KEY": "127.0.0.1:3055"

# API 配置 (不同端口)
api:
  web3_json_rpc:
    http_port: 3070
    ws_port: 3071
  healthcheck:
    port: 3091
  merkle_tree:
    port: 3092

# 数据库配置
db:
  state_keeper_db_path: "./staking_network/validator3/db/state_keeper"
  merkle_tree:
    path: "./staking_network/validator3/db/tree"
EOF

# 创建验证者注册脚本
echo "📝 创建验证者注册脚本..."
cat > scripts/register_validators.sh << 'EOF'
#!/bin/bash

# 注册验证者到 ConsensusRegistry 合约

echo "🏦 注册验证者到质押合约..."

# 合约地址 (需要先部署 ConsensusRegistry 合约)
REGISTRY_CONTRACT="0x0000000000000000000000000000000000000000"

# 验证者信息 (需要从实际密钥文件中获取公钥)
VALIDATOR1_OWNER="0x1234567890123456789012345678901234567890"
VALIDATOR1_PUBKEY="validator:public:bls12_381:..."
VALIDATOR1_WEIGHT=1000

VALIDATOR2_OWNER="0x2345678901234567890123456789012345678901"
VALIDATOR2_PUBKEY="validator:public:bls12_381:..."
VALIDATOR2_WEIGHT=1500

VALIDATOR3_OWNER="0x3456789012345678901234567890123456789012"
VALIDATOR3_PUBKEY="validator:public:bls12_381:..."
VALIDATOR3_WEIGHT=2000

echo "注册验证者1 (权重: $VALIDATOR1_WEIGHT)..."
cast send $REGISTRY_CONTRACT \
  "add(address,bool,uint32,(bytes32,bytes32,bytes32),(bytes32,bytes16))" \
  $VALIDATOR1_OWNER true $VALIDATOR1_WEIGHT \
  "($VALIDATOR1_PUBKEY)" \
  "(proof_of_possession)" \
  --rpc-url http://localhost:3050 \
  --private-key $PRIVATE_KEY

echo "注册验证者2 (权重: $VALIDATOR2_WEIGHT)..."
cast send $REGISTRY_CONTRACT \
  "add(address,bool,uint32,(bytes32,bytes32,bytes32),(bytes32,bytes16))" \
  $VALIDATOR2_OWNER true $VALIDATOR2_WEIGHT \
  "($VALIDATOR2_PUBKEY)" \
  "(proof_of_possession)" \
  --rpc-url http://localhost:3050 \
  --private-key $PRIVATE_KEY

echo "注册验证者3 (权重: $VALIDATOR3_WEIGHT)..."
cast send $REGISTRY_CONTRACT \
  "add(address,bool,uint32,(bytes32,bytes32,bytes32),(bytes32,bytes16))" \
  $VALIDATOR3_OWNER true $VALIDATOR3_WEIGHT \
  "($VALIDATOR3_PUBKEY)" \
  "(proof_of_possession)" \
  --rpc-url http://localhost:3050 \
  --private-key $PRIVATE_KEY

echo "提交验证者委员会..."
cast send $REGISTRY_CONTRACT \
  "commitValidatorCommittee()" \
  --rpc-url http://localhost:3050 \
  --private-key $PRIVATE_KEY

echo "✅ 验证者注册完成！"
EOF

chmod +x scripts/register_validators.sh

echo "✅ 质押网络配置创建完成！"
echo ""
echo "📋 质押网络信息:"
echo "================"
echo "验证者1: 权重 1000 (22.2%), 端口 3054, RPC 3050"
echo "验证者2: 权重 1500 (33.3%), 端口 3055, RPC 3060"  
echo "验证者3: 权重 2000 (44.4%), 端口 3056, RPC 3070"
echo "总权重: 4500"
echo ""
echo "🚀 部署步骤:"
echo "==========="
echo "1. 生成密钥: bash scripts/generate_real_consensus_keys.sh"
echo "2. 部署 ConsensusRegistry 合约"
echo "3. 更新配置中的合约地址"
echo "4. 注册验证者: bash scripts/register_validators.sh"
echo "5. 启动质押网络"
echo ""
echo "💡 质押机制:"
echo "==========="
echo "- 验证者权重决定投票权重"
echo "- 需要 2/3+ 权重同意才能确认区块"
echo "- 领导者轮换基于权重分配"
echo "- 可以动态添加/移除验证者"