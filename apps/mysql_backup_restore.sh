#!/bin/bash

# MySQL备份恢复脚本
# 支持数据库备份、恢复和备份文件管理

set -e

# 配置变量
MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
BACKUP_DIR="${BACKUP_DIR:-./mysql_backups}"
DATE_FORMAT=$(date +"%Y%m%d_%H%M%S")

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印帮助信息
show_help() {
    echo "MySQL备份恢复工具"
    echo ""
    echo "用法:"
    echo "  $0 backup [数据库名]                    # 备份指定数据库"
    echo "  $0 backup-all                          # 备份所有数据库"
    echo "  $0 restore [数据库名] [备份文件]        # 恢复数据库"
    echo "  $0 list                                # 列出所有备份文件"
    echo "  $0 delete [数据库名] [备份文件]        # 删除指定备份"
    echo "  $0 clean [天数]                        # 清理N天前的备份"
    echo ""
    echo "环境变量:"
    echo "  MYSQL_HOST     MySQL服务器地址 (默认: localhost)"
    echo "  MYSQL_PORT     MySQL端口 (默认: 3306)"
    echo "  MYSQL_USER     MySQL用户名 (默认: root)"
    echo "  MYSQL_PASSWORD MySQL密码"
    echo "  BACKUP_DIR     备份目录 (默认: ./mysql_backups)"
    echo ""
    echo "示例:"
    echo "  MYSQL_PASSWORD=123456 $0 backup myapp"
    echo "  MYSQL_PASSWORD=123456 $0 restore myapp ./backups/myapp_20231201_120000.sql"
    echo "  MYSQL_PASSWORD=123456 $0 clean 7"
}

# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# 检查MySQL连接
check_mysql_connection() {
    log "检查MySQL连接..."
    if ! mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; then
        error "无法连接到MySQL服务器，请检查连接参数"
    fi
    log "MySQL连接正常"
}

# 创建备份目录
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log "创建备份目录: $BACKUP_DIR"
    fi
}

# 备份单个数据库
backup_database() {
    local db_name="$1"

    if [ -z "$db_name" ]; then
        error "请指定数据库名"
    fi

    log "开始备份数据库: $db_name"
    check_mysql_connection
    create_backup_dir

    # 检查数据库是否存在
    if ! mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "USE $db_name;" 2>/dev/null; then
        error "数据库 '$db_name' 不存在"
    fi

    local backup_file="$BACKUP_DIR/${db_name}_${DATE_FORMAT}.sql"
    local compressed_file="$backup_file.gz"

    # 执行备份
    log "正在备份到: $backup_file"
    mysqldump -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --hex-blob \
        --default-character-set=utf8mb4 \
        "$db_name" > "$backup_file"

    # 压缩备份文件
    gzip "$backup_file"
    local file_size=$(du -h "$compressed_file" | cut -f1)

    log "数据库 '$db_name' 备份完成: $compressed_file (大小: $file_size)"
}

# 备份所有数据库
backup_all_databases() {
    log "开始备份所有数据库"
    check_mysql_connection
    create_backup_dir

    local backup_file="$BACKUP_DIR/all_databases_${DATE_FORMAT}.sql"
    local compressed_file="$backup_file.gz"

    # 执行全量备份
    log "正在备份所有数据库到: $backup_file"
    mysqldump -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --hex-blob \
        --default-character-set=utf8mb4 \
        --all-databases > "$backup_file"

    # 压缩备份文件
    gzip "$backup_file"
    local file_size=$(du -h "$compressed_file" | cut -f1)

    log "所有数据库备份完成: $compressed_file (大小: $file_size)"
}

# 恢复数据库
restore_database() {
    local db_name="$1"
    local backup_file="$2"

    if [ -z "$db_name" ] || [ -z "$backup_file" ]; then
        error "请指定数据库名和备份文件路径"
    fi

    # 如果是压缩文件，先解压
    if [[ "$backup_file" == *.gz ]]; then
        local temp_file="${backup_file%.gz}"
        log "解压备份文件: $backup_file"
        gunzip -c "$backup_file" > "$temp_file"
        backup_file="$temp_file"
    fi

    if [ ! -f "$backup_file" ]; then
        error "备份文件不存在: $backup_file"
    fi

    log "开始恢复数据库: $db_name"
    check_mysql_connection

    # 创建数据库（如果不存在）
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -e "CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

    # 执行恢复
    log "正在从 $backup_file 恢复数据"
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$db_name" < "$backup_file"

    log "数据库 '$db_name' 恢复完成"

    # 清理临时解压文件
    if [[ "$backup_file" == *.sql.tmp ]]; then
        rm -f "$backup_file"
    fi
}

# 列出备份文件
list_backups() {
    log "备份文件列表:"
    echo ""

    if [ ! -d "$BACKUP_DIR" ]; then
        warn "备份目录不存在: $BACKUP_DIR"
        return
    fi

    printf "%-30s %-15s %-20s\n" "文件名" "大小" "创建时间"
    printf "%-30s %-15s %-20s\n" "----------------------------------" "---------------" "--------------------"

    find "$BACKUP_DIR" -name "*.sql.gz" -o -name "*.sql" | while read -r file; do
        local filename=$(basename "$file")
        local filesize=$(du -h "$file" | cut -f1)
        local filedate=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1)
        printf "%-30s %-15s %-20s\n" "$filename" "$filesize" "$filedate"
    done
}

# 删除备份文件
delete_backup() {
    local db_name="$1"
    local backup_file="$2"

    if [ -z "$db_name" ] || [ -z "$backup_file" ]; then
        error "请指定数据库名和备份文件名"
    fi

    local full_path="$BACKUP_DIR/$backup_file"

    if [ ! -f "$full_path" ]; then
        # 尝试匹配数据库相关的备份文件
        local matched_files=$(find "$BACKUP_DIR" -name "${db_name}*${backup_file}*" 2>/dev/null)
        if [ -z "$matched_files" ]; then
            error "找不到匹配的备份文件: $backup_file"
        fi
        echo "找到匹配的备份文件:"
        echo "$matched_files"
        read -p "确认删除这些文件吗? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "$matched_files" | xargs rm -f
            log "备份文件已删除"
        fi
    else
        rm -f "$full_path"
        log "备份文件已删除: $backup_file"
    fi
}

# 清理旧备份
clean_old_backups() {
    local days="$1"

    if [ -z "$days" ]; then
        error "请指定要清理的天数"
    fi

    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        error "天数必须是数字"
    fi

    log "清理 $days 天前的备份文件"

    if [ ! -d "$BACKUP_DIR" ]; then
        warn "备份目录不存在: $BACKUP_DIR"
        return
    fi

    local deleted_count=0
    find "$BACKUP_DIR" -name "*.sql.gz" -o -name "*.sql" -type f -mtime +$days | while read -r file; do
        log "删除旧备份: $(basename "$file")"
        rm -f "$file"
        ((deleted_count++))
    done

    log "清理完成，共删除了 $deleted_count 个旧备份文件"
}

# 主函数
main() {
    case "$1" in
        "backup")
            backup_database "$2"
            ;;
        "backup-all")
            backup_all_databases
            ;;
        "restore")
            restore_database "$2" "$3"
            ;;
        "list")
            list_backups
            ;;
        "delete")
            delete_backup "$2" "$3"
            ;;
        "clean")
            clean_old_backups "$2"
            ;;
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        *)
            error "未知命令: $1。使用 '$0 help' 查看帮助信息"
            ;;
    esac
}

main "$@"