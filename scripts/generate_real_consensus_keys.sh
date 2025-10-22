#!/bin/bash

# 生成真实的共识密钥 (用于质押)

echo "🔐 生成真实的共识密钥用于质押..."

# 检查是否安装了必要的工具
if ! command -v openssl &> /dev/null; then
    echo "❌ 需要安装 openssl"
    exit 1
fi

# 创建密钥目录
mkdir -p staking_keys/{validator1,validator2,validator3}

echo "⚠️  重要提示:"
echo "============"
echo "这个脚本生成示例密钥用于测试。"
echo "生产环境请使用专业的密钥生成工具！"
echo ""

# 生成验证者1的密钥
echo "🔑 生成验证者1密钥..."
VALIDATOR1_SECRET=$(openssl rand -hex 32)
NODE1_SECRET=$(openssl rand -hex 32)

cat > staking_keys/validator1/secrets.yaml << EOF
# 验证者1 - 质押权重: 1000
validator_key: "validator:secret:bls12_381:${VALIDATOR1_SECRET}"
node_key: "node:secret:ed25519:${NODE1_SECRET}"
EOF

# 生成验证者2的密钥
echo "🔑 生成验证者2密钥..."
VALIDATOR2_SECRET=$(openssl rand -hex 32)
NODE2_SECRET=$(openssl rand -hex 32)

cat > staking_keys/validator2/secrets.yaml << EOF
# 验证者2 - 质押权重: 1500
validator_key: "validator:secret:bls12_381:${VALIDATOR2_SECRET}"
node_key: "node:secret:ed25519:${NODE2_SECRET}"
EOF

# 生成验证者3的密钥
echo "🔑 生成验证者3密钥..."
VALIDATOR3_SECRET=$(openssl rand -hex 32)
NODE3_SECRET=$(openssl rand -hex 32)

cat > staking_keys/validator3/secrets.yaml << EOF
# 验证者3 - 质押权重: 2000
validator_key: "validator:secret:bls12_381:${VALIDATOR3_SECRET}"
node_key: "node:secret:ed25519:${NODE3_SECRET}"
EOF

echo "✅ 密钥生成完成！"
echo ""
echo "📁 密钥文件位置:"
echo "================"
echo "验证者1: staking_keys/validator1/secrets.yaml"
echo "验证者2: staking_keys/validator2/secrets.yaml"
echo "验证者3: staking_keys/validator3/secrets.yaml"
echo ""
echo "🏦 质押权重分配:"
echo "================"
echo "验证者1: 1000 (22.2%)"
echo "验证者2: 1500 (33.3%)"
echo "验证者3: 2000 (44.4%)"
echo "总计:   4500 (100%)"
echo ""
echo "🚀 下一步:"
echo "========="
echo "1. 部署 ConsensusRegistry 合约"
echo "2. 注册验证者到合约"
echo "3. 启动多节点网络"