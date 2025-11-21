#!/bin/bash

# MySQL数据库表大小分析脚本
# 用于查询和分析MySQL数据库中各个库、表的大小使用情况

set -e

# 配置变量
MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
SORT_BY="${SORT_BY:-size}"  # size, rows, name
ORDER="${ORDER:-desc}"      # asc, desc
OUTPUT_FORMAT="${OUTPUT_FORMAT:-table}"  # table, csv, json

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 单位转换
convert_size() {
    local size=$1
    if [ "$size" -ge 1073741824 ]; then
        echo "$(echo "scale=2; $size / 1073741824" | bc -l) GB"
    elif [ "$size" -ge 1048576 ]; then
        echo "$(echo "scale=2; $size / 1048576" | bc -l) MB"
    elif [ "$size" -ge 1024 ]; then
        echo "$(echo "scale=2; $size / 1024" | bc -l) KB"
    else
        echo "$size B"
    fi
}

# 打印帮助信息
show_help() {
    echo "MySQL数据库表大小分析工具"
    echo ""
    echo "用法:"
    echo "  $0                                        # 显示所有数据库大小概览"
    echo "  $0 database <数据库名>                    # 显示指定数据库的所有表大小"
    echo "  $0 top <数量>                            # 显示最大的N个表"
    echo "  $0 empty                                  # 显示空表"
    echo "  $0 large [阈值MB]                        # 显示大表(默认>100MB)"
    echo "  $0 indexes                               # 显示索引使用情况"
    echo "  $0 fragmentation                         # 显示表碎片情况"
    echo "  $0 engines                               # 显示各存储引擎使用情况"
    echo "  $0 summary                               # 显示详细汇总报告"
    echo "  $0 export [格式] <文件名>                # 导出结果到文件"
    echo ""
    echo "环境变量:"
    echo "  MYSQL_HOST     MySQL服务器地址 (默认: localhost)"
    echo "  MYSQL_PORT     MySQL端口 (默认: 3306)"
    echo "  MYSQL_USER     MySQL用户名 (默认: root)"
    echo "  MYSQL_PASSWORD MySQL密码"
    echo "  SORT_BY        排序字段: size, rows, name (默认: size)"
    echo "  ORDER          排序方向: asc, desc (默认: desc)"
    echo "  OUTPUT_FORMAT  输出格式: table, csv, json (默认: table)"
    echo ""
    echo "示例:"
    echo "  MYSQL_PASSWORD=123456 $0"
    echo "  MYSQL_PASSWORD=123456 $0 database myapp"
    echo "  MYSQL_PASSWORD=123456 $0 top 20"
    echo "  MYSQL_PASSWORD=123456 $0 large 500"
    echo "  SORT_BY=rows ORDER=desc MYSQL_PASSWORD=123456 $0"
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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# 检查MySQL连接
check_mysql_connection() {
    log "检查MySQL连接..."
    if ! mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; then
        error "无法连接到MySQL服务器，请检查连接参数"
    fi
    log "MySQL连接正常"
}

# 获取排序SQL
get_sort_sql() {
    case "$SORT_BY" in
        "size")
            echo "ORDER BY total_size $ORDER"
            ;;
        "rows")
            echo "ORDER BY table_rows $ORDER"
            ;;
        "name")
            echo "ORDER BY table_name $ORDER"
            ;;
        *)
            echo "ORDER BY total_size $ORDER"
            ;;
    esac
}

# 显示所有数据库大小概览
show_database_overview() {
    log "获取数据库大小概览..."
    check_mysql_connection

    local sql="
    SELECT
        SCHEMA_NAME as '数据库',
        ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as '总大小(MB)',
        ROUND(SUM(DATA_LENGTH) / 1024 / 1024, 2) as '数据大小(MB)',
        ROUND(SUM(INDEX_LENGTH) / 1024 / 1024, 2) as '索引大小(MB)',
        COUNT(TABLE_NAME) as '表数量',
        ROUND(AVG(TABLE_ROWS), 0) as '平均行数'
    FROM information_schema.TABLES
    WHERE SCHEMA_NAME NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    GROUP BY SCHEMA_NAME
    $(get_sort_sql);
    "

    echo -e "${CYAN}=== 数据库大小概览 ===${NC}"
    echo ""

    if [ "$OUTPUT_FORMAT" = "csv" ]; then
        mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$sql" | sed 's/\t/,/g'
    elif [ "$OUTPUT_FORMAT" = "json" ]; then
        if command -v jq >/dev/null 2>&1; then
            mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$sql" --json | jq .
        else
            warn "需要安装jq工具来输出JSON格式，切换到表格格式"
            mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$sql"
        fi
    else
        mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$sql"
    fi
}

