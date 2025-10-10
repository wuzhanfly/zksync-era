#!/bin/bash

# 多节点 ZKsync Era 部署脚本

echo "🚀 设置多节点 ZKsync Era 网络..."

# 创建多节点配置目录
mkdir -p multi_node/{node1,node2,node3}

# 节点1配置 (主节点 + 验证者)
echo "📝 创建节点1配置..."
cat > multi_node/node1/general.yaml << 'EOF'
# 节点1 - 主节点配置
consensus:
  port: 3054
  server_addr: 127.0.0.1:3054
  public_addr: 127.0.0.1:3054
  max_payload_size: 2500000
  gossip_dynamic_inbound_limit: 100
  gossip_static_outbound:
    # 连接到其他节点
    "node:public:ed25519:ba106a8ag339d92f5g498g8f252b0bfg51a297ff1d5gdb1156d2d7c7g8a03dc6": "127.0.0.1:3055"
    "node:public:ed25519:cb217b9ch450ea3g6g609h9g363c1ch62b398gg2e6hec2267e3e8d8ha9b14ed7": "127.0.0.1:3056"
  
  genesis_spec:
    chain_id: 9701
    protocol_version: 1
    validators:
    - key: validator:public:bls12_381:b14e3126668ae79e689a2d65c56522889a3812ef5433097c33bd7af601b073dcdddf46e188883aa381725c49e08f90c705df1f78bf918e1978912cebeadff0d0084b1a4fe2ddee243e826348045f528803207f5de303c6a95bc1a701a190dbcf
      weight: 1
    - key: validator:public:bls12_381:c25f4237779bf8af7a9b3e76d67633990a4923f6544208d44ce8bg712b184eddeeeg57299994bb492836c59f19g1d16eg2g89cg029f2979923dfcbfgg1e1195c2bg6ef4de354f937156g639914318g6ef4de404d7a91b2812a291edcg
      weight: 1
    - key: validator:public:bls12_381:d36g5348880cg9bg8cab4f87e78744aa1b5a34g7655319e55dfgch823c295gffggg68388aa4cc503936d6ac6ag2h2g27h3ga0dh040g3a90a34egdcggh2g2a6d3gh7gf5ef465g048267g750a25429h4gf5ef515e8b92c3923b402fh
      weight: 1
    leader: validator:public:bls12_381:b14e3126668ae79e689a2d65c56522889a3812ef5433097c33bd7af601b073dcdddf46e188883aa381725c49e08f90c705df1f78bf918e1978912cebeadff0d0084b1a4fe2ddee243e826348045f528803207f5de303c6a95bc1a701a190dbcf

# API 配置
api:
  web3_json_rpc:
    http_port: 3050
    ws_port: 3051
  healthcheck:
    port: 3071
  merkle_tree:
    port: 3072
EOF

# 节点2配置 (验证者)
echo "📝 创建节点2配置..."
cat > multi_node/node2/general.yaml << 'EOF'
# 节点2 - 验证者配置
consensus:
  port: 3055
  server_addr: 127.0.0.1:3055
  public_addr: 127.0.0.1:3055
  max_payload_size: 2500000
  gossip_dynamic_inbound_limit: 100
  gossip_static_outbound:
    # 连接到其他节点
    "node:public:ed25519:a9995979f228c91e4f387f7e141a9afe409196ee0c4fca0045c1c6b6e7892cb5": "127.0.0.1:3054"
    "node:public:ed25519:cb217b9ch450ea3g6g609h9g363c1ch62b398gg2e6hec2267e3e8d8ha9b14ed7": "127.0.0.1:3056"
  
  genesis_spec:
    chain_id: 9701
    protocol_version: 1
    validators:
    - key: validator:public:bls12_381:b14e3126668ae79e689a2d65c56522889a3812ef5433097c33bd7af601b073dcdddf46e188883aa381725c49e08f90c705df1f78bf918e1978912cebeadff0d0084b1a4fe2ddee243e826348045f528803207f5de303c6a95bc1a701a190dbcf
      weight: 1
    - key: validator:public:bls12_381:c25f4237779bf8af7a9b3e76d67633990a4923f6544208d44ce8bg712b184eddeeeg57299994bb492836c59f19g1d16eg2g89cg029f2979923dfcbfgg1e1195c2bg6ef4de354f937156g639914318g6ef4de404d7a91b2812a291edcg
      weight: 1
    - key: validator:public:bls12_381:d36g5348880cg9bg8cab4f87e78744aa1b5a34g7655319e55dfgch823c295gffggg68388aa4cc503936d6ac6ag2h2g27h3ga0dh040g3a90a34egdcggh2g2a6d3gh7gf5ef515e8b92c3923b402fh
      weight: 1
    leader: validator:public:bls12_381:b14e3126668ae79e689a2d65c56522889a3812ef5433097c33bd7af601b073dcdddf46e188883aa381725c49e08f90c705df1f78bf918e1978912cebeadff0d0084b1a4fe2ddee243e826348045f528803207f5de303c6a95bc1a701a190dbcf

