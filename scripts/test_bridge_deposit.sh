#!/bin/bash

# 测试 Bridge 存款功能

echo "🌉 测试 ZKsync Era Bridge 存款功能"
echo "=================================="

# 配置参数
BSC_TESTNET_RPC="https://data-seed-prebsc-1-s1.binance.org:8545"
L2_RPC="http://localhost:3050"
PRIVATE_KEY="${PRIVATE_KEY:-f778138bf30a0e6eea7eba238c474f082bd0a149a38031c3bf8062fdbdaf80da}"
DEPOSITOR_ADDRESS="0x69AC695BE0e9f67d9b2e933628039Af1E37f5840"

# 存款参数
DEPOSIT_AMOUNT="0.001"  # 0.001 BNB
L2_GAS_LIMIT="100000"

echo "📋 测试参数:"
echo "==========="
echo "存款者: $DEPOSITOR_ADDRESS"
echo "存款金额: $DEPOSIT_AMOUNT BNB"
echo "L1 网络: BSC 测试网"
echo "L2 网络: ZKsync Era (localhost:3050)"
echo ""

# 检查网络连接
echo "🔍 检查网络连接..."

# 检查 L1 网络
if ! curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   $BSC_TESTNET_RPC | grep -q "result"; then
    echo "❌ L1 网络连接失败"
    exit 1
fi
echo "✅ L1 网络连接正常"

# 检查 L2 网络
if ! curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   $L2_RPC | grep -q "result"; then
    echo "❌ L2 网络连接失败，请先启动 ZKsync Era 节点"
    exit 1
fi
echo "✅ L2 网络连接正常"

# 检查余额
echo ""
echo "💰 检查账户余额..."

L1_BALANCE=$(cast balance $DEPOSITOR_ADDRESS --rpc-url $BSC_TESTNET_RPC)
L1_BALANCE_BNB=$(cast to-unit $L1_BALANCE ether)
echo "L1 余额: $L1_BALANCE_BNB BNB"

L2_BALANCE=$(cast balance $DEPOSITOR_ADDRESS --rpc-url $L2_RPC)
L2_BALANCE_ETH=$(cast to-unit $L2_BALANCE ether)
echo "L2 余额: $L2_BALANCE_ETH ETH"

# 检查是否有足够余额进行存款
REQUIRED_AMOUNT=$(echo "$DEPOSIT_AMOUNT + 0.01" | bc -l)  # 存款金额 + Gas 费
if [ $(echo "$L1_BALANCE_BNB < $REQUIRED_AMOUNT" | bc -l) -eq 1 ]; then
    echo "❌ L1 余额不足，需要至少 $REQUIRED_AMOUNT BNB"
    exit 1
fi

# 读取合约地址
echo ""
echo "📖 读取合约地址..."

if [ ! -f "chains/era/configs/contracts.yaml" ]; then
    echo "❌ 合约配置文件不存在"
    echo "请先运行: bash scripts/deploy_bridge_contracts.sh"
    exit 1
fi

# 提取合约地址 (简化版本，实际需要根据配置文件格式调整)
if command -v yq &> /dev/null; then
    BRIDGEHUB_ADDR=$(yq '.core_ecosystem_contracts.bridgehub_proxy_addr' chains/era/configs/contracts.yaml 2>/dev/null)
    ERC20_BRIDGE_ADDR=$(yq '.bridges.erc20.l1_address' chains/era/configs/contracts.yaml 2>/dev/null)
    
    if [ "$BRIDGEHUB_ADDR" = "null" ] || [ -z "$BRIDGEHUB_ADDR" ]; then
        echo "❌ 无法读取 Bridgehub 地址"
        echo "请检查合约配置文件"
        exit 1
    fi
    
    echo "✅ Bridgehub 地址: $BRIDGEHUB_ADDR"
    echo "✅ ERC20 Bridge 地址: $ERC20_BRIDGE_ADDR"
else
    echo "⚠️  未安装 yq，使用默认地址进行测试"
    # 这里需要手动设置实际部署的合约地址
    BRIDGEHUB_ADDR="0x0000000000000000000000000000000000000000"
    echo "请手动设置 BRIDGEHUB_ADDR 变量"
fi

# 执行存款
echo ""
echo "🚀 执行存款交易..."

