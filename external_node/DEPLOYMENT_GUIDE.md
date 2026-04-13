# External Node 完整部署指南

## 🎯 部署目标

将 External Node 部署到独立服务器 `13.228.79.240`，从主节点 `54.255.184.251` 同步数据。

**重要**: 该服务器已有其他 ZK 节点运行，使用不同端口避免冲突。

## 📋 前置条件

### 服务器信息
- **主节点**: 54.255.184.251 (SSH: ~/zk_gas.pem)
- **外部节点**: 13.228.79.240 (SSH: zk_node1.pem)

### 端口分配
```
现有服务:
  3050  - 现有 ZK 节点 RPC
  10432 - 现有 PostgreSQL

tMai External Node (新):
  4050  - HTTP RPC
  4051  - WebSocket RPC
  4071  - Health Check
  5433  - PostgreSQL
```

详见: [PORT_MAPPING.md](PORT_MAPPING.md)

### 本地准备
- ✅ Docker 已安装
- ✅ tmai-server:2.0 镜像已构建
- ✅ SSH 密钥文件存在

## 🚀 部署步骤

### 步骤 1: 配置主节点防火墙

```bash
bash external_node/configure_main_node_firewall.sh
```

这会：
- 允许外部节点 IP 访问主节点 RPC 端口
- 检查主节点端口配置

**重要**: 确保主节点 docker-compose.yml 中的端口配置为：
```yaml
ports:
  - "0.0.0.0:3050:3050"  # 不是 127.0.0.1:3050:3050
```

如果需要修改，在主节点上执行：
```bash
ssh -i ~/zk_gas.pem ubuntu@54.255.184.251
cd /home/ubuntu/node
# 编辑 docker-compose.yml
docker compose restart tmai-server
```

### 步骤 2: 测试主节点连接

从本地测试：
```bash
curl -X POST http://54.255.184.251:3050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

应该返回：
```json
{"jsonrpc":"2.0","result":"0x25f8","id":1}
```

### 步骤 3: 部署外部节点

```bash
bash external_node/deploy_to_node1.sh
```

这个脚本会自动：
1. ✅ 从主节点下载 tmai_ecosystem 配置
2. ✅ 导出 Docker 镜像
3. ✅ 上传到外部节点服务器
4. ✅ 配置 docker-compose.yml
5. ✅ 启动 PostgreSQL 和 External Node

**预计时间**: 10-15 分钟（取决于网络速度）

### 步骤 4: 验证部署

```bash
# 检查外部节点状态（注意端口是 4050）
curl -X POST http://13.228.79.240:4050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# 现有 ZK 节点仍然正常（端口 3050）
curl -X POST http://13.228.79.240:3050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

### 步骤 5: 监控同步进度

```bash
bash external_node/check_sync_status.sh
```

输出示例：
```
=== 检查节点同步状态 ===

📊 主节点 (54.255.184.251):
  区块高度: 150 (0x96)

📊 外部节点 (13.228.79.240):
  区块高度: 145 (0x91)
  差距: 5 个区块
  ⚠️  接近同步 (差距 < 10 区块)
  进度: 96%
```

## 📊 服务管理

### 查看外部节点日志

```bash
ssh -i zk_node1.pem ubuntu@13.228.79.240
docker logs -f tmai-external-node
```

### 重启外部节点

```bash
ssh -i zk_node1.pem ubuntu@13.228.79.240
cd /home/ubuntu/e-node1
docker compose restart external-node
```

### 停止外部节点

```bash
ssh -i zk_node1.pem ubuntu@13.228.79.240
cd /home/ubuntu/e-node1
docker compose down
```

### 完全重新同步

```bash
ssh -i zk_node1.pem ubuntu@13.228.79.240
cd /home/ubuntu/e-node1
docker compose down
rm -rf db/*
docker compose up -d
```

## 🔍 故障排查

### 问题 1: 外部节点无法连接主节点

**症状**: 日志显示 "failed to connect to main node"

**解决方案**:
1. 检查主节点防火墙
2. 确认主节点监听 0.0.0.0
3. 测试网络连通性

```bash
# 在外部节点服务器上测试
ssh -i zk_node1.pem ubuntu@13.228.79.240
curl -v http://54.255.184.251:3050
```

### 问题 2: 同步速度慢

**症状**: 区块高度增长缓慢

**原因**: 这是正常的，外部节点需要验证所有历史区块

**优化**:
- 增加外部节点服务器配置
- 检查网络带宽
- 查看日志确认没有错误

### 问题 3: 数据库连接失败

**症状**: "database connection failed"

**解决方案**:
```bash
ssh -i zk_node1.pem ubuntu@13.228.79.240
cd /home/ubuntu/e-node1

# 检查 PostgreSQL 状态
docker ps | grep postgres

# 重启 PostgreSQL
docker compose restart postgres
```

### 问题 4: Docker 镜像加载失败

**症状**: "image not found"

**解决方案**:
```bash
# 在本地重新构建镜像
bash local/build_minimal_image.sh

# 重新部署
bash external_node/deploy_to_node1.sh
```

## 📈 性能优化

### 数据库优化

在外部节点的 docker-compose.yml 中调整 PostgreSQL 配置：

```yaml
postgres:
  command: >
    postgres
    -c max_connections=200
    -c shared_buffers=2GB
    -c effective_cache_size=6GB
    -c maintenance_work_mem=512MB
```

### 网络优化

确保两台服务器之间的网络延迟低：
```bash
# 测试延迟
ping -c 10 54.255.184.251
```

## 🔐 安全建议

1. **防火墙规则**: 只允许必要的 IP 访问
2. **SSH 密钥**: 妥善保管 SSH 密钥文件
3. **数据库密码**: 生产环境使用强密码
4. **HTTPS**: 考虑使用 Nginx + SSL 证书

## 📝 维护清单

### 每日检查
- [ ] 检查同步状态
- [ ] 查看错误日志
- [ ] 监控磁盘空间

### 每周检查
- [ ] 检查数据库大小
- [ ] 验证 RPC 响应时间
- [ ] 更新系统补丁

### 每月检查
- [ ] 备份配置文件
- [ ] 检查 Docker 镜像更新
- [ ] 性能优化评估

## 🎉 部署完成后

外部节点成功部署后，你将拥有：

✅ **高可用性**: 主节点故障时外部节点仍可提供查询服务
✅ **负载分散**: 可以将用户请求分发到外部节点
✅ **地理分布**: 外部节点可以部署在不同地区
✅ **易扩展**: 可以部署更多外部节点

## 📞 获取帮助

如遇问题，检查：
1. `external_node/README.md` - 基础文档
2. `MULTI_NODE_SETUP.md` - 多节点架构说明
3. 日志文件 - `docker logs tmai-external-node`

## 🔗 相关文档

- [MULTI_NODE_SETUP.md](../MULTI_NODE_SETUP.md) - 多节点架构详解
- [SERVER_DEPLOYMENT_GUIDE.md](../SERVER_DEPLOYMENT_GUIDE.md) - 服务器部署指南
- [DAPP_PORTAL_CONFIG.md](../DAPP_PORTAL_CONFIG.md) - dapp-portal 配置
