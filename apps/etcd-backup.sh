#!/bin/bash

# etcd 数据备份脚本
# 使用方法: ./etcd-backup.sh [备份路径] [etcd端点] [其他选项]

set -e

# 默认配置
DEFAULT_ENDPOINT="http://localhost:2379"
DEFAULT_BACKUP_DIR="/apps/kubernetes/etcd-backups"
ETCDCTL_API=3

# 解析命令行参数
BACKUP_DIR=${1:-$DEFAULT_BACKUP_DIR}
ENDPOINTS=${2:-$DEFAULT_ENDPOINT}
shift 2
ETCDCTL_OPTS="$@"

# 显示帮助信息
show_help() {
    echo "etcd 数据备份脚本"
    echo ""
    echo "使用方法:"
    echo "  $0 [备份目录] [etcd端点] [其他etcdctl选项]"
    echo ""
    echo "参数说明:"
    echo "  备份目录    备份文件保存目录 (默认: $DEFAULT_BACKUP_DIR)"
    echo "  etcd端点    etcd服务端点 (默认: $DEFAULT_ENDPOINT)"
    echo "  其他选项    传递给etcdctl的其他选项"
    echo ""
    echo "环境变量:"
    echo "  ETCDCTL_CACERT        CA证书文件路径"
    echo "  ETCDCTL_CERT          客户端证书文件路径"
    echo "  ETCDCTL_KEY           客户端私钥文件路径"
    echo "  ETCDCTL_ENDPOINTS     etcd端点列表"
    echo ""
    echo "示例:"
    echo "  # 基本备份"
    echo "  $0 /backup etcd.example.com:2379"
    echo ""
    echo "  # 使用TLS连接"
    echo "  ETCDCTL_CACERT=/etc/ssl/etcd/ca.crt \\"
    echo "  ETCDCTL_CERT=/etc/ssl/etcd/client.crt \\"
    echo "  ETCDCTL_KEY=/etc/ssl/etcd/client.key \\"
    echo "  $0 /backup etcd.example.com:2379"
    echo ""
    echo "  # 指定命名空间备份"
    echo "  $0 /backup etcd.example.com:2379 --prefix=/myapp/"
}

# 检查etcdctl是否可用
check_etcdctl() {
    if ! command -v etcdctl &> /dev/null; then
        echo "错误: etcdctl 命令未找到，请确保已安装 etcdctl"
        exit 1
    fi
}

# 创建备份目录
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        echo "创建备份目录: $BACKUP_DIR"
    fi
}

# 检查etcd连接
check_etcd_connection() {
    echo "检查etcd连接: $ENDPOINTS"
    
    # 设置环境变量
    export ETCDCTL_API=$ETCDCTL_API
    export ETCDCTL_ENDPOINTS=$ENDPOINTS
    
    if [ -n "$ETCDCTL_CACERT" ]; then
        export ETCDCTL_CACERT="$ETCDCTL_CACERT"
    fi
    if [ -n "$ETCDCTL_CERT" ]; then
        export ETCDCTL_CERT="$ETCDCTL_CERT"
    fi
    if [ -n "$ETCDCTL_KEY" ]; then
        export ETCDCTL_KEY="$ETCDCTL_KEY"
    fi
    
    # 测试连接
    if ! etcdctl endpoint health $ETCDCTL_OPTS &>/dev/null; then
        echo "错误: 无法连接到etcd服务器: $ENDPOINTS"
        echo "请检查:"
        echo "  1. etcd服务是否运行"
        echo "  2. 端点地址是否正确"
        echo "  3. 网络连接是否正常"
        echo "  4. TLS证书配置是否正确"
        exit 1
    fi
    
    echo "✓ etcd连接正常"
}

# 获取etcd版本和集群信息
get_etcd_info() {
    echo "获取etcd集群信息..."
    echo "ETCD版本: $(etcdctl version $ETCDCTL_OPTS | grep 'etcdctl' | awk '{print $2}' | tr -d ',')"
    echo "集群状态:"
    etcdctl endpoint status $ETCDCTL_OPTS --write-out=table 2>/dev/null || echo "无法获取详细状态信息"
    echo ""
}

# 执行备份
perform_backup() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/etcd-backup-$timestamp.db"
    
    echo "开始备份etcd数据..."
    echo "备份文件: $backup_file"
    
    # 执行备份命令
    if etcdctl snapshot save "$backup_file" $ETCDCTL_OPTS; then
        echo "✓ 备份完成: $backup_file"
        
        # 获取备份文件大小
        local file_size=$(ls -lh "$backup_file" | awk '{print $5}')
        echo "文件大小: $file_size"
        
        # 验证备份文件
        echo "验证备份文件..."
        if etcdctl snapshot status "$backup_file" --write-out=table $ETCDCTL_OPTS; then
            echo "✓ 备份文件验证成功"
        else
            echo "⚠ 备份文件验证失败，但文件已创建"
        fi
    else
        echo "✗ 备份失败"
        rm -f "$backup_file"
        exit 1
    fi
}

# 清理旧备份（保留最近10个）
cleanup_old_backups() {
    echo "清理旧备份文件..."
    local backup_count=$(ls -1 "$BACKUP_DIR"/etcd-backup-*.db 2>/dev/null | wc -l)
    
    if [ "$backup_count" -gt 10 ]; then
        echo "当前备份数量: $backup_count，保留最新10个"
        ls -1t "$BACKUP_DIR"/etcd-backup-*.db | tail -n +11 | xargs -r rm -f
        echo "✓ 清理完成"
    else
        echo "当前备份数量: $backup_count，无需清理"
    fi
}

# 显示备份列表
show_backup_list() {
    echo ""
    echo "当前备份文件列表:"
    if [ -n "$(ls -A "$BACKUP_DIR"/etcd-backup-*.db 2>/dev/null)" ]; then
        ls -lh "$BACKUP_DIR"/etcd-backup-*.db | awk '{printf "%-30s %s %s %s\n", $9, $5, $6, $7}'
    else
        echo "  (无备份文件)"
    fi
}

# 主函数
main() {
    # 检查参数
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    echo "=== etcd 数据备份工具 ==="
    echo "备份目录: $BACKUP_DIR"
    echo "etcd端点: $ENDPOINTS"
    echo ""
    
    check_etcdctl
    create_backup_dir
    check_etcd_connection
    get_etcd_info
    perform_backup
    cleanup_old_backups
    show_backup_list
    
    echo ""
    echo "备份完成！"
    echo ""
    echo "恢复数据使用命令:"
    echo "  etcdctl snapshot restore <备份文件路径> $ETCDCTL_OPTS"
}

# 执行主函数
main "$@"