if [ "$BRIDGEHUB_ADDR" != "0x0000000000000000000000000000000000000000" ]; then
    
    # 构造存款交易 (这是一个示例，实际参数需要根据合约接口调整)
    echo "发送存款交易..."
    
    # 示例存款调用 (需要根据实际合约接口调整)
    DEPOSIT_TX=$(cast send $BRIDGEHUB_ADDR \
        "requestL2TransactionDirect((uint256,uint256,address,uint256,bytes,uint256,uint256,bytes[],address))" \
        "(97,$(cast chain-id --rpc-url $L2_RPC),$DEPOSITOR_ADDRESS,$(cast to-wei $DEPOSIT_AMOUNT ether),'0x',$L2_GAS_LIMIT,800,'[]',$DEPOSITOR_ADDRESS)" \
        --value $(cast to-wei $DEPOSIT_AMOUNT ether) \
        --rpc-url $BSC_TESTNET_RPC \
        --private-key $PRIVATE_KEY \
        2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$DEPOSIT_TX" ]; then
        echo "✅ 存款交易已发送"
        echo "交易哈希: $DEPOSIT_TX"
        
        echo ""
        echo "⏳ 等待交易确认..."
        sleep 10
        
        # 检查交易状态
        TX_RECEIPT=$(cast receipt $DEPOSIT_TX --rpc-url $BSC_TESTNET_RPC 2>/dev/null)
        if [ $? -eq 0 ]; then
            STATUS=$(echo "$TX_RECEIPT" | grep "status" | awk '{print $2}')
            if [ "$STATUS" = "1" ]; then
                echo "✅ L1 存款交易确认成功"
                
                echo ""
                echo "⏳ 等待 L2 处理 (可能需要几分钟)..."
                sleep 30
                
                # 检查 L2 余额变化
                NEW_L2_BALANCE=$(cast balance $DEPOSITOR_ADDRESS --rpc-url $L2_RPC)
                NEW_L2_BALANCE_ETH=$(cast to-unit $NEW_L2_BALANCE ether)
                
                echo "更新后 L2 余额: $NEW_L2_BALANCE_ETH ETH"
                
                # 计算余额变化
                BALANCE_DIFF=$(echo "$NEW_L2_BALANCE_ETH - $L2_BALANCE_ETH" | bc -l)
                if [ $(echo "$BALANCE_DIFF > 0" | bc -l) -eq 1 ]; then
                    echo "🎉 存款成功！L2 余额增加了 $BALANCE_DIFF ETH"
                else
                    echo "⏳ L2 余额暂未更新，可能还在处理中"
                    echo "💡 请稍后检查余额或查看 L2 节点日志"
                fi
                
            else
                echo "❌ L1 交易失败"
                echo "请检查交易详情: cast receipt $DEPOSIT_TX --rpc-url $BSC_TESTNET_RPC"
            fi
        else
            echo "❌ 无法获取交易收据"
        fi
        
    else
        echo "❌ 存款交易发送失败"
        echo "可能的原因:"
        echo "1. 合约地址不正确"
        echo "2. 函数签名不匹配"
        echo "3. Gas 费用不足"
        echo "4. 网络连接问题"
    fi
    
else
    echo "❌ 无法执行存款，合约地址未配置"
    echo ""
    echo "💡 手动存款步骤:"
    echo "================"
    echo "1. 获取正确的 Bridgehub 合约地址"
    echo "2. 调用 requestL2TransactionDirect 函数"
    echo "3. 提供正确的参数和 value"
    echo ""
    echo "示例命令:"
    echo "cast send <BRIDGEHUB_ADDRESS> 'requestL2TransactionDirect(...)' \\"
    echo "  <PARAMETERS> --value $DEPOSIT_AMOUNT --rpc-url $BSC_TESTNET_RPC"
fi

echo ""
echo "📊 测试总结:"
echo "==========="
echo "L1 网络: BSC 测试网 ✅"
echo "L2 网络: ZKsync Era ✅"
echo "合约配置: $([ -f "chains/era/configs/contracts.yaml" ] && echo "✅" || echo "❌")"
echo "存款测试: $([ -n "$DEPOSIT_TX" ] && echo "✅" || echo "⚠️")"
echo ""
echo "🔗 有用的链接:"
echo "============="
echo "BSC 测试网浏览器: https://testnet.bscscan.com/"
echo "账户地址: https://testnet.bscscan.com/address/$DEPOSITOR_ADDRESS"
if [ -n "$DEPOSIT_TX" ]; then
    echo "存款交易: https://testnet.bscscan.com/tx/$DEPOSIT_TX"
fi