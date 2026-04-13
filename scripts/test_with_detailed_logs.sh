#!/bin/bash

echo "🔍 启用详细日志并测试单笔交易"
echo "========================================"

SERVER="ubuntu@54.255.184.251"
KEY="~/zk_gas.pem"

# 1. 备份当前配置
echo "1️⃣ 备份当前配置..."
scp -i $KEY $SERVER:/home/ubuntu/node/tmai_ecosystem/chains/tmai_chain/configs/general.yaml \
    tmai_ecosystem/chains/tmai_chain/configs/general.yaml.backup

# 2. 修改日志级别
echo "2️⃣ 修改日志级别为trace..."
sed -i 's/log_directives: warn,zksync=info/log_directives: trace,zksync=trace/' \
    tmai_ecosystem/chains/tmai_chain/configs/general.yaml

# 3. 上传新配置
echo "3️⃣ 上传新配置..."
scp -i $KEY tmai_ecosystem/chains/tmai_chain/configs/general.yaml \
    $SERVER:/home/ubuntu/node/tmai_ecosystem/chains/tmai_chain/configs/

# 4. 重启服务
echo "4️⃣ 重启服务..."
ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node
docker compose restart tmai-server
echo "等待30秒让服务启动..."
sleep 30
EOF

echo ""
echo "5️⃣ 发送测试交易..."
node scripts/test_single_tx.js

echo ""
echo "6️⃣ 等待10秒..."
sleep 10

echo ""
echo "7️⃣ 获取详细日志..."
ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node
docker compose logs --tail=200 --timestamps tmai-server 2>&1 | grep -E "finished tx|execute_tx|seal|process_block|took|duration" | tail -50
EOF

echo ""
echo "8️⃣ 恢复原配置..."
mv tmai_ecosystem/chains/tmai_chain/configs/general.yaml.backup \
   tmai_ecosystem/chains/tmai_chain/configs/general.yaml

echo ""
echo "✅ 测试完成"
