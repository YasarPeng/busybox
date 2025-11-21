#!/bin/bash

# RabbitMQ虚拟主机管理脚本
# 支持创建、删除、列出虚拟主机以及配置用户权限

set -e

# 配置变量
RABBITMQ_HOST="${RABBITMQ_HOST:-localhost}"
RABBITMQ_PORT="${RABBITMQ_PORT:-15672}"
RABBITMQ_USER="${RABBITMQ_USER:-guest}"
RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD:-guest}"
RABBITMQ_CLI_HOST="${RABBITMQ_CLI_HOST:-localhost}"
RABBITMQ_CLI_PORT="${RABBITMQ_CLI_PORT:-5672}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印帮助信息
show_help() {
    echo "RabbitMQ虚拟主机管理工具"
    echo ""
    echo "用法:"
    echo "  $0 create <vhost_name>                           # 创建虚拟主机"
    echo "  $0 delete <vhost_name>                           # 删除虚拟主机"
    echo "  $0 list                                          # 列出所有虚拟主机"
    echo "  $0 info <vhost_name>                            # 查看虚拟主机信息"
    echo "  $0 set-permissions <vhost_name> <username>      # 设置用户权限"
    echo "  $0 set-tags <username> <tag>                    # 设置用户标签"
    echo "  $0 create-user <username> <password> [tag]      # 创建用户"
    echo "  $0 delete-user <username>                       # 删除用户"
    echo "  $0 list-users                                    # 列出所有用户"
    echo "  $0 enable-feature <feature>                     # 启用插件"
    echo "  $0 disable-feature <feature>                    # 禁用插件"
    echo "  $0 list-features                                # 列出所有插件"
    echo "  $0 health                                       # 检查RabbitMQ健康状态"
    echo ""
    echo "环境变量:"
    echo "  RABBITMQ_HOST     管理界面地址 (默认: localhost)"
    echo "  RABBITMQ_PORT     管理界面端口 (默认: 15672)"
    echo "  RABBITMQ_USER     管理员用户名 (默认: guest)"
    echo "  RABBITMQ_PASSWORD 管理员密码 (默认: guest)"
    echo "  RABBITMQ_CLI_HOST RabbitMQ服务地址 (默认: localhost)"
    echo "  RABBITMQ_CLI_PORT RabbitMQ服务端口 (默认: 5672)"
    echo ""
    echo "示例:"
    echo "  $0 create myapp_vhost"
    echo "  $0 set-permissions myapp_vhost myapp_user"
    echo "  $0 create-user myapp_user myapp_password management"
    echo "  RABBITMQ_PASSWORD=admin123 $0 create production_vhost"
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

# 检查RabbitMQ连接
check_rabbitmq_connection() {
    log "检查RabbitMQ连接..."

    # 使用rabbitmqctl检查连接
    if ! rabbitmqctl -n "$RABBITMQ_CLI_HOST" status >/dev/null 2>&1; then
        warn "使用rabbitmqctl连接失败，尝试使用HTTP API..."

        # 使用HTTP API检查连接
        if ! curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASSWORD" \
            "http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/overview" >/dev/null 2>&1; then
            error "无法连接到RabbitMQ服务器，请检查连接参数"
        fi
    fi

    log "RabbitMQ连接正常"
}

# 创建虚拟主机
create_vhost() {
    local vhost_name="$1"

    if [ -z "$vhost_name" ]; then
        error "请指定虚拟主机名称"
    fi

    log "创建虚拟主机: $vhost_name"
    check_rabbitmq_connection

    # 检查虚拟主机是否已存在
    if rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_vhosts | grep -q "^$vhost_name$"; then
        warn "虚拟主机 '$vhost_name' 已存在"
        return
    fi

    # 创建虚拟主机
    if rabbitmqctl -n "$RABBITMQ_CLI_HOST" add_vhost "$vhost_name"; then
        log "虚拟主机 '$vhost_name' 创建成功"
    else
        error "虚拟主机 '$vhost_name' 创建失败"
    fi
}

# 删除虚拟主机
delete_vhost() {
    local vhost_name="$1"

    if [ -z "$vhost_name" ]; then
        error "请指定虚拟主机名称"
    fi

    log "删除虚拟主机: $vhost_name"
    check_rabbitmq_connection

    # 检查虚拟主机是否存在
    if ! rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_vhosts | grep -q "^$vhost_name$"; then
        error "虚拟主机 '$vhost_name' 不存在"
    fi

    # 确认删除
    read -p "确认删除虚拟主机 '$vhost_name' 吗? 这将删除其中的所有队列和交换机 (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "操作已取消"
        return
    fi

    # 删除虚拟主机
    if rabbitmqctl -n "$RABBITMQ_CLI_HOST" delete_vhost "$vhost_name"; then
        log "虚拟主机 '$vhost_name' 删除成功"
    else
        error "虚拟主机 '$vhost_name' 删除失败"
    fi
}

# 列出虚拟主机
list_vhosts() {
    log "RabbitMQ虚拟主机列表:"
    echo ""

    check_rabbitmq_connection

    printf "%-20s %-15s %-10s %-20s\n" "虚拟主机" "队列数量" "连接数" "消息总数"
    printf "%-20s %-15s %-10s %-20s\n" "--------------------" "---------------" "----------" "--------------------"

    rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_vhosts name | while read -r vhost; do
        if [ -n "$vhost" ]; then
            # 获取虚拟主机统计信息
            local queue_count=$(curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASSWORD" \
                "http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/queues/$vhost" | \
                jq 'length' 2>/dev/null || echo "0")

            local connection_count=$(curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASSWORD" \
                "http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/connections" | \
                jq "[.[] | select(.vhost==\"$vhost\")] | length" 2>/dev/null || echo "0")

            local message_count=$(curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASSWORD" \
                "http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/queues/$vhost" | \
                jq "[.[] | .messages] | add" 2>/dev/null || echo "0")

            printf "%-20s %-15s %-10s %-20s\n" "$vhost" "$queue_count" "$connection_count" "$message_count"
        fi
    done
}

# 查看虚拟主机信息
show_vhost_info() {
    local vhost_name="$1"

    if [ -z "$vhost_name" ]; then
        error "请指定虚拟主机名称"
    fi

    log "虚拟主机 '$vhost_name' 详细信息:"
    echo ""

    check_rabbitmq_connection

    # 检查虚拟主机是否存在
    if ! rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_vhosts | grep -q "^$vhost_name$"; then
        error "虚拟主机 '$vhost_name' 不存在"
    fi

    # 获取基本信息
    echo "=== 基本信息 ==="
    rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_vhosts name tracing | grep "^$vhost_name"

    echo ""
    echo "=== 权限信息 ==="
    printf "%-15s %-10s %-10s %-10s\n" "用户名" "配置权限" "写权限" "读权限"
    printf "%-15s %-10s %-10s %-10s\n" "---------------" "----------" "----------" "----------"
    rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_permissions -p "$vhost_name" user configure write read | \
    while read -r user configure write read; do
        printf "%-15s %-10s %-10s %-10s\n" "$user" "$configure" "$write" "$read"
    done

    echo ""
    echo "=== 队列信息 ==="
    printf "%-25s %-10s %-10s %-15s\n" "队列名" "消息数" "消费者数" "状态"
    printf "%-25s %-10s %-10s %-15s\n" "-------------------------" "----------" "----------" "---------------"

    if command -v jq >/dev/null 2>&1; then
        curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASSWORD" \
            "http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/queues/$vhost_name" | \
        jq -r '.[] | "\(.name) \(.messages) \(.consumers) \(.state)"' 2>/dev/null | \
        while read -r name messages consumers state; do
            printf "%-25s %-10s %-10s %-15s\n" "$name" "$messages" "$consumers" "$state"
        done
    else
        warn "需要安装jq工具来显示详细队列信息"
        rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_queues -p "$vhost_name" name messages consumers state
    fi
}

# 设置用户权限
set_permissions() {
    local vhost_name="$1"
    local username="$2"
    local configure="${3:-.*}"
    local write="${4:-.*}"
    local read="${5:-.*}"

    if [ -z "$vhost_name" ] || [ -z "$username" ]; then
        error "请指定虚拟主机名称和用户名"
    fi

    log "为用户 '$username' 设置虚拟主机 '$vhost_name' 权限"
    check_rabbitmq_connection

    # 检查虚拟主机和用户是否存在
    if ! rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_vhosts | grep -q "^$vhost_name$"; then
        error "虚拟主机 '$vhost_name' 不存在"
    fi

    if ! rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_users | grep -q "^$username$"; then
        error "用户 '$username' 不存在"
    fi

    # 设置权限
    if rabbitmqctl -n "$RABBITMQ_CLI_HOST" set_permissions -p "$vhost_name" "$username" "$configure" "$write" "$read"; then
        log "权限设置成功"
        echo "用户: $username"
        echo "虚拟主机: $vhost_name"
        echo "配置权限: $configure"
        echo "写权限: $write"
        echo "读权限: $read"
    else
        error "权限设置失败"
    fi
}

# 设置用户标签
set_user_tags() {
    local username="$1"
    local tag="$2"

    if [ -z "$username" ] || [ -z "$tag" ]; then
        error "请指定用户名和标签"
    fi

    log "为用户 '$username' 设置标签: $tag"
    check_rabbitmq_connection

    if ! rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_users | grep -q "^$username$"; then
        error "用户 '$username' 不存在"
    fi

    if rabbitmqctl -n "$RABBITMQ_CLI_HOST" set_user_tags "$username" "$tag"; then
        log "用户标签设置成功"
    else
        error "用户标签设置失败"
    fi
}

# 创建用户
create_user() {
    local username="$1"
    local password="$2"
    local tag="$3"

    if [ -z "$username" ] || [ -z "$password" ]; then
        error "请指定用户名和密码"
    fi

    log "创建用户: $username"
    check_rabbitmq_connection

    # 检查用户是否已存在
    if rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_users | grep -q "^$username$"; then
        warn "用户 '$username' 已存在"
        return
    fi

    # 创建用户
    if rabbitmqctl -n "$RABBITMQ_CLI_HOST" add_user "$username" "$password"; then
        log "用户 '$username' 创建成功"

        # 如果指定了标签，设置标签
        if [ -n "$tag" ]; then
            rabbitmqctl -n "$RABBITMQ_CLI_HOST" set_user_tags "$username" "$tag"
            log "用户标签已设置为: $tag"
        fi
    else
        error "用户 '$username' 创建失败"
    fi
}

# 删除用户
delete_user() {
    local username="$1"

    if [ -z "$username" ]; then
        error "请指定用户名"
    fi

    log "删除用户: $username"
    check_rabbitmq_connection

    if ! rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_users | grep -q "^$username$"; then
        error "用户 '$username' 不存在"
    fi

    read -p "确认删除用户 '$username' 吗? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "操作已取消"
        return
    fi

    if rabbitmqctl -n "$RABBITMQ_CLI_HOST" delete_user "$username"; then
        log "用户 '$username' 删除成功"
    else
        error "用户 '$username' 删除失败"
    fi
}

# 列出用户
list_users() {
    log "RabbitMQ用户列表:"
    echo ""

    check_rabbitmq_connection

    printf "%-15s %-15s %-20s\n" "用户名" "标签" "权限数量"
    printf "%-15s %-15s %-20s\n" "---------------" "---------------" "--------------------"

    rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_users name tags | while read -r username tags; do
        if [ -n "$username" ]; then
            local permission_count=$(rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_user_permissions "$username" | wc -l | tr -d ' ')
            printf "%-15s %-15s %-20s\n" "$username" "$tags" "$permission_count"
        fi
    done
}

# 启用插件
enable_feature() {
    local feature="$1"

    if [ -z "$feature" ]; then
        error "请指定插件名称"
    fi

    log "启用RabbitMQ插件: $feature"
    check_rabbitmq_connection

    if rabbitmq-plugins enable "$feature"; then
        log "插件 '$feature' 启用成功"
    else
        error "插件 '$feature' 启用失败"
    fi
}

# 禁用插件
disable_feature() {
    local feature="$1"

    if [ -z "$feature" ]; then
        error "请指定插件名称"
    fi

    log "禁用RabbitMQ插件: $feature"
    check_rabbitmq_connection

    if rabbitmq-plugins disable "$feature"; then
        log "插件 '$feature' 禁用成功"
    else
        error "插件 '$feature' 禁用失败"
    fi
}

# 列出插件
list_features() {
    log "RabbitMQ插件列表:"
    echo ""

    check_rabbitmq_connection

    printf "%-25s %-10s %-50s\n" "插件名" "状态" "描述"
    printf "%-25s %-10s %-50s\n" "-------------------------" "----------" "--------------------------------------------------"

    rabbitmq-plugins list | grep -E "^\[E\]|\[e\]|\[\*\]" | while read -r line; do
        local plugin=$(echo "$line" | sed 's/^\[.\] *\([^ ]*\).*/\1/')
        local status=$(echo "$line" | sed 's/^\[\(.\)\].*/\1/')
        local description=$(echo "$line" | sed 's/^\[.\] *[^ ]* *//')

        case $status in
            "E") status_text="启用" ;;
            "e") status_text="显式启用" ;;
            "*") status_text="隐式启用" ;;
            *) status_text="禁用" ;;
        esac

        printf "%-25s %-10s %-50s\n" "$plugin" "$status_text" "$description"
    done
}

# 健康检查
health_check() {
    log "检查RabbitMQ健康状态..."
    echo ""

    # 检查服务状态
    echo "=== 服务状态 ==="
    if rabbitmqctl -n "$RABBITMQ_CLI_HOST" status >/dev/null 2>&1; then
        log "RabbitMQ服务运行正常"
    else
        error "RabbitMQ服务异常"
    fi

    # 检查集群状态
    echo ""
    echo "=== 集群状态 ==="
    rabbitmqctl -n "$RABBITMQ_CLI_HOST" cluster_status

    # 检查连接数
    echo ""
    echo "=== 连接信息 ==="
    local connection_count=$(rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_connections | wc -l | tr -d ' ')
    echo "当前连接数: $connection_count"

    # 检查队列和消息
    echo ""
    echo "=== 队列和消息统计 ==="
    local queue_count=$(rabbitmqctl -n "$RABBITMQ_CLI_HOST" list_queues | wc -l | tr -d ' ')
    echo "队列总数: $queue_count"

    if command -v jq >/dev/null 2>&1; then
        local total_messages=$(curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASSWORD" \
            "http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/queues" | \
            jq "[.[] | .messages] | add" 2>/dev/null || echo "0")
        echo "消息总数: $total_messages"
    fi

    # 检查内存使用
    echo ""
    echo "=== 内存使用 ==="
    rabbitmqctl -n "$RABBITMQ_CLI_HOST" status | grep -A 5 "{memory,"
}

# 主函数
main() {
    case "$1" in
        "create")
            create_vhost "$2"
            ;;
        "delete")
            delete_vhost "$2"
            ;;
        "list")
            list_vhosts
            ;;
        "info")
            show_vhost_info "$2"
            ;;
        "set-permissions")
            set_permissions "$2" "$3" "$4" "$5" "$6"
            ;;
        "set-tags")
            set_user_tags "$2" "$3"
            ;;
        "create-user")
            create_user "$2" "$3" "$4"
            ;;
        "delete-user")
            delete_user "$2"
            ;;
        "list-users")
            list_users
            ;;
        "enable-feature")
            enable_feature "$2"
            ;;
        "disable-feature")
            disable_feature "$2"
            ;;
        "list-features")
            list_features
            ;;
        "health")
            health_check
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