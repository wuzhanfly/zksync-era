# 端口映射说明

## 外部节点服务器 (13.228.79.240) 端口分配

### 现有服务（不要修改）
```
3050  - 现有 ZK 节点 HTTP RPC
3051  - 现有 ZK 节点 WebSocket RPC (可能)
5432  - 现有 ZK 节点 PostgreSQL (映射到 10432)
10432 - 现有 ZK 节点 PostgreSQL 外部端口
```

### tMai External Node（新部署）
```
4050  - tMai External Node HTTP RPC
4051  - tMai External Node WebSocket RPC
4071  - tMai External Node Health Check
5433  - tMai External Node PostgreSQL 外部端口
```

## 容器名称

### 现有容器
- `zk_bsc_docker` - 现有 ZK 节点
- `node-postgres-1` - 现有 PostgreSQL

### 新容器
- `tmai-external-node` - tMai 外部节点
- `tmai-external-postgres` - tMai PostgreSQL

## 访问方式

### 现有 ZK 节点
```bash
curl -X POST http://13.228.79.240:3050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

### tMai External Node
```bash
curl -X POST http://13.228.79.240:4050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

## 网络隔离

两个服务使用不同的 Docker 网络，互不干扰：
- 现有服务: 默认网络
- tMai 服务: `tmai-external-network`

## 如需添加更多外部节点

下一个外部节点可以使用：
- HTTP RPC: 5050
- WebSocket: 5051
- Health: 5071
- Database: 5434
