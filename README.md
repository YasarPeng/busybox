# 多功能调试工具镜像

这个 Docker 镜像包含了常用的数据库客户端、消息队列工具和网络排查工具。基于 Alpine Linux 构建，支持多架构（x86_64、ARM64、ARMv7）。

## 🚀 特性

- ✅ **多架构支持**: x86_64 (amd64), ARM64, ARMv7
- ✅ **小体积**: 基于 Alpine Linux，镜像大小显著减小
- ✅ **全面工具**: 包含数据库、消息队列、存储和网络工具
- ✅ **生产就绪**: 优化的多层构建和清理

## 📦 镜像大小对比

- **基于 Ubuntu**: ~800MB
- **基于 Alpine**: ~200MB (减少 75%)

## 🏗️ 支持的架构

| 架构 | 平台标识 | 说明 |
|------|----------|------|
| x86_64 | linux/amd64 | 标准 Intel/AMD 64位处理器 |
| ARM64 | linux/arm64 | Apple M1/M2, ARM 服务器 |
| ARMv7 | linux/arm/v7 | 树莓派等 ARM 设备 |

## 🛠️ 包含的工具

### 数据库客户端
- **MySQL**: `mysql`, `mysqldump`, `mysqlcheck` 等
- **Redis**: `redis-cli`

### 消息队列工具
- **RabbitMQ**: `rabbitmqctl`, `rabbitmq-admin` 等

### 存储工具
- **MinIO**: `mc` (MinIO Client)

### 网络排查工具
- `ping`, `traceroute`, `mtr` - 网络连通性测试
- `telnet` - 端口连通性测试
- `nslookup`, `dig` - DNS 查询
- `nmap` - 端口扫描
- `tcpdump` - 网络抓包
- `ip`, `ss` - 网络连接查看

### 系统工具
- `htop`, `iotop` - 系统监控
- `lsof` - 查看打开的文件
- `strace` - 系统调用跟踪
- `vim` - 文本编辑器
- `jq` - JSON 处理工具

## 🔨 构建镜像

### 前置要求

1. **Docker Engine** 19.03+
2. **Docker Buildx** (用于多架构构建)
   ```bash
   # 启用 buildx
   docker buildx install
   docker buildx create --name multiarch-builder --use
   ```

### 构建方法

#### 1. 使用构建脚本 (推荐)

```bash
# 克隆或下载相关文件
git clone <repository>
cd <repository>

# 构建所有架构的镜像 (本地)
./build.sh

# 构建并推送到仓库
./build.sh --push

# 构建特定架构
./build.sh --platforms "linux/amd64,linux/arm64"

# 查看帮助
./build.sh --help
```

#### 2. 手动构建

```bash
# 构建单个架构
docker build -t multi-tool-debug:latest .

# 使用 buildx 构建多架构
docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t multi-tool-debug:latest --push .
```

### 构建选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--push` | 推送到镜像仓库 | false |
| `--platforms` | 指定平台 | `linux/amd64,linux/arm64,linux/arm/v7` |
| `--tag` | 指定标签 | `latest` |

## 🚀 使用方法

### 基本使用

```bash
# 交互式运行 (自动选择架构)
docker run -it --rm multi-tool-debug:latest

# 指定架构运行
docker run -it --rm --platform linux/amd64 multi-tool-debug:latest
docker run -it --rm --platform linux/arm64 multi-tool-debug:latest

# 运行特定命令
docker run --rm multi-tool-debug:latest mysql --version
docker run --rm multi-tool-debug:latest redis-cli --version
```

### 连接到数据库

```bash
# MySQL
docker run -it --rm multi-tool-debug:latest mysql -h mysql-server -u root -p

# Redis
docker run -it --rm multi-tool-debug:latest redis-cli -h redis-server

# RabbitMQ 状态检查
docker run --rm multi-tool-debug:latest rabbitmqctl status
```

### 网络排查

```bash
# Ping 测试
docker run --rm multi-tool-debug:latest ping -c 4 8.8.8.8

# 端口扫描
docker run --rm multi-tool-debug:latest nmap -p 80,443 example.com

# DNS 查询
docker run --rm multi-tool-debug:latest nslookup example.com

# 网络抓包 (需要特权模式)
docker run --rm --privileged multi-tool-debug:latest tcpdump -i any
```

### MinIO 文件操作

```bash
# 配置 MinIO 客户端
docker run -it --rm -v ~/.mc:/root/.mc multi-tool-debug:latest \
  mc alias set minio http://minio-server:9000 ACCESS_KEY SECRET_KEY

# 列出文件
docker run --rm multi-tool-debug:latest mc ls minio/bucket
```

### 高级用法

```bash
# 挂载配置文件目录
docker run -it --rm -v /path/to/configs:/configs multi-tool-debug:latest

# 挂载主机网络
docker run -it --rm --network host multi-tool-debug:latest

# 作为调试 Pod 运行 (Kubernetes)
kubectl run debug-pod --image=multi-tool-debug:latest -it --rm --restart=Never -- bash
```

## 示例用法

### 1. 数据库备份
```bash
docker run --rm multi-tool-debug:latest mysqldump -h mysql-server -u root -p database_name > backup.sql
```

### 2. Redis 数据导出
```bash
docker run --rm multi-tool-debug:latest redis-cli -h redis-server --rdb backup.rdb
```

### 3. RabbitMQ 状态检查
```bash
docker run --rm multi-tool-debug:latest rabbitmqctl status
```

### 4. MinIO 文件操作
```bash
docker run -it --rm multi-tool-debug:latest mc ls minio/bucket
```

### 5. 网络诊断
```bash
docker run --rm multi-tool-debug:latest traceroute 8.8.8.8
```

## 注意事项

1. 这个镜像仅包含客户端工具，不包含服务器组件
2. 使用时需要确保目标服务可从容器访问
3. 敏感信息（如密码）建议使用环境变量而非命令行参数
4. 生产环境使用前请进行安全评估

## 自定义扩展

如需添加其他工具，可以修改 `Dockerfile` 并重新构建镜像。