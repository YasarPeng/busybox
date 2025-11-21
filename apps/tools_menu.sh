#!/bin/bash

# 工具菜单脚本
# 提供统一的工具入口和说明

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 打印标题
print_title() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                   系统管理工具集                              ║${NC}"
    echo -e "${BOLD}${CYAN}║                      v1.0                                    ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 打印分隔线
print_separator() {
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
}

# 显示帮助信息
show_help() {
    print_title
    echo -e "${BOLD}使用说明：${NC}"
    echo "  $0 [工具名] [参数...]    # 运行指定工具"
    echo "  $0 help [工具名]         # 查看指定工具的帮助"
    echo "  $0 list                 # 列出所有可用工具"
    echo "  $0 menu                 # 显示交互式菜单"
    echo ""
}

# 列出所有工具
list_tools() {
    print_title
    echo -e "${BOLD}可用工具列表：${NC}"
    echo ""

    # MySQL相关工具
    echo -e "${GREEN}📊 MySQL 数据库工具：${NC}"
    echo "  ${YELLOW}1.${NC} mysql_backup_restore.sh      MySQL备份恢复工具"
    echo "      功能：数据库备份、恢复、备份管理"
    echo "      用法：$0 mysql_backup_restore.sh help"
    echo ""
    echo "  ${YELLOW}2.${NC} mysql_read_write_test.sh     MySQL读写性能测试"
    echo "      功能：连接测试、写入测试、读取测试、压力测试"
    echo "      用法：$0 mysql_read_write_test.sh help"
    echo ""
    echo "  ${YELLOW}3.${NC} mysql_table_size_analyzer.sh MySQL表大小分析工具"
    echo "      功能：分析数据库和表大小、碎片分析、索引统计"
    echo "      用法：$0 mysql_table_size_analyzer.sh help"
    echo ""

    # RabbitMQ相关工具
    echo -e "${GREEN}🐰 RabbitMQ 消息队列工具：${NC}"
    echo "  ${YELLOW}4.${NC} rabbitmq_vhost_manager.sh    RabbitMQ虚拟主机管理"
    echo "      功能：创建/删除虚拟主机、用户管理、权限配置"
    echo "      用法：$0 rabbitmq_vhost_manager.sh help"
    echo ""

    print_separator
    echo -e "${BOLD}环境变量配置：${NC}"
    echo -e "${BLUE}MySQL相关：${NC}"
    echo "  export MYSQL_HOST=localhost        # MySQL服务器地址"
    echo "  export MYSQL_PORT=3306             # MySQL端口"
    echo "  export MYSQL_USER=root             # MySQL用户名"
    echo "  export MYSQL_PASSWORD=your_password # MySQL密码"
    echo ""
    echo -e "${BLUE}RabbitMQ相关：${NC}"
    echo "  export RABBITMQ_HOST=localhost     # RabbitMQ管理界面地址"
    echo "  export RABBITMQ_PORT=15672         # RabbitMQ管理端口"
    echo "  export RABBITMQ_USER=guest         # RabbitMQ管理员用户名"
    echo "  export RABBITMQ_PASSWORD=guest     # RabbitMQ管理员密码"
    echo ""
}