# 显示指定数据库的所有表大小
show_database_tables() {
    local database="$1"

    if [ -z "$database" ]; then
        error "请指定数据库名"
    fi

    log "获取数据库 '$database' 的表大小详情..."
    check_mysql_connection

    # 检查数据库是否存在
    if ! mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "USE $database;" 2>/dev/null; then
        error "数据库 '$database' 不存在"
    fi

    local sql="
    SELECT
        TABLE_NAME as '表名',
        ENGINE as '存储引擎',
        ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) as '总大小(MB)',
        ROUND((DATA_LENGTH / 1024 / 1024), 2) as '数据大小(MB)',
        ROUND((INDEX_LENGTH / 1024 / 1024), 2) as '索引大小(MB)',
        TABLE_ROWS as '行数',
        ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / NULLIF(TABLE_ROWS, 0)), 4) as '平均行大小(KB)',
        TABLE_COLLATION as '字符集'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = '$database'
    $(get_sort_sql);
    "

    echo -e "${CYAN}=== 数据库 '$database' 表大小详情 ===${NC}"
    echo ""

    if [ "$OUTPUT_FORMAT" = "csv" ]; then
        mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$sql" | sed 's/\t/,/g'
    elif [ "$OUTPUT_FORMAT" = "json" ]; then
        if command -v jq >/dev/null 2>&1; then
            mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$sql" --json | jq .
        else
            warn "需要安装jq工具来输出JSON格式，切换到表格格式"
            mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$sql"
        fi
    else
        mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$sql"
    fi

    # 显示数据库统计
    echo ""
    local total_sql="
    SELECT
        COUNT(TABLE_NAME) as '总表数',
        ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as '总大小(MB)',
        SUM(TABLE_ROWS) as '总行数'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = '$database';
    "
    echo -e "${CYAN}=== 数据库统计 ===${NC}"
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$total_sql"
}

# 显示最大的N个表
show_top_tables() {
    local limit="${1:-10}"

    if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
        error "数量必须是数字"
    fi

    log "获取最大的 $limit 个表..."
    check_mysql_connection

    local sql="
    SELECT
        TABLE_SCHEMA as '数据库',
        TABLE_NAME as '表名',
        ENGINE as '存储引擎',
        ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) as '总大小(MB)',
        ROUND((DATA_LENGTH / 1024 / 1024), 2) as '数据大小(MB)',
        ROUND((INDEX_LENGTH / 1024 / 1024), 2) as '索引大小(MB)',
        TABLE_ROWS as '行数'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC
    LIMIT $limit;
    "

    echo -e "${CYAN}=== 最大的 $limit 个表 ===${NC}"
    echo ""
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$sql"
}

# 显示空表
show_empty_tables() {
    log "查找空表..."
    check_mysql_connection

    local sql="
    SELECT
        TABLE_SCHEMA as '数据库',
        TABLE_NAME as '表名',
        ENGINE as '存储引擎',
        ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024), 2) as '总大小(KB)',
        TABLE_COLLATION as '字符集'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND (TABLE_ROWS = 0 OR TABLE_ROWS IS NULL)
    ORDER BY TABLE_SCHEMA, TABLE_NAME;
    "

    echo -e "${CYAN}=== 空表列表 ===${NC}"
    echo ""
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$sql"

    # 统计空表数量
    local count_sql="
    SELECT COUNT(*) as empty_table_count
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND (TABLE_ROWS = 0 OR TABLE_ROWS IS NULL);
    "
    local count=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -sN -e "$count_sql" 2>/dev/null)
    echo ""
    info "共找到 $count 个空表"
}

