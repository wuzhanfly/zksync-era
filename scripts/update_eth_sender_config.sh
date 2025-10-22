#!/bin/bash

# 更新 ETH Sender 配置以支持网络感知

CONFIG_FILE="/tmp/bsc-testnet-demo/bsc_testnet_demo/chains/bsc_test_chain/configs/general.yaml"

echo "更新 ETH Sender 配置: $CONFIG_FILE"

# 备份配置
cp "$CONFIG_FILE" "${CONFIG_FILE}.network_aware_backup"

# 使用 Python 更新配置
python3 << 'PYTHON_EOF'
import yaml
import sys

config_file = "/tmp/bsc-testnet-demo/bsc_testnet_demo/chains/bsc_test_chain/configs/general.yaml"

try:
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)

    # 确保 eth_sender 配置存在
    if 'eth_sender' not in config:
        config['eth_sender'] = {}

    # 网络感知配置
    config['eth_sender'].update({
        # BSC 兼容的费用配置
        'max_acceptable_priority_fee_in_gwei': 100,  # 100 Gwei
        'max_acceptable_base_fee_in_wei': 200000000000,  # 200 Gwei
        'time_in_mempool_in_l1_blocks_cap': 50,
        
        # BSC 网络优化
        'wait_confirmations': 1,
        'max_txs_in_flight': 3,
        'expected_confirmations_for_tx_type': {
            'commit': 1,
            'prove': 1,
            'execute': 1
        },
        
        # Gas adjuster 配置
        'gas_adjuster': {
            'default_priority_fee_per_gas': 1000000000,  # 1 Gwei
            'max_base_fee_samples': 10000,
            'pricing_formula_parameter_a': 3.0,
            'pricing_formula_parameter_b': 1.1,
            'internal_l1_pricing_multiplier': 0.8,
            'internal_enforced_l1_gas_price': None,  # 让系统自动检测
            'internal_enforced_priority_fee_per_gas': None,  # 让系统自动检测
            'poll_period': 15,
            'max_l1_gas_price': 100000000000  # 100 Gwei
        }
    })

    # ETH Watch 配置优化 (解决范围限制问题)
    if 'eth' not in config:
        config['eth'] = {}
    if 'watcher' not in config['eth']:
        config['eth']['watcher'] = {}
    
    config['eth']['watcher'].update({
        'confirmations_for_eth_event': 1,
        'eth_node_poll_interval': 300,  # 5 分钟
        'max_blocks_to_process_in_iteration': 1000,  # 减小批次大小
    })

    # 写回配置
    with open(config_file, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, indent=2)

    print("✅ 网络感知配置更新成功")

except Exception as e:
    print(f"❌ 配置更新失败: {e}")
    sys.exit(1)
PYTHON_EOF

echo "✅ ETH Sender 配置更新完成"
