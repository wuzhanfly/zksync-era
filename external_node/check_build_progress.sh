#!/bin/bash

# 检查 Docker 构建进度

echo "=== 检查 External Node 镜像构建进度 ==="
echo ""

# 检查 Docker 进程
if pgrep -f "docker build.*external-node" > /dev/null; then
    echo "✅ Docker 构建正在进行中..."
    echo ""
    
    # 显示最近的构建日志
    echo "📝 最近的构建活动:"
    docker ps -a | grep -i build || echo "   (无活动容器)"
    
    echo ""
    echo "💡 提示:"
    echo "   - 构建通常需要 20-30 分钟"
    echo "   - 主要时间花在编译 Rust 代码"
    echo "   - 可以继续等待或在另一个终端工作"
else
    echo "⏸️  没有检测到正在运行的构建进程"
    echo ""
    
    # 检查镜像是否已存在
    if docker images | grep -q "tmai-external-node.*latest"; then
        echo "✅ 镜像已构建完成！"
        echo ""
        docker images | grep tmai-external-node
        echo ""
        echo "下一步:"
        echo "  bash external_node/deploy_official_external_node.sh"
    else
        echo "❌ 镜像尚未构建"
        echo ""
        echo "开始构建:"
        echo "  bash external_node/build_external_node.sh"
    fi
fi