# 显示大表
show_large_tables() {
    local threshold_mb="${1:-100}"

    if ! [[ "$threshold_mb" =~ ^[0-9]+$ ]]; then
        error "阈值必须是数字(MB)"
    fi

    log "查找大于 $threshold_mb MB 的表..."
    check_mysql_connection

    local sql="
    SELECT
        TABLE_SCHEMA as '数据库',
        TABLE_NAME as '表名',
        ENGINE as '存储引擎',
        ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) as '总大小(MB)',
        ROUND((DATA_LENGTH / 1024 / 1024), 2) as '数据大小(MB)',
        ROUND((INDEX_LENGTH / 1024 / 1024), 2) as '索引大小(MB)',
        TABLE_ROWS as '行数',
        ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / NULLIF(TABLE_ROWS, 0)), 4) as '平均行大小(KB)'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND ((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024) > $threshold_mb
    ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;
    "

    echo -e "${CYAN}=== 大于 $threshold_mb MB 的表 ===${NC}"
    echo ""
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$sql"

    # 统计大表数量和总大小
    local summary_sql="
    SELECT
        COUNT(*) as large_table_count,
        ROUND(SUM((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) as total_size_mb
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND ((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024) > $threshold_mb;
    "
    echo ""
    echo -e "${CYAN}=== 大表统计 ===${NC}"
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$summary_sql"
}

# 显示索引使用情况
show_index_usage() {
    log "分析索引使用情况..."
    check_mysql_connection

    echo -e "${CYAN}=== 索引大小统计 ===${NC}"
    echo ""

    # 索引大小统计
    local index_sql="
    SELECT
        TABLE_SCHEMA as '数据库',
        TABLE_NAME as '表名',
        ROUND((INDEX_LENGTH / 1024 / 1024), 2) as '索引大小(MB)',
        ROUND((DATA_LENGTH / 1024 / 1024), 2) as '数据大小(MB)',
        ROUND((INDEX_LENGTH / NULLIF(DATA_LENGTH, 0) * 100), 2) as '索引占比(%)'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND INDEX_LENGTH > 0
    ORDER BY INDEX_LENGTH DESC
    LIMIT 20;
    "
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$index_sql"

    echo ""
    echo -e "${CYAN}=== 高索引占比表 (>50%) ===${NC}"
    echo ""

    # 高索引占比表
    local high_index_sql="
    SELECT
        TABLE_SCHEMA as '数据库',
        TABLE_NAME as '表名',
        ROUND((INDEX_LENGTH / 1024 / 1024), 2) as '索引大小(MB)',
        ROUND((DATA_LENGTH / 1024 / 1024), 2) as '数据大小(MB)',
        ROUND((INDEX_LENGTH / NULLIF(DATA_LENGTH, 0) * 100), 2) as '索引占比(%)'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND DATA_LENGTH > 0
    AND (INDEX_LENGTH / DATA_LENGTH) > 0.5
    ORDER BY (INDEX_LENGTH / DATA_LENGTH) DESC;
    "
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$high_index_sql"
}

# 显示表碎片情况
show_fragmentation() {
    log "分析表碎片情况..."
    check_mysql_connection

    # 需要启用innodb_file_per_table和innodb_stats_persistent
    echo -e "${CYAN}=== 表碎片分析 ===${NC}"
    echo ""

    local sql="
    SELECT
        TABLE_SCHEMA as '数据库',
        TABLE_NAME as '表名',
        ENGINE as '存储引擎',
        ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) as '总大小(MB)',
        ROUND((DATA_FREE / 1024 / 1024), 2) as '碎片大小(MB)',
        ROUND((DATA_FREE / NULLIF(DATA_LENGTH + INDEX_LENGTH, 0) * 100), 2) as '碎片占比(%)',
        TABLE_ROWS as '行数'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND DATA_FREE > 0
    ORDER BY DATA_FREE DESC
    LIMIT 20;
    "

    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$sql"

    echo ""
    info "提示: 可以使用 OPTIMIZE TABLE table_name; 命令清理碎片"
}

# 显示存储引擎使用情况
show_storage_engines() {
    log "分析存储引擎使用情况..."
    check_mysql_connection

    echo -e "${CYAN}=== 存储引擎使用统计 ===${NC}"
    echo ""

    local engine_sql="
    SELECT
        ENGINE as '存储引擎',
        COUNT(*) as '表数量',
        ROUND(SUM(DATA_LENGTH / 1024 / 1024), 2) as '数据大小(MB)',
        ROUND(SUM(INDEX_LENGTH / 1024 / 1024), 2) as '索引大小(MB)',
        ROUND(SUM((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) as '总大小(MB)',
        SUM(TABLE_ROWS) as '总行数'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    GROUP BY ENGINE
    ORDER BY total_size DESC;
    "

    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$engine_sql"

    echo ""
    echo -e "${CYAN}=== 各数据库的存储引擎分布 ===${NC}"
    echo ""

    local db_engine_sql="
    SELECT
        TABLE_SCHEMA as '数据库',
        ENGINE as '存储引擎',
        COUNT(*) as '表数量'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    GROUP BY TABLE_SCHEMA, ENGINE
    ORDER BY TABLE_SCHEMA, count DESC;
    "

    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$db_engine_sql"
}

# 显示详细汇总报告
show_summary_report() {
    log "生成详细汇总报告..."
    check_mysql_connection

    echo -e "${CYAN}=== MySQL数据库详细汇总报告 ===${NC}"
    echo "生成时间: $(date)"
    echo "服务器: $MYSQL_HOST:$MYSQL_PORT"
    echo ""

    # 总体统计
    echo -e "${CYAN}1. 总体统计${NC}"
    local total_sql="
    SELECT
        COUNT(DISTINCT TABLE_SCHEMA) as '数据库数量',
        COUNT(*) as '总表数量',
        ROUND(SUM((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) as '总大小(MB)',
        ROUND(SUM(DATA_LENGTH / 1024 / 1024), 2) as '数据大小(MB)',
        ROUND(SUM(INDEX_LENGTH / 1024 / 1024), 2) as '索引大小(MB)',
        SUM(TABLE_ROWS) as '总行数'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys');
    "
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$total_sql"
    echo ""

    # 前5大数据库
    echo -e "${CYAN}2. 前5大数据库${NC}"
    local top_db_sql="
    SELECT
        SCHEMA_NAME as '数据库',
        ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as '总大小(MB)',
        COUNT(TABLE_NAME) as '表数量'
    FROM information_schema.TABLES
    WHERE SCHEMA_NAME NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    GROUP BY SCHEMA_NAME
    ORDER BY SUM(DATA_LENGTH + INDEX_LENGTH) DESC
    LIMIT 5;
    "
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$top_db_sql"
    echo ""

    # 前10大表
    echo -e "${CYAN}3. 前10大表${NC}"
    show_top_tables 10
    echo ""

    # 存储引擎分布
    echo -e "${CYAN}4. 存储引擎分布${NC}"
    local engine_summary="
    SELECT
        ENGINE as '存储引擎',
        COUNT(*) as '表数量',
        ROUND(SUM((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) as '总大小(MB)',
        ROUND(SUM((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024) / (
            SELECT SUM((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024)
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
        ) * 100, 2) as '占比(%)'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    GROUP BY ENGINE
    ORDER BY total_size DESC;
    "
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$engine_summary"
    echo ""

    # 碎片统计
    echo -e "${CYAN}5. 碎片统计${NC}"
    local frag_sql="
    SELECT
        COUNT(*) as '有碎片的表数量',
        ROUND(SUM(DATA_FREE / 1024 / 1024), 2) as '总碎片大小(MB)',
        ROUND(AVG(DATA_FREE / NULLIF(DATA_LENGTH + INDEX_LENGTH, 0) * 100), 2) as '平均碎片占比(%)'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND DATA_FREE > 0;
    "
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$frag_sql"
    echo ""

    # 空表统计
    echo -e "${CYAN}6. 空表统计${NC}"
    local empty_sql="
    SELECT
        COUNT(*) as '空表数量',
        ROUND(SUM((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) as '空表占用空间(MB)'
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND (TABLE_ROWS = 0 OR TABLE_ROWS IS NULL);
    "
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$empty_sql"
}

# 导出结果
export_results() {
    local format="${1:-table}"
    local filename="$2"

    if [ -z "$filename" ]; then
        error "请指定输出文件名"
    fi

    log "导出结果到 $filename (格式: $format)..."

    # 临时设置输出格式
    local original_format="$OUTPUT_FORMAT"
    OUTPUT_FORMAT="$format"

    case "$format" in
        "csv")
            show_database_overview > "$filename"
            ;;
        "json")
            if ! command -v jq >/dev/null 2>&1; then
                error "需要安装jq工具来输出JSON格式"
            fi
            show_database_overview > "$filename"
            ;;
        "table"|*)
            show_database_overview > "$filename"
            ;;
    esac

    # 恢复原始格式
    OUTPUT_FORMAT="$original_format"

    log "结果已导出到: $filename"
    info "文件大小: $(du -h "$filename" | cut -f1)"
}

# 主函数
main() {
    # 检查必要的工具
    if ! command -v mysql >/dev/null 2>&1; then
        error "需要安装MySQL客户端工具"
    fi

    case "$1" in
        "database")
            show_database_tables "$2"
            ;;
        "top")
            show_top_tables "$2"
            ;;
        "empty")
            show_empty_tables
            ;;
        "large")
            show_large_tables "$2"
            ;;
        "indexes")
            show_index_usage
            ;;
        "fragmentation")
            show_fragmentation
            ;;
        "engines")
            show_storage_engines
            ;;
        "summary")
            show_summary_report
            ;;
        "export")
            export_results "$2" "$3"
            ;;
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        *)
            # 默认显示数据库概览
            show_database_overview
            ;;
    esac
}

main "$@"