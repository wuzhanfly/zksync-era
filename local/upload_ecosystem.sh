#!/bin/bash

set -e

SERVER="ubuntu@54.255.184.251"
KEY="/home/jerry/zk_gas.pem"
REMOTE_PATH="/home/ubuntu/node"

echo "=== 上传 tmai_ecosystem 到服务器 ==="
echo ""

# 检查 tmai_ecosystem 是否存在
if [ ! -d "tmai_ecosystem" ]; then
    echo "❌ tmai_ecosystem 目录不存在"
    echo "请先运行: ./local/deploy_contracts.sh"
    exit 1
fi

# 检查 SSH 密钥
if [ ! -f "$KEY" ]; then
    echo "❌ SSH 密钥不存在: $KEY"
    exit 1
fi

chmod 600 $KEY

echo "打包 tmai_ecosystem..."
tar czf tmai_ecosystem.tar.gz tmai_ecosystem/

echo "上传到服务器..."
scp -i $KEY tmai_ecosystem.tar.gz $SERVER:$REMOTE_PATH/

echo "在服务器上解压..."
ssh -i $KEY $SERVER << EOF
cd $REMOTE_PATH
tar xzf tmai_ecosystem.tar.gz
rm tmai_ecosystem.tar.gz
echo "✅ tmai_ecosystem 已部署到服务器"
EOF

# 清理本地临时文件
rm tmai_ecosystem.tar.gz

echo ""
echo "========================================="
echo "  ✅ 上传完成！"
echo "========================================="
echo ""
echo "下一步:"
echo "  在服务器上启动 tMai Server"
echo ""
echo "启动命令:"
echo "  ssh -i $KEY $SERVER"
echo "  cd $REMOTE_PATH"
echo "  ./start_server.sh"
echo ""
