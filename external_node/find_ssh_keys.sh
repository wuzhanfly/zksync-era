#!/bin/bash

# 查找 SSH 密钥文件

echo "=== 查找 SSH 密钥文件 ==="
echo ""

# 需要的密钥
KEYS=("zk_gas.pem" "zk_node1.pem")

# 可能的位置
LOCATIONS=(
    "$HOME"
    "$(pwd)"
    "$HOME/.ssh"
    "/tmp"
)

for key in "${KEYS[@]}"; do
    echo "🔍 查找 $key:"
    found=false
    
    for loc in "${LOCATIONS[@]}"; do
        if [ -f "$loc/$key" ]; then
            echo "  ✅ 找到: $loc/$key"
            ls -lh "$loc/$key"
            found=true
        fi
    done
    
    if [ "$found" = false ]; then
        echo "  ❌ 未找到"
    fi
    
    echo ""
done

echo "========================================="
echo ""
echo "如果密钥文件在其他位置，请："
echo "1. 复制到 $HOME/ 目录"
echo "2. 或修改部署脚本中的路径"
echo ""
echo "示例："
echo "  cp /path/to/zk_node1.pem $HOME/"
echo "  chmod 400 $HOME/zk_node1.pem"

