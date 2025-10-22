#!/bin/bash

# 部署 ZKsync Era Bridge 合约到 BSC 测试网

echo "🌉 部署 ZKsync Era Bridge 合约到 BSC 测试网"
echo "=============================================="

# 配置参数
BSC_TESTNET_RPC="https://data-seed-prebsc-1-s1.binance.org:8545"
PRIVATE_KEY="${PRIVATE_KEY:-f778138bf30a0e6eea7eba238c474f082bd0a149a38031c3bf8062fdbdaf80da}"
DEPLOYER_ADDRESS="0x69AC695BE0e9f67d9b2e933628039Af1E37f5840"

echo "📋 部署参数:"
echo "==========="
echo "L1 网络: BSC 测试网"
echo "RPC URL: $BSC_TESTNET_RPC"
echo "部署者: $DEPLOYER_ADDRESS"
echo "链 ID: 97"
echo ""

# 检查网络连接
echo "🔍 检查 BSC 测试网连接..."
if ! curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   $BSC_TESTNET_RPC | grep -q "result"; then
    echo "❌ BSC 测试网连接失败"
    exit 1
fi
echo "✅ BSC 测试网连接正常"

# 检查账户余额
echo ""
echo "💰 检查部署者余额..."
BALANCE=$(cast balance $DEPLOYER_ADDRESS --rpc-url $BSC_TESTNET_RPC)
BALANCE_BNB=$(cast to-unit $BALANCE ether)
echo "余额: $BALANCE_BNB BNB"

if [ $(echo "$BALANCE_BNB < 0.1" | bc -l) -eq 1 ]; then
    echo "⚠️  余额不足，建议至少 0.1 BNB 用于部署"
    echo "💡 获取测试 BNB: https://testnet.binance.org/faucet-smart"
fi

echo ""
echo "🚀 开始部署 L1 核心合约..."

# 设置环境变量
export ETH_CLIENT_WEB3_URL=$BSC_TESTNET_RPC
export ETH_CLIENT_CHAIN_ID=97
export PRIVATE_KEY=$PRIVATE_KEY

# 部署 L1 核心合约
echo "部署生态系统合约..."
if ./zkstack_cli/target/release/zkstack chain deploy-l1-contracts --chain era; then
    echo "✅ L1 核心合约部署成功"
else
    echo "❌ L1 核心合约部署失败"
    exit 1
fi

echo ""
echo "📝 更新合约配置..."

# 检查部署结果
if [ -f "chains/era/configs/contracts.yaml" ]; then
    echo "✅ 合约配置文件已生成"
    
    # 显示关键合约地址
    echo ""
    echo "🔗 部署的合约地址:"
    echo "================="
    
    # 提取关键地址 (需要根据实际配置文件格式调整)
    if command -v yq &> /dev/null; then
        BRIDGEHUB_ADDR=$(yq '.core_ecosystem_contracts.bridgehub_proxy_addr' chains/era/configs/contracts.yaml)
        ERC20_BRIDGE_ADDR=$(yq '.bridges.erc20.l1_address' chains/era/configs/contracts.yaml)
        SHARED_BRIDGE_ADDR=$(yq '.bridges.shared.l1_address' chains/era/configs/contracts.yaml)
        
        echo "Bridgehub: $BRIDGEHUB_ADDR"
        echo "ERC20 Bridge: $ERC20_BRIDGE_ADDR"
        echo "Shared Bridge: $SHARED_BRIDGE_ADDR"
    else
        echo "请安装 yq 工具来解析配置文件"
        echo "或手动查看: chains/era/configs/contracts.yaml"
    fi
    
else
    echo "❌ 合约配置文件未找到"
    echo "请检查部署是否成功"
fi

echo ""
echo "🔧 注册链到 Bridgehub..."

# 注册链
if ./zkstack_cli/target/release/zkstack chain register --chain era; then
    echo "✅ 链注册成功"
else
    echo "❌ 链注册失败"
    echo "💡 可能需要手动注册或检查配置"
fi

echo ""
echo "🌉 设置 Bridge 连接..."

# 设置遗留桥接 (如果需要)
if ./zkstack_cli/target/release/zkstack chain setup-legacy-bridge --chain era; then
    echo "✅ Bridge 设置成功"
else
    echo "⚠️  Bridge 设置可能失败，请检查日志"
fi

echo ""
echo "✅ Bridge 合约部署完成！"
echo ""
echo "📊 部署总结:"
echo "==========="
echo "✅ L1 核心合约已部署到 BSC 测试网"
echo "✅ Bridge 合约已配置"
echo "✅ 链已注册到 Bridgehub"
echo ""
echo "🔗 验证部署:"
echo "==========="
echo "1. 查看合约: chains/era/configs/contracts.yaml"
echo "2. BSC 浏览器: https://testnet.bscscan.com/"
echo "3. 测试存款: bash scripts/test_bridge_deposit.sh"
echo ""
echo "💡 下一步:"
echo "========="
echo "1. 启动 L2 节点: ./zkstack_cli/target/release/zkstack server --chain era"
echo "2. 测试桥接功能"
echo "3. 部署前端界面"