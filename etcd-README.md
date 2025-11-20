# etcdctl 工具使用指南

本镜像已集成 `etcdctl` 命令行工具，支持 etcd 数据的备份、恢复和管理操作。

## 安装版本

- **etcdctl 版本**: v3.5.12
- **支持架构**: linux/amd64, linux/arm64, linux/arm/v7

## 快速开始

### 1. 构建镜像

```bash
docker build -t busybox-tools:latest .
```

### 2. 运行容器

```bash
docker run -it --rm busybox-tools:latest
```

## etcdctl 基本使用

### 连接到 etcd 服务器

```bash
# 连接到本地 etcd
export ETCDCTL_ENDPOINTS="http://localhost:2379"

# 连接到远程 etcd
export ETCDCTL_ENDPOINTS="http://etcd.example.com:2379"

# 使用 TLS 连接
export ETCDCTL_CACERT="/path/to/ca.crt"
export ETCDCTL_CERT="/path/to/client.crt"
export ETCDCTL_KEY="/path/to/client.key"
export ETCDCTL_ENDPOINTS="https://etcd.example.com:2379"
```

### 基本 etcd 操作

```bash
# 检查 etcd 健康状态
etcdctl endpoint health

# 查看集群成员
etcdctl member list

# 查看集群状态
etcdctl endpoint status

# 设置键值
etcdctl put /myapp/config "value"

# 获取键值
etcdctl get /myapp/config

# 列出所有键
etcdctl get "" --prefix

# 删除键
etcdctl del /myapp/config
```

## 使用备份脚本

### 备份 etcd 数据

镜像提供了便捷的备份脚本 `etcd-backup.sh`：

```bash
# 基本备份（备份到默认目录 /tmp/etcd-backups）
./etcd-backup.sh

# 指定备份目录和端点
./etcd-backup.sh /backup etcd.example.com:2379

# 使用 TLS 连接备份
ETCDCTL_CACERT=/etc/ssl/etcd/ca.crt \
ETCDCTL_CERT=/etc/ssl/etcd/client.crt \
ETCDCTL_KEY=/etc/ssl/etcd/client.key \
./etcd-backup.sh /backup etcd.example.com:2379

# 备份特定前缀的数据
./etcd-backup.sh /backup etcd.example.com:2379 --prefix=/myapp/
```

### 恢复 etcd 数据

使用恢复脚本 `etcd-restore.sh`：

```bash
# 恢复到默认数据目录
./etcd-restore.sh /tmp/etcd-backup-20240101_120000.db

# 恢复到指定数据目录
./etcd-restore.sh /backup/etcd-backup.db /new-etcd-data
```

## 手动备份和恢复

### 手动备份

```bash
# 创建快照
etcdctl snapshot save /backup/etcd-snapshot.db

# 查看快照状态
etcdctl snapshot status /backup/etcd-snapshot.db --write-out=table
```

### 手动恢复

```bash
# 停止 etcd 服务
sudo systemctl stop etcd

# 恢复数据
etcdctl snapshot restore /backup/etcd-snapshot.db --data-dir /var/lib/etcd

# 设置权限
sudo chown -R etcd:etcd /var/lib/etcd

# 启动 etcd 服务
sudo systemctl start etcd
```

## 常用场景

### 1. 定期备份

```bash
#!/bin/bash
# daily-backup.sh

BACKUP_DIR="/backup/etcd/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

etcdctl snapshot save "$BACKUP_DIR/snapshot.db"
etcdctl snapshot status "$BACKUP_DIR/snapshot.db"

# 保留最近 7 天的备份
find /backup/etcd -type d -mtime +7 -exec rm -rf {} \;
```

### 2. 集群数据迁移

```bash
# 从集群 A 备份
etcdctl --endpoints=http://cluster-a:2379 snapshot save cluster-a-backup.db

# 恢复到集群 B
etcdctl snapshot restore cluster-a-backup.db --data-dir /var/lib/etcd-cluster-b
```

### 3. 监控 etcd 健康状态

```bash
#!/bin/bash
# health-check.sh

if etcdctl endpoint health; then
    echo "etcd is healthy"
else
    echo "etcd is unhealthy"
    exit 1
fi
```

## 环境变量配置

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `ETCDCTL_ENDPOINTS` | etcd 端点列表 | `http://localhost:2379` |
| `ETCDCTL_CACERT` | CA 证书路径 | `/etc/ssl/etcd/ca.crt` |
| `ETCDCTL_CERT` | 客户端证书路径 | `/etc/ssl/etcd/client.crt` |
| `ETCDCTL_KEY` | 客户端私钥路径 | `/etc/ssl/etcd/client.key` |
| `ETCDCTL_API` | API 版本 | `3` |

## 故障排除

### 常见错误

1. **连接被拒绝**
   ```bash
   # 检查 etcd 是否运行
   etcdctl endpoint health

   # 检查网络连接
   telnet etcd.example.com 2379
   ```

2. **TLS 证书错误**
   ```bash
   # 验证证书路径
   ls -la $ETCDCTL_CACERT $ETCDCTL_CERT $ETCDCTL_KEY

   # 使用 --insecure-skip-tls-verify 临时跳过验证（仅测试）
   etcdctl --insecure-skip-tls-verify endpoint health
   ```

3. **权限不足**
   ```bash
   # 检查数据目录权限
   ls -la /var/lib/etcd

   # 设置正确权限
   sudo chown -R etcd:etcd /var/lib/etcd
   ```

## 参考资料

- [etcd 官方文档](https://etcd.io/docs/)
- [etcdctl 使用指南](https://etcd.io/docs/v3.5/dev-guide/interacting_v3/)
- [etcd 备份和恢复](https://etcd.io/docs/v3.5/op-guide/recovery/)

## 注意事项

1. **备份前验证连接**: 确保能够正常连接到 etcd 服务器
2. **存储空间**: 备份文件大小取决于数据量，确保有足够的存储空间
3. **定期测试恢复**: 定期测试备份文件的完整性
4. **集群环境**: 集群环境下需要特殊处理，建议参考官方文档
5. **安全性**: 备份文件包含敏感数据，妥善存储和传输