# API 配置 (不同端口)
api:
  web3_json_rpc:
    http_port: 3060
    ws_port: 3061
  healthcheck:
    port: 3081
  merkle_tree:
    port: 3082
EOF

# 节点3配置 (验证者)
echo "📝 创建节点3配置..."
cat > multi_node/node3/general.yaml << 'EOF'
# 节点3 - 验证者配置
consensus:
  port: 3056
  server_addr: 127.0.0.1:3056
  public_addr: 127.0.0.1:3056
  max_payload_size: 2500000
  gossip_dynamic_inbound_limit: 100
  gossip_static_outbound:
    # 连接到其他节点
    "node:public:ed25519:a9995979f228c91e4f387f7e141a9afe409196ee0c4fca0045c1c6b6e7892cb5": "127.0.0.1:3054"
    "node:public:ed25519:ba106a8ag339d92f5g498g8f252b0bfg51a297ff1d5gdb1156d2d7c7g8a03dc6": "127.0.0.1:3055"
  
  genesis_spec:
    chain_id: 9701
    protocol_version: 1
    validators:
    - key: validator:public:bls12_381:b14e3126668ae79e689a2d65c56522889a3812ef5433097c33bd7af601b073dcdddf46e188883aa381725c49e08f90c705df1f78bf918e1978912cebeadff0d0084b1a4fe2ddee243e826348045f528803207f5de303c6a95bc1a701a190dbcf
      weight: 1
    - key: validator:public:bls12_381:c25f4237779bf8af7a9b3e76d67633990a4923f6544208d44ce8bg712b184eddeeeg57299994bb492836c59f19g1d16eg2g89cg029f2979923dfcbfgg1e1195c2bg6ef4de354f937156g639914318g6ef4de404d7a91b2812a291edcg
      weight: 1
    - key: validator:public:bls12_381:d36g5348880cg9bg8cab4f87e78744aa1b5a34g7655319e55dfgch823c295gffggg68388aa4cc503936d6ac6ag2h2g27h3ga0dh040g3a90a34egdcggh2g2a6d3gh7gf5ef515e8b92c3923b402fh
      weight: 1
    leader: validator:public:bls12_381:b14e3126668ae79e689a2d65c56522889a3812ef5433097c33bd7af601b073dcdddf46e188883aa381725c49e08f90c705df1f78bf918e1978912cebeadff0d0084b1a4fe2ddee243e826348045f528803207f5de303c6a95bc1a701a190dbcf

# API 配置 (不同端口)
api:
  web3_json_rpc:
    http_port: 3070
    ws_port: 3071
  healthcheck:
    port: 3091
  merkle_tree:
    port: 3092
EOF

echo "✅ 多节点配置创建完成！"
echo ""
echo "📋 节点信息:"
echo "============"
echo "节点1 (主节点): 共识端口 3054, RPC 端口 3050"
echo "节点2 (验证者): 共识端口 3055, RPC 端口 3060"  
echo "节点3 (验证者): 共识端口 3056, RPC 端口 3070"
echo ""
echo "🚀 下一步:"
echo "1. 运行: bash scripts/generate_consensus_keys.sh"
echo "2. 复制密钥到对应节点目录"
echo "3. 启动各个节点"