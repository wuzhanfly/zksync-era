#!/bin/bash

echo "🔥 应用高 TPS 优化配置"
echo "================================"
echo ""

CONFIG_DIR="tmai_ecosystem/chains/tmai_chain/configs"
BACKUP_DIR="$CONFIG_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 备份当前配置
echo "📦 备份当前配置..."
cp "$CONFIG_DIR/general.yaml" "$BACKUP_DIR/general_${TIMESTAMP}.yaml"
echo "   ✅ 备份到: $BACKUP_DIR/general_${TIMESTAMP}.yaml"
echo ""

# 合并配置（保留原配置中的其他部分，只更新优化的部分）
echo "🔧 应用优化配置..."

# 使用 yq 合并配置（如果没有 yq，则直接替换关键参数）
if command -v yq &> /dev/null; then
    echo "   使用 yq 合并配置..."
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
        "$CONFIG_DIR/general.yaml" \
        "$CONFIG_DIR/general_high_tps.yaml" > "$CONFIG_DIR/general_new.yaml"
    mv "$CONFIG_DIR/general_new.yaml" "$CONFIG_DIR/general.yaml"
else
    echo "   ⚠️  未安装 yq，使用 sed 直接修改..."
    
    # 关键参数修改
    sed -i 's/block_commit_deadline_ms: 3000/block_commit_deadline_ms: 500/' "$CONFIG_DIR/general.yaml"
    sed -i 's/miniblock_commit_deadline_ms: 1000/miniblock_commit_deadline_ms: 200/' "$CONFIG_DIR/general.yaml"
    sed -i 's/transaction_slots: 10000/transaction_slots: 20000/' "$CONFIG_DIR/general.yaml"
    sed -i 's/max_gas_per_batch: 200000000/max_gas_per_batch: 500000000/' "$CONFIG_DIR/general.yaml"
    sed -i 's/miniblock_max_payload_size: 1000000/miniblock_max_payload_size: 5000000/' "$CONFIG_DIR/general.yaml"
    sed -i 's/miniblock_seal_queue_capacity: 10/miniblock_seal_queue_capacity: 50/' "$CONFIG_DIR/general.yaml"
    sed -i 's/sync_interval_ms: 10/sync_interval_ms: 5/' "$CONFIG_DIR/general.yaml"
    sed -i 's/delay_interval: 100/delay_interval: 50/' "$CONFIG_DIR/general.yaml"
    sed -i 's/capacity: 10000000/capacity: 20000000/' "$CONFIG_DIR/general.yaml"
    sed -i 's/sync_batch_size: 1000/sync_batch_size: 2000/' "$CONFIG_DIR/general.yaml"
    sed -i 's/pubsub_polling_interval: 200/pubsub_polling_interval: 100/' "$CONFIG_DIR/general.yaml"
    sed -i 's/max_nonce_ahead: 200/max_nonce_ahead: 500/' "$CONFIG_DIR/general.yaml"
    sed -i 's/max_connections: 200/max_connections: 500/' "$CONFIG_DIR/general.yaml"
    sed -i 's/state_keeper_db_block_cache_capacity_mb: 128/state_keeper_db_block_cache_capacity_mb: 512/' "$CONFIG_DIR/general.yaml"
    sed -i 's/block_cache_size_mb: 128/block_cache_size_mb: 512/' "$CONFIG_DIR/general.yaml"
    sed -i 's/memtable_capacity_mb: 256/memtable_capacity_mb: 512/' "$CONFIG_DIR/general.yaml"
    sed -i 's/max_l1_batches_per_iter: 20/max_l1_batches_per_iter: 50/' "$CONFIG_DIR/general.yaml"
    sed -i 's/multi_get_chunk_size: 500/multi_get_chunk_size: 1000/' "$CONFIG_DIR/general.yaml"
    sed -i 's/tx_poll_period: 300 ms/tx_poll_period: 100 ms/' "$CONFIG_DIR/general.yaml"
    sed -i 's/aggregate_tx_poll_period: 300 ms/aggregate_tx_poll_period: 100 ms/' "$CONFIG_DIR/general.yaml"
    sed -i 's/max_txs_in_flight: 50/max_txs_in_flight: 100/' "$CONFIG_DIR/general.yaml"
    sed -i 's/max_aggregated_tx_gas: 15000000/max_aggregated_tx_gas: 30000000/' "$CONFIG_DIR/general.yaml"
fi

echo "   ✅ 配置已更新"
echo ""

# 显示关键变更
echo "📊 关键优化参数:"
echo "   • block_commit_deadline_ms: 3000 → 500"
echo "   • miniblock_commit_deadline_ms: 1000 → 200"
echo "   • transaction_slots: 10000 → 20000"
echo "   • max_gas_per_batch: 200M → 500M"
echo "   • miniblock_max_payload_size: 1M → 5M"
echo "   • mempool sync_interval_ms: 10 → 5"
echo "   • max_connections: 200 → 500"
echo "   • cache sizes: 128MB → 512MB"
echo ""

echo "⚠️  重要提示:"
echo "   1. 需要重启节点才能生效"
echo "   2. 如需恢复，使用备份: $BACKUP_DIR/general_${TIMESTAMP}.yaml"
echo "   3. 建议监控服务器资源使用情况"
echo ""

echo "🚀 下一步:"
echo "   在服务器上重启节点:"
echo "   ssh -i ~/zk_gas.pem ubuntu@54.255.184.251"
echo "   cd /home/ubuntu/node"
echo "   docker-compose down"
echo "   docker-compose up -d"
echo ""

echo "✅ 配置应用完成！"