# 显示工具特定帮助
show_tool_help() {
    local tool="$1"
    local tool_path="/apps/$tool"

    if [ -f "$tool_path" ]; then
        echo -e "${BOLD}工具 '$tool' 的帮助信息：${NC}"
        echo ""
        "$tool_path" --help 2>/dev/null || "$tool_path" help 2>/dev/null || "$tool_path" -h 2>/dev/null || "$tool_path"
    else
        echo -e "${RED}错误：工具 '$tool' 不存在${NC}"
        echo ""
        echo "可用工具："
        ls -1 /apps/*.sh 2>/dev/null | xargs -n1 basename | sed 's/\.sh$//'
    fi
}

# 交互式菜单
show_interactive_menu() {
    while true; do
        clear
        print_title
        echo -e "${BOLD}请选择要使用的工具：${NC}"
        echo ""

        echo -e "${GREEN}📊 MySQL 数据库工具：${NC}"
        echo "  1) MySQL备份恢复工具"
        echo "  2) MySQL读写性能测试"
        echo "  3) MySQL表大小分析工具"
        echo ""

        echo -e "${GREEN}🐰 RabbitMQ 消息队列工具：${NC}"
        echo "  4) RabbitMQ虚拟主机管理"
        echo ""

        echo -e "${YELLOW}其他选项：${NC}"
        echo "  5) 查看环境配置示例"
        echo "  6) 工具使用说明"
        echo "  0) 退出"
        echo ""

        read -p "请输入选项 (0-6): " choice

        case $choice in
            1)
                echo ""
                echo -e "${BOLD}MySQL备份恢复工具${NC}"
                print_separator
                /apps/mysql_backup_restore.sh --help
                echo ""
                read -p "按回车键继续..."
                ;;
            2)
                echo ""
                echo -e "${BOLD}MySQL读写性能测试${NC}"
                print_separator
                /apps/mysql_read_write_test.sh --help
                echo ""
                read -p "按回车键继续..."
                ;;
            3)
                echo ""
                echo -e "${BOLD}MySQL表大小分析工具${NC}"
                print_separator
                /apps/mysql_table_size_analyzer.sh --help
                echo ""
                read -p "按回车键继续..."
                ;;
            4)
                echo ""
                echo -e "${BOLD}RabbitMQ虚拟主机管理${NC}"
                print_separator
                /apps/rabbitmq_vhost_manager.sh --help
                echo ""
                read -p "按回车键继续..."
                ;;
            5)
                echo ""
                echo -e "${BOLD}环境配置示例${NC}"
                print_separator
                echo -e "${BLUE}MySQL环境变量：${NC}"
                echo "export MYSQL_HOST=localhost"
                echo "export MYSQL_PORT=3306"
                echo "export MYSQL_USER=root"
                echo "export MYSQL_PASSWORD=your_password"
                echo ""
                echo -e "${BLUE}RabbitMQ环境变量：${NC}"
                echo "export RABBITMQ_HOST=localhost"
                echo "export RABBITMQ_PORT=15672"
                echo "export RABBITMQ_USER=guest"
                echo "export RABBITMQ_PASSWORD=guest"
                echo ""
                echo -e "${YELLOW}提示：可以将这些环境变量添加到 ~/.bashrc 或 ~/.profile 中${NC}"
                echo ""
                read -p "按回车键继续..."
                ;;
            6)
                echo ""
                echo -e "${BOLD}工具使用说明${NC}"
                print_separator
                echo -e "${CYAN}快速开始示例：${NC}"
                echo ""
                echo "1. MySQL备份恢复："
                echo "   MYSQL_PASSWORD=123456 /apps/mysql_backup_restore.sh backup mydatabase"
                echo ""
                echo "2. MySQL性能测试："
                echo "   MYSQL_PASSWORD=123456 /apps/mysql_read_write_test.sh test"
                echo ""
                echo "3. MySQL表大小分析："
                echo "   MYSQL_PASSWORD=123456 /apps/mysql_table_size_analyzer.sh"
                echo ""
                echo "4. RabbitMQ管理："
                echo "   /apps/rabbitmq_vhost_manager.sh create myapp_vhost"
                echo ""
                echo "5. 使用菜单："
                echo "   /apps/tools_menu.sh menu"
                echo ""
                read -p "按回车键继续..."
                ;;
            0)
                echo "退出工具菜单"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# 运行指定工具
run_tool() {
    local tool="$1"
    shift
    local tool_path="/apps/$tool"

    if [ -f "$tool_path" ]; then
        echo -e "${BOLD}运行工具：$tool${NC}"
        print_separator
        "$tool_path" "$@"
    else
        echo -e "${RED}错误：工具 '$tool' 不存在${NC}"
        echo ""
        echo "可用工具："
        ls -1 /apps/*.sh 2>/dev/null | xargs -n1 basename | sed 's/\.sh$//' | sed 's/^/  - /'
        exit 1
    fi
}

# 主函数
main() {
    case "$1" in
        "help"|"--help"|"-h")
            if [ -n "$2" ]; then
                show_tool_help "$2"
            else
                show_help
            fi
            ;;
        "list"|"-l"|"--list")
            list_tools
            ;;
        "menu"|"-m"|"--menu")
            show_interactive_menu
            ;;
        "")
            # 无参数时显示帮助
            show_help
            ;;
        *)
            # 运行指定工具
            run_tool "$@"
            ;;
    esac
}

main "$@"