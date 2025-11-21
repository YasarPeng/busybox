# 系统管理工具集

这个目录包含了一系列实用的系统管理工具脚本，主要针对MySQL数据库和RabbitMQ消息队列的管理。

## 📁 目录结构

```
/apps/
├── mysql_backup_restore.sh       # MySQL备份恢复工具
├── mysql_read_write_test.sh      # MySQL读写性能测试
├── mysql_table_size_analyzer.sh  # MySQL表大小分析工具
├── rabbitmq_vhost_manager.sh     # RabbitMQ虚拟主机管理
├── tools_menu.sh                 # 统一工具菜单
└── README.md                     # 说明文档
```

## 🚀 快速开始

### 使用统一菜单

```bash
# 进入容器后运行
/apps/tools_menu.sh menu
```

### 直接使用工具

```bash
# 查看所有可用工具
/apps/tools_menu.sh list

# 查看特定工具帮助
/apps/tools_menu.sh help mysql_backup_restore.sh

# 直接运行工具
/apps/tools_menu.sh mysql_backup_restore.sh backup mydatabase
```

## 🛠️ 工具详情

### 1. MySQL备份恢复工具 (`mysql_backup_restore.sh`)

**功能特性：**
- 备份单个数据库或所有数据库
- 恢复数据库
- 列出、删除备份文件
- 自动清理过期备份
- 支持压缩存储

**常用命令：**
```bash
# 备份数据库
MYSQL_PASSWORD=123456 /apps/mysql_backup_restore.sh backup myapp

# 备份所有数据库
MYSQL_PASSWORD=123456 /apps/mysql_backup_restore.sh backup-all

# 恢复数据库
MYSQL_PASSWORD=123456 /apps/mysql_backup_restore.sh restore myapp backup_file.sql.gz

# 列出备份文件
/apps/mysql_backup_restore.sh list

# 清理7天前的备份
/apps/mysql_backup_restore.sh clean 7
```

### 2. MySQL读写性能测试 (`mysql_read_write_test.sh`)

**功能特性：**
- 连通性测试
- 写入性能测试
- 读取性能测试
- 压力测试（并发连接）
- 完整性能基准测试

**常用命令：**
```bash
# 完整测试
MYSQL_PASSWORD=123456 /apps/mysql_read_write_test.sh test

# 写入测试（插入10000条记录）
MYSQL_PASSWORD=123456 /apps/mysql_read_write_test.sh write 10000

# 读取测试（5000次查询）
MYSQL_PASSWORD=123456 /apps/mysql_read_write_test.sh read 5000

# 压力测试（20个并发连接）
CONCURRENT_CONNECTIONS=20 MYSQL_PASSWORD=123456 /apps/mysql_read_write_test.sh stress

# 性能基准测试
MYSQL_PASSWORD=123456 /apps/mysql_read_write_test.sh benchmark
```

### 3. MySQL表大小分析工具 (`mysql_table_size_analyzer.sh`)

**功能特性：**
- 数据库大小概览
- 表大小详细分析
- 碎片分析
- 索引使用统计
- 存储引擎分布
- 大表和空表识别

**常用命令：**
```bash
# 显示所有数据库大小概览
MYSQL_PASSWORD=123456 /apps/mysql_table_size_analyzer.sh

# 显示指定数据库的所有表大小
MYSQL_PASSWORD=123456 /apps/mysql_table_size_analyzer.sh database myapp

# 显示最大的20个表
MYSQL_PASSWORD=123456 /apps/mysql_table_size_analyzer.sh top 20

# 显示大于500MB的表
MYSQL_PASSWORD=123456 /apps/mysql_table_size_analyzer.sh large 500

# 显示空表
MYSQL_PASSWORD=123456 /apps/mysql_table_size_analyzer.sh empty

# 显示碎片情况
MYSQL_PASSWORD=123456 /apps/mysql_table_size_analyzer.sh fragmentation

# 生成详细汇总报告
MYSQL_PASSWORD=123456 /apps/mysql_table_size_analyzer.sh summary
```

### 4. RabbitMQ虚拟主机管理 (`rabbitmq_vhost_manager.sh`)

**功能特性：**
- 创建、删除虚拟主机
- 管理用户和权限
- 查看虚拟主机详情和统计信息
- 插件管理
- 健康检查和监控

