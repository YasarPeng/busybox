#!/bin/bash

# etcd 数据恢复脚本
# 使用方法: ./etcd-restore.sh <备份文件路径> [数据目录] [其他选项]

set -e

# 默认配置
DEFAULT_DATA_DIR="/var/lib/etcd-data"

# 显示帮助信息
show_help() {
    echo "etcd 数据恢复脚本"
    echo ""
    echo "使用方法:"
    echo "  $0 <备份文件路径> [数据目录] [其他选项]"
    echo ""
    echo "参数说明:"
    echo "  备份文件路径    要恢复的备份文件路径"
    echo "  数据目录        etcd数据目录 (默认: $DEFAULT_DATA_DIR)"
    echo "  其他选项        传递给etcdctl的其他选项"
    echo ""
    echo "注意事项:"
    echo "  1. 恢复操作会覆盖目标数据目录，请确保目录可写"
    echo "  2. 恢复前建议备份当前数据"
    echo "  3. 确保etcd服务已停止"
    echo ""
    echo "示例:"
    echo "  $0 /tmp/etcd-backup-20240101_120000.db"
    echo "  $0 /backup/etcd-backup.db /new-etcd-data"
}

# 检查etcdctl是否可用
check_etcdctl() {
    if ! command -v etcdctl &> /dev/null; then
        echo "错误: etcdctl 命令未找到，请确保已安装 etcdctl"
        exit 1
    fi
}

# 验证备份文件
validate_backup_file() {
    local backup_file="$1"

    if [ ! -f "$backup_file" ]; then
        echo "错误: 备份文件不存在: $backup_file"
        exit 1
    fi

    echo "验证备份文件: $backup_file"
    if etcdctl snapshot status "$backup_file" --write-out=table $ETCDCTL_OPTS 2>/dev/null; then
        echo "✓ 备份文件有效"
    else
        echo "✗ 备份文件无效或已损坏"
        exit 1
    fi

    # 显示文件信息
    local file_size=$(ls -lh "$backup_file" | awk '{print $5}')
    echo "文件大小: $file_size"
}

# 准备数据目录
prepare_data_dir() {
    local data_dir="$1"

    if [ -z "$data_dir" ]; then
        data_dir="$DEFAULT_DATA_DIR"
    fi

    if [ -d "$data_dir" ]; then
        echo "警告: 数据目录已存在: $data_dir"
        read -p "是否要继续？这将覆盖现有数据 (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "操作已取消"
            exit 1
        fi

        # 备份现有数据
        local backup_dir="${data_dir}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "备份现有数据到: $backup_dir"
        mv "$data_dir" "$backup_dir"
    fi

    mkdir -p "$data_dir"
    echo "数据目录: $data_dir"

    echo "$data_dir"
}

# 执行恢复
perform_restore() {
    local backup_file="$1"
    local data_dir="$2"

    echo "开始恢复etcd数据..."
    echo "从: $backup_file"
    echo "到: $data_dir"

    # 执行恢复命令
    if etcdctl snapshot restore "$backup_file" --data-dir "$data_dir" $ETCDCTL_OPTS; then
        echo "✓ 数据恢复完成"
    else
        echo "✗ 数据恢复失败"
        exit 1
    fi

    # 设置权限
    chmod -R 755 "$data_dir"
    echo "✓ 设置目录权限完成"
}

# 显示恢复后信息
show_restore_info() {
    local data_dir="$1"

    echo ""
    echo "=== 恢复完成 ==="
    echo "数据目录: $data_dir"
    echo ""
    echo "启动etcd服务器命令:"
    echo "  etcd --data-dir $data_dir [其他选项]"
    echo ""
    echo "或者使用systemd服务:"
    echo "  sudo systemctl start etcd"
    echo ""
    echo "注意事项:"
    echo "  1. 确保etcd配置文件中的数据目录指向恢复后的目录"
    echo "  2. 如果是集群环境，所有节点都需要使用相同的备份数据"
    echo "  3. 启动前检查端口和防火墙配置"
}

# 主函数
main() {
    if [[ "$1" == "-h" || "$1" == "--help" || $# -lt 1 ]]; then
        show_help
        exit 1
    fi

    local backup_file="$1"
    local data_dir="${2:-$DEFAULT_DATA_DIR}"
    shift 2
    ETCDCTL_OPTS="$@"

    echo "=== etcd 数据恢复工具 ==="
    echo ""

    check_etcdctl
    validate_backup_file "$backup_file"
    data_dir=$(prepare_data_dir "$data_dir")
    perform_restore "$backup_file" "$data_dir"
    show_restore_info "$data_dir"
}

# 执行主函数
main "$@"