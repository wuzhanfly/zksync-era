# External Node 部署方案

## 架构概述

```
┌─────────────────────────────────────┐
│ Main Node Server                    │
│ IP: 54.255.184.251                  │
│ SSH: zk_gas.pem                     │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ tmai-server (Main Node)         │ │
│ │ RPC: http://54.255.184.251:3050 │ │
│ │ Path: /home/ubuntu/node/        │ │
│ │       tmai_ecosystem             │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
              │
              │ 同步数据
              ▼
┌─────────────────────────────────────┐
│ External Node Server                │
│ IP: 13.228.79.240                   │
│ SSH: zk_node1.pem                   │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 现有 ZK 节点 (端口 3050)        │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ tMai External Node (端口 4050)  │ │
│ │ RPC: http://13.228.79.240:4050  │ │
│ │ Path: /home/ubuntu/e-node1      │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

## 端口分配

**重要**: 该服务器已有其他 ZK 节点，使用不同端口避免冲突。

| 服务 | HTTP RPC | WebSocket | Database | Health |
|------|----------|-----------|----------|--------|
| 现有 ZK 节点 | 3050 | 3051 | 10432 | - |
| tMai External | 4050 | 4051 | 5433 | 4071 |

详见: [PORT_MAPPING.md](PORT_MAPPING.md)

## 部署步骤

### 1. 准备工作

确保主节点可以被外部节点访问：
- 主节点 RPC 端口 3050 需要对外开放
- 防火墙允许 13.228.79.240 访问 54.255.184.251:3050

### 2. 部署流程

```bash
# 本地执行
bash external_node/deploy_to_node1.sh
```

这个脚本会自动：
1. 上传 tmai_ecosystem 配置到外部节点
2. 上传 Docker 镜像
3. 配置外部节点
4. 启动服务

### 3. 验证部署

```bash
# 检查主节点
curl -X POST http://54.255.184.251:3050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# 检查外部节点
curl -X POST http://13.228.79.240:3050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

## 网络要求

### 主节点服务器 (54.255.184.251)
- 开放端口 3050 (HTTP RPC)
- 允许来自 13.228.79.240 的连接

### 外部节点服务器 (13.228.79.240)
- 开放端口 3050 (HTTP RPC) - 对外提供服务
- 开放端口 3051 (WebSocket RPC) - 可选
- 能够访问 54.255.184.251:3050

## 故障排查

### 外部节点无法连接主节点

```bash
# 在外部节点服务器上测试
curl -X POST http://54.255.184.251:3050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

如果失败，检查：
1. 主节点防火墙设置
2. 安全组规则
3. 主节点是否监听 0.0.0.0

### 外部节点同步慢

这是正常的，外部节点需要从创世区块开始同步所有数据。

查看同步进度：
```bash
ssh -i zk_node1.pem ubuntu@13.228.79.240
docker logs -f tmai-external-node
```

## 维护

### 重启外部节点

```bash
ssh -i zk_node1.pem ubuntu@13.228.79.240
cd /home/ubuntu/e-node1
docker compose restart
```

### 查看日志

```bash
ssh -i zk_node1.pem ubuntu@13.228.79.240
docker logs -f tmai-external-node
```

### 清理并重新同步

```bash
ssh -i zk_node1.pem ubuntu@13.228.79.240
cd /home/ubuntu/e-node1
docker compose down
rm -rf db/*
docker compose up -d
```