**常用命令：**
```bash
# 创建虚拟主机
/apps/rabbitmq_vhost_manager.sh create myapp_vhost

# 创建用户并设置权限
/apps/rabbitmq_vhost_manager.sh create-user myapp_user myapp_password management
/apps/rabbitmq_vhost_manager.sh set-permissions myapp_vhost myapp_user

# 列出虚拟主机
/apps/rabbitmq_vhost_manager.sh list

# 查看虚拟主机详情
/apps/rabbitmq_vhost_manager.sh info myapp_vhost

# 健康检查
/apps/rabbitmq_vhost_manager.sh health

# 启用管理插件
/apps/rabbitmq_vhost_manager.sh enable-feature rabbitmq_management
```

## 🔧 环境变量配置

### MySQL相关
```bash
export MYSQL_HOST=localhost        # MySQL服务器地址
export MYSQL_PORT=3306             # MySQL端口
export MYSQL_USER=root             # MySQL用户名
export MYSQL_PASSWORD=your_password # MySQL密码
export MYSQL_DATABASE=test_db      # 测试数据库名（可选）
```

### RabbitMQ相关
```bash
export RABBITMQ_HOST=localhost     # RabbitMQ管理界面地址
export RABBITMQ_PORT=15672         # RabbitMQ管理端口
export RABBITMQ_USER=guest         # RabbitMQ管理员用户名
export RABBITMQ_PASSWORD=guest     # RabbitMQ管理员密码
```

### 其他配置
```bash
export BACKUP_DIR=./mysql_backups  # MySQL备份目录
export CONCURRENT_CONNECTIONS=10   # 并发连接数
export TEST_DURATION=30            # 测试持续时间（秒）
export SORT_BY=size                # 排序字段（size/rows/name）
export ORDER=desc                  # 排序方向（asc/desc）
export OUTPUT_FORMAT=table         # 输出格式（table/csv/json）
```

## 📋 使用建议

### 1. 环境配置
建议将常用的环境变量添加到容器的启动脚本或配置文件中：

```bash
# 创建环境配置文件
cat > /etc/profile.d/tools-env.sh << 'EOF'
export MYSQL_HOST=your_mysql_host
export MYSQL_PORT=3306
export MYSQL_USER=your_username
export MYSQL_PASSWORD=your_password
export RABBITMQ_HOST=your_rabbitmq_host
export RABBITMQ_PORT=15672
export RABBITMQ_USER=your_username
export RABBITMQ_PASSWORD=your_password
EOF

# 加载配置
source /etc/profile
```

### 2. 定期任务
可以设置定期任务来自动执行备份和清理：

```bash
# 添加到crontab
# 每天凌晨2点备份MySQL数据库
0 2 * * * /apps/mysql_backup_restore.sh backup-all

# 每周日凌晨3点清理7天前的备份
0 3 * * 0 /apps/mysql_backup_restore.sh clean 7
```

### 3. 监控和告警
结合监控工具使用这些脚本的输出：

```bash
# 定期检查数据库大小
/apps/mysql_table_size_analyzer.sh summary > /tmp/db_size_report.txt

# 定期检查RabbitMQ健康状态
/apps/rabbitmq_vhost_manager.sh health > /tmp/rabbitmq_health.txt
```

## 🐛 故障排除

### 常见问题

1. **MySQL连接失败**
   - 检查环境变量是否正确设置
   - 确认MySQL服务正在运行
   - 验证网络连接和防火墙设置

2. **权限不足**
   - 确保MySQL用户有足够的权限
   - 对于RabbitMQ，确认用户有管理员权限

3. **工具找不到**
   - 确保在容器内运行
   - 检查脚本是否有执行权限：`chmod +x /apps/*.sh`

4. **输出格式问题**
   - 安装必要工具：`apt-get install bc jq`（如需要）
   - 检查终端是否支持颜色输出

### 获取帮助

```bash
# 查看工具菜单帮助
/apps/tools_menu.sh help

# 查看特定工具帮助
/apps/tools_menu.sh help mysql_backup_restore.sh

# 直接查看工具帮助
/apps/mysql_backup_restore.sh --help
```

## 📝 更新日志

### v1.0
- 初始版本发布
- 包含MySQL和RabbitMQ管理工具
- 统一的工具菜单界面
- 完整的帮助文档