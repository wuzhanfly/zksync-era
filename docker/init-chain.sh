#!/bin/bash
set -e

echo "=== tMai Chain 初始化脚本 ==="

# 等待数据库
echo "等待数据库就绪..."
until PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USER" -d postgres -c '\q' 2>/dev/null; do
  sleep 2
done
echo "✅ 数据库就绪"

cd /app

# 检查是否已初始化
if [ -d "/app/tmai_ecosystem/chains/tmai_chain" ]; then
    echo "⚠️  链已存在，跳过初始化"
    exit 0
fi

echo ""
echo "=== 1. 创建 Ecosystem ==="
zkstack ecosystem create \
    --ecosystem-name tmai_ecosystem \
    --l1-network custom \
    --link-to-code /app \
    --chain-name tmai_chain \
    --chain-id 9720 \
    --prover-mode no-proofs \
    --wallet-creation localhost \
    --l1-batch-commit-data-generator-mode rollup \
    --base-token-address $BASE_TOKEN_ADDRESS \
    --base-token-price-nominator 1 \
    --base-token-price-denominator 1 \
    --set-as-default false

echo ""
echo "=== 2. 初始化链配置 ==="
cd /app/tmai_ecosystem

# 修改配置
echo "修改 general.yaml 配置..."
cat > /app/tmai_ecosystem/chains/tmai_chain/configs/general.yaml.patch << 'EOF'
postgres:
  max_connections: 200
state_keeper:
  transaction_slots: 10000
  validation_computational_gas_limit: 300000
EOF

# 应用配置补丁
python3 << 'PYTHON'
import yaml

with open('/app/tmai_ecosystem/chains/tmai_chain/configs/general.yaml', 'r') as f:
    config = yaml.safe_load(f)

with open('/app/tmai_ecosystem/chains/tmai_chain/configs/general.yaml.patch', 'r') as f:
    patch = yaml.safe_load(f)

# 合并配置
config['postgres']['max_connections'] = patch['postgres']['max_connections']
config['state_keeper']['transaction_slots'] = patch['state_keeper']['transaction_slots']
config['state_keeper']['validation_computational_gas_limit'] = patch['state_keeper']['validation_computational_gas_limit']

with open('/app/tmai_ecosystem/chains/tmai_chain/configs/general.yaml', 'w') as f:
    yaml.dump(config, f, default_flow_style=False)

print("✅ 配置已更新")
PYTHON

echo ""
echo "=== 3. 初始化数据库 ==="
zkstack dev database setup --ecosystem-name tmai_ecosystem

echo ""
echo "=== 4. 部署 L1 合约 ==="
zkstack contract deploy \
    --ecosystem-name tmai_ecosystem \
    --chain-name tmai_chain \
    --l1-rpc-url $L1_RPC_URL

echo ""
echo "=== 5. 初始化 L1 合约 ==="
zkstack contract initialize \
    --ecosystem-name tmai_ecosystem \
    --chain-name tmai_chain

echo ""
echo "=== 6. 部署 L2 合约 ==="
zkstack contract deploy-l2-contracts \
    --ecosystem-name tmai_ecosystem \
    --chain-name tmai_chain

echo ""
echo "=== 7. 创建 Genesis ==="
zkstack server genesis \
    --ecosystem-name tmai_ecosystem \
    --chain-name tmai_chain

echo ""
echo "✅ 链初始化完成！"
echo ""
echo "配置信息已保存到: /app/tmai_ecosystem"
