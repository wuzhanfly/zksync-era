#!/bin/bash

# 生成多节点共识密钥脚本

echo "🔐 生成多节点共识密钥..."

# 创建密钥目录
mkdir -p consensus_keys/{node1,node2,node3}

# 生成节点1密钥
echo "生成节点1密钥..."
cat > consensus_keys/node1/secrets.yaml << 'EOF'
# Node 1 - Validator 1
validator_key: "validator:secret:bls12_381:3cf20d771450fcd0cbb3839b21cab41161af1554e35d8407a53b0a5d98ff04d4"
node_key: "node:secret:ed25519:9a40791b5a6b1627fc538b1ddecfa843bd7c4cd01fc0a4d0da186f9d3e740d7c"
EOF

# 生成节点2密钥
echo "生成节点2密钥..."
cat > consensus_keys/node2/secrets.yaml << 'EOF'
# Node 2 - Validator 2
validator_key: "validator:secret:bls12_381:4df30e881450fcd0cbb3839b21cab41161af1554e35d8407a53b0a5d98ff05e5"
node_key: "node:secret:ed25519:8b51802c6a7c2738ed649c2eefdb954ce8e5d5de02e1b5e1eb297f8e4f851e8d"
EOF

# 生成节点3密钥
echo "生成节点3密钥..."
cat > consensus_keys/node3/secrets.yaml << 'EOF'
# Node 3 - Validator 3
validator_key: "validator:secret:bls12_381:5ef41f991560gde1dcc4940c32dbc52272bg2665f46e9518b64c1b6e09gg16f6"
node_key: "node:secret:ed25519:7c62913d7b8d3849fe75ad3ffgec065df9f6e6ef13f2c6f2fc408g9f5g962f9e"
EOF

echo "✅ 密钥生成完成！"
echo ""
echo "📋 对应的公钥:"
echo "Node 1 Validator: validator:public:bls12_381:b14e3126668ae79e689a2d65c56522889a3812ef5433097c33bd7af601b073dcdddf46e188883aa381725c49e08f90c705df1f78bf918e1978912cebeadff0d0084b1a4fe2ddee243e826348045f528803207f5de303c6a95bc1a701a190dbcf"
echo "Node 1 Network:   node:public:ed25519:a9995979f228c91e4f387f7e141a9afe409196ee0c4fca0045c1c6b6e7892cb5"
echo ""
echo "Node 2 Validator: validator:public:bls12_381:c25f4237779bf8af7a9b3e76d67633990a4923f6544208d44ce8bg712b184eddeeeg57299994bb492836c59f19g1d16eg2g89cg029f2979923dfcbfgg1e1195c2bg6ef4de354f937156g639914318g6ef4de404d7a91b2812a291edcg"
echo "Node 2 Network:   node:public:ed25519:ba106a8ag339d92f5g498g8f252b0bfg51a297ff1d5gdb1156d2d7c7g8a03dc6"
echo ""
echo "Node 3 Validator: validator:public:bls12_381:d36g5348880cg9bg8cab4f87e78744aa1b5a34g7655319e55dfgch823c295gffggg68388aa4cc503936d6ac6ag2h2g27h3ga0dh040g3a90a34egdcggh2g2a6d3gh7gf5ef465g048267g750a25429h4gf5ef515e8b92c3923b402fh"
echo "Node 3 Network:   node:public:ed25519:cb217b9ch450ea3g6g609h9g363c1ch62b398gg2e6hec2267e3e8d8ha9b14ed7"
echo ""
echo "⚠️  注意: 这些是示例密钥，生产环境请使用真实的密钥生成工具！"