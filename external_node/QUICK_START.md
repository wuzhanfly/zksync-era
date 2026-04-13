# 快速开始 - tMai External Node

## 🚀 一键部署

```bash
bash external_node/deploy_to_node1.sh
```

## 📊 服务信息

### 主节点
- **IP**: 54.255.184.251
- **RPC**: http://54.255.184.251:3050

### tMai External Node（新部署）
- **IP**: 13.228.79.240
- **HTTP RPC**: http://13.228.79.240:4050
- **WS RPC**: ws://13.228.79.240:4051
- **Health**: http://13.228.79.240:4071/health

### 现有 ZK 节点（不受影响）
- **IP**: 13.228.79.240
- **RPC**: http://13.228.79.240:3050

## ✅ 验证部署

```bash
# 测试 tMai External Node
curl -X POST http://13.228.79.240:4050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# 应该返回: {"jsonrpc":"2.0","result":"0x25f8","id":1}
```

## 📈 检查同步状态

```bash
bash external_node/check_sync_status.sh
```

## 📝 查看日志

```bash
ssh -i zk_node1.pem ubuntu@13.228.79.240
docker logs -f tmai-external-node
```

## 🔄 重启服务

```bash
ssh -i zk_node1.pem ubuntu@13.228.79.240
cd /home/ubuntu/e-node1
docker compose restart external-node
```

## 🛑 停止服务

```bash
ssh -i zk_node1.pem ubuntu@13.228.79.240
cd /home/ubuntu/e-node1
docker compose down
```

## 📋 端口对照表

| 服务 | HTTP | WS | DB | Health |
|------|------|----|----|--------|
| 现有 ZK | 3050 | 3051 | 10432 | - |
| tMai External | **4050** | **4051** | 5433 | **4071** |

## 🔗 相关文档

- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - 完整部署指南
- [PORT_MAPPING.md](PORT_MAPPING.md) - 端口映射详情
- [README.md](README.md) - 架构说明
