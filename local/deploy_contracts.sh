#!/bin/bash

set -e

echo "=== 本地合约部署脚本 ==="
echo ""

# 配置
SERVER_IP="54.255.184.251"
DB_HOST="$SERVER_IP"
DB_PORT="5432"
DB_USER="postgres"
DB_PASSWORD="notsecurepassword"
L1_RPC_URL="http://13.212.114.138:10575"
TMAI_TOKEN="0xC42F240C256F5FB97346b9d69d10E2e1D77b2EBa"
FUNDER_PRIVATE_KEY="0xc9fd9d8eedf1d07a3ff46bd7370c48db3b4c359f4d0dfd73404c3a27f687dae1"

# 检查数据库连接
echo "检查远程数据库连接..."
if ! PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c '\q' 2>/dev/null; then
    echo "❌ 无法连接到远程数据库"
    echo "请确保:"
    echo "  1. 服务器上 PostgreSQL 已启动"
    echo "  2. 防火墙允许 5432 端口"
    echo "  3. PostgreSQL 配置允许远程连接"
    exit 1
fi
echo "✅ 数据库连接成功"
echo ""

# 设置环境变量
export DATABASE_URL="postgres://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/zksync_server_bsc_testnet_tmai_chain"

export L1_RPC_URL="http://13.212.114.138:10575"
export L1_CHAIN_ID=97
export BASE_TOKEN_ADDRESS="0xC42F240C256F5FB97346b9d69d10E2e1D77b2EBa"

echo "=== 1. 创建 Ecosystem ==="
REPO_PATH=$(pwd)
zkstack ecosystem create \
    --ecosystem-name tmai_ecosystem \
    --l1-network bsc-testnet \
    --link-to-code "$REPO_PATH" \
    --chain-name tmai_chain \
    --chain-id 9720 \
    --prover-mode no-proofs \
    --wallet-creation random \
    --l1-batch-commit-data-generator-mode rollup \
    --base-token-address $BASE_TOKEN_ADDRESS \
    --base-token-price-nominator 1 \
    --base-token-price-denominator 1 \
    --set-as-default false

# 创建数据库（如果不存在）
echo "创建数据库..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "CREATE DATABASE zksync_server_bsc_testnet_tmai_chain;" 2>/dev/null || echo "数据库可能已存在"
echo "✅ 数据库准备就绪"
echo ""

# 检查 tmai_ecosystem 是否存在
if [ ! -d "tmai_ecosystem" ]; then
    echo "❌ tmai_ecosystem 不存在"
    echo "请先运行: zkstack ecosystem create"
    exit 1
fi

echo "=== 1. 读取生成的钱包地址 ==="
cd tmai_ecosystem
WALLETS_FILE="configs/wallets.yaml"

# 提取地址
DEPLOYER_ADDR=$(grep -A 1 "^deployer:" $WALLETS_FILE | grep "address:" | awk '{print $2}' | tr -d '"')
OPERATOR_ADDR=$(grep -A 1 "^operator:" $WALLETS_FILE | grep "address:" | awk '{print $2}' | tr -d '"')
GOVERNOR_ADDR=$(grep -A 1 "^governor:" $WALLETS_FILE | grep "address:" | awk '{print $2}' | tr -d '"')
BLOB_OPERATOR_ADDR=$(grep -A 1 "^blob_operator:" $WALLETS_FILE | grep "address:" | awk '{print $2}' | tr -d '"')

echo "Deployer: $DEPLOYER_ADDR"
echo "Operator: $OPERATOR_ADDR"
echo "Governor: $GOVERNOR_ADDR"
echo "Blob Operator: $BLOB_OPERATOR_ADDR"

cd ..

echo ""
echo "=== 2. 给钱包地址转账 ==="
node << EOF
const { ethers } = require("ethers");

const L1_RPC_URL = "$L1_RPC_URL";
const TMAI_TOKEN = "$TMAI_TOKEN";
const FUNDER_PRIVATE_KEY = "$FUNDER_PRIVATE_KEY";

const addresses = [
  "$DEPLOYER_ADDR",
  "$OPERATOR_ADDR",
  "$GOVERNOR_ADDR",
  "$BLOB_OPERATOR_ADDR"
];

const ERC20_ABI = [
  "function transfer(address to, uint256 amount) returns (bool)"
];

async function fundWallets() {
  const provider = new ethers.JsonRpcProvider(L1_RPC_URL);
  const funder = new ethers.Wallet(FUNDER_PRIVATE_KEY, provider);
  const tmaiContract = new ethers.Contract(TMAI_TOKEN, ERC20_ABI, funder);

  for (const addr of addresses) {
    if (!addr || addr === 'null') continue;
    
    console.log(\`\n转账到 \${addr}...\`);
    
    // 转 0.1 BNB
    const bnbTx = await funder.sendTransaction({
      to: addr,
      value: ethers.parseEther("0.1")
    });
    await bnbTx.wait();
    console.log(\`✅ BNB 已转账: \${bnbTx.hash}\`);
    
    // 转 1000 tMai
    const tmaiTx = await tmaiContract.transfer(addr, ethers.parseEther("1000"));
    await tmaiTx.wait();
    console.log(\`✅ tMai 已转账: \${tmaiTx.hash}\`);
  }
  
  console.log(\`\n✅ 所有钱包已充值\`);
}

fundWallets().catch(console.error);
EOF

echo ""
echo "=== 3. 部署合约和初始化 ==="
cd tmai_ecosystem

# 使用 --server-db-url 参数避免交互式输入
zkstack ecosystem init \
    --l1-rpc-url $L1_RPC_URL \
    --server-db-url "$DATABASE_URL" \
    --deploy-ecosystem true \
    --deploy-paymaster true

cd ..

echo ""
echo "=== 4. 修改 general.yaml 配置 ==="
cd tmai_ecosystem

# 修改 general.yaml
python3 << 'PYTHON'
import yaml

config_file = 'chains/tmai_chain/configs/general.yaml'
with open(config_file, 'r') as f:
    config = yaml.safe_load(f)

# 修改配置
config['postgres']['max_connections'] = 200
config['state_keeper']['transaction_slots'] = 10000
config['state_keeper']['validation_computational_gas_limit'] = 300000

with open(config_file, 'w') as f:
    yaml.dump(config, f, default_flow_style=False)

print("✅ general.yaml 已更新")
PYTHON

cd ..

echo ""
echo "========================================="
echo "  ✅ 合约部署完成！"
echo "========================================="
echo ""
echo "tmai_ecosystem 目录已创建并配置完成"
echo ""
echo "下一步:"
echo "  1. 上传 tmai_ecosystem 到服务器: ./local/upload_ecosystem.sh"
echo "  2. 在服务器上启动服务: ssh 到服务器运行 ./start_server.sh"
echo ""
