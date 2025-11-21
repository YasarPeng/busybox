#!/bin/bash

# MySQL读写测试脚本
# 用于测试MySQL数据库的读写性能和连通性

set -e

# 配置变量
MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
MYSQL_DATABASE="${MYSQL_DATABASE:-test_db}"
TEST_TABLE="${TEST_TABLE:-test_performance}"
CONCURRENT_CONNECTIONS="${CONCURRENT_CONNECTIONS:-10}"
TEST_DURATION="${TEST_DURATION:-30}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印帮助信息
show_help() {
    echo "MySQL读写测试工具"
    echo ""
    echo "用法:"
    echo "  $0 test                                     # 执行完整读写测试"
    echo "  $0 connection                              # 测试数据库连接"
    echo "  $0 write [记录数]                          # 写入测试"
    echo "  $0 read [查询次数]                         # 读取测试"
    echo "  $0 stress                                  # 压力测试"
    echo "  $0 benchmark                               # 性能基准测试"
    echo "  $0 cleanup                                 # 清理测试数据"
    echo "  $0 setup                                   # 初始化测试环境"
    echo ""
    echo "环境变量:"
    echo "  MYSQL_HOST              MySQL服务器地址 (默认: localhost)"
    echo "  MYSQL_PORT              MySQL端口 (默认: 3306)"
    echo "  MYSQL_USER              MySQL用户名 (默认: root)"
    echo "  MYSQL_PASSWORD          MySQL密码"
    echo "  MYSQL_DATABASE          测试数据库名 (默认: test_db)"
    echo "  TEST_TABLE              测试表名 (默认: test_performance)"
    echo "  CONCURRENT_CONNECTIONS  并发连接数 (默认: 10)"
    echo "  TEST_DURATION           测试持续时间(秒) (默认: 30)"
    echo ""
    echo "示例:"
    echo "  MYSQL_PASSWORD=123456 $0 test"
    echo "  MYSQL_PASSWORD=123456 MYSQL_DATABASE=myapp $0 write 10000"
    echo "  MYSQL_PASSWORD=123456 CONCURRENT_CONNECTIONS=20 $0 stress"
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

# 初始化测试环境
setup_test_environment() {
    log "初始化测试环境..."
    check_mysql_connection

    # 创建测试数据库（如果不存在）
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null

    # 创建测试表
    local create_table_sql="
    CREATE TABLE IF NOT EXISTS $MYSQL_DATABASE.$TEST_TABLE (
        id BIGINT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255),
        age INT,
        salary DECIMAL(10,2),
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_name (name),
        INDEX idx_email (email),
        INDEX idx_age (age),
        INDEX idx_created_at (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    "

    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -e "$create_table_sql" 2>/dev/null

    log "测试环境初始化完成"
}

# 连接测试
test_connection() {
    log "执行连接测试..."

    check_mysql_connection

    local start_time=$(date +%s.%N)

    # 执行简单查询
    for i in {1..10}; do
        mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
            -e "SELECT 1 as test_connection;" >/dev/null 2>&1
    done

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    local avg_time=$(echo "scale=3; $duration / 10" | bc -l)

    log "连接测试完成"
    info "平均响应时间: ${avg_time}秒"
}

# 写入测试
test_write() {
    local record_count="${1:-1000}"

    log "执行写入测试 - 插入 $record_count 条记录..."
    check_mysql_connection

    # 清空测试表
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -e "TRUNCATE TABLE $MYSQL_DATABASE.$TEST_TABLE;" 2>/dev/null

    local start_time=$(date +%s.%N)
    local batch_size=1000
    local batches=$((record_count / batch_size))

    if [ $((record_count % batch_size)) -ne 0 ]; then
        batches=$((batches + 1))
    fi

    log "分 $batches 批次插入，每批次 $batch_size 条记录"

    for ((batch=1; batch<=batches; batch++)); do
        local remaining=$record_count
        local offset=$(((batch-1) * batch_size))
        local current_batch_size=$batch_size

        if [ $((offset + batch_size)) -gt $record_count ]; then
            current_batch_size=$((record_count - offset))
        fi

        # 生成批量插入语句
        local insert_sql="INSERT INTO $MYSQL_DATABASE.$TEST_TABLE (name, email, age, salary, description) VALUES "
        local values=""

        for ((i=1; i<=current_batch_size; i++)); do
            local record_num=$((offset + i))
            values+="'Test User $record_num', 'user$record_num@test.com', $((20 + record_num % 50)), $((30000 + record_num % 50000)).$((record_num % 100)), 'Description for test record $record_num'"
            if [ $i -lt $current_batch_size ]; then
                values+=", "
            fi
        done

        insert_sql+="$values;"

        mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
            -e "$insert_sql" 2>/dev/null

        info "批次 $batch/$batches 完成 ($current_batch_size 条记录)"
    done

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    local throughput=$(echo "scale=2; $record_count / $duration" | bc -l)

    log "写入测试完成"
    info "总耗时: ${duration}秒"
    info "吞吐量: ${throughput} 记录/秒"

    # 验证插入的记录数
    local actual_count=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -sN -e "SELECT COUNT(*) FROM $MYSQL_DATABASE.$TEST_TABLE;" 2>/dev/null)

    info "实际插入记录数: $actual_count"
}

# 读取测试
test_read() {
    local query_count="${1:-1000}"

    log "执行读取测试 - 执行 $query_count 次查询..."
    check_mysql_connection

    local start_time=$(date +%s.%N)

    # 确保表中有数据
    local record_count=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -sN -e "SELECT COUNT(*) FROM $MYSQL_DATABASE.$TEST_TABLE;" 2>/dev/null)

    if [ "$record_count" -eq 0 ]; then
        warn "测试表中没有数据，先插入测试数据..."
        test_write 10000
        record_count=10000
    fi

    log "表中当前有 $record_count 条记录"

    # 执行各种类型的查询
    for ((i=1; i<=query_count; i++)); do
        local random_id=$((1 + RANDOM % record_count))
        local random_age=$((20 + RANDOM % 50))

        # 随机执行不同类型的查询
        case $((RANDOM % 5)) in
            0)
                # 主键查询
                mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
                    -sN -e "SELECT * FROM $MYSQL_DATABASE.$TEST_TABLE WHERE id = $random_id;" >/dev/null 2>&1
                ;;
            1)
                # 名称查询
                mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
                    -sN -e "SELECT COUNT(*) FROM $MYSQL_DATABASE.$TEST_TABLE WHERE name LIKE 'Test User%';" >/dev/null 2>&1
                ;;
            2)
                # 范围查询
                mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
                    -sN -e "SELECT COUNT(*) FROM $MYSQL_DATABASE.$TEST_TABLE WHERE age BETWEEN $random_age AND $((random_age + 10));" >/dev/null 2>&1
                ;;
            3)
                # 聚合查询
                mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
                    -sN -e "SELECT AVG(salary), MAX(salary), MIN(salary) FROM $MYSQL_DATABASE.$TEST_TABLE;" >/dev/null 2>&1
                ;;
            4)
                # 排序查询
                mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
                    -sN -e "SELECT * FROM $MYSQL_DATABASE.$TEST_TABLE ORDER BY created_at DESC LIMIT 10;" >/dev/null 2>&1
                ;;
        esac

        if [ $((i % 100)) -eq 0 ]; then
            info "已完成 $i/$query_count 次查询"
        fi
    done

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    local qps=$(echo "scale=2; $query_count / $duration" | bc -l)
    local avg_response_time=$(echo "scale=4; $duration / $query_count * 1000" | bc -l)

    log "读取测试完成"
    info "总耗时: ${duration}秒"
    info "查询速率: ${qps} QPS"
    info "平均响应时间: ${avg_response_time} 毫秒"
}

# 压力测试
test_stress() {
    log "执行压力测试 - $CONCURRENT_CONNECTIONS 个并发连接，持续 $TEST_DURATION 秒..."
    check_mysql_connection

    # 确保测试环境已设置
    setup_test_environment

    # 创建临时脚本用于并发测试
    local temp_script="/tmp/mysql_stress_test_$$_$RANDOM.sh"
    cat > "$temp_script" << 'EOF'
#!/bin/bash
MYSQL_HOST="$1"
MYSQL_PORT="$2"
MYSQL_USER="$3"
MYSQL_PASSWORD="$4"
MYSQL_DATABASE="$5"
TEST_DURATION="$6"
WORKER_ID="$7"

start_time=$(date +%s)
end_time=$((start_time + TEST_DURATION))
operations=0

while [ $(date +%s) -lt $end_time ]; do
    case $((RANDOM % 4)) in
        0)
            # 插入操作
            mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
                -e "INSERT INTO $MYSQL_DATABASE.test_performance (name, email, age, salary, description) VALUES ('Stress Test $WORKER_ID-$RANDOM', 'stress$WORKER_ID-$RANDOM@test.com', $((20 + RANDOM % 50)), $((30000 + RANDOM % 50000)).$((RANDOM % 100)), 'Stress test record from worker $WORKER_ID');" >/dev/null 2>&1
            ;;
        1)
            # 更新操作
            mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
                -e "UPDATE $MYSQL_DATABASE.test_performance SET salary = salary * 1.01 WHERE id % 10 = $WORKER_ID;" >/dev/null 2>&1
            ;;
        2)
            # 查询操作
            mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
                -e "SELECT COUNT(*) FROM $MYSQL_DATABASE.test_performance WHERE age BETWEEN 20 AND 50;" >/dev/null 2>&1
            ;;
        3)
            # 删除操作（限制数量，避免删除太多）
            mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
                -e "DELETE FROM $MYSQL_DATABASE.test_performance WHERE name LIKE 'Stress Test $WORKER_ID-%' LIMIT 5;" >/dev/null 2>&1
            ;;
    esac
    ((operations++))
done

echo "$operations"
EOF

    chmod +x "$temp_script"

    log "启动 $CONCURRENT_CONNECTIONS 个并发工作进程..."
    local start_time=$(date +%s)

    # 启动并发进程
    local pids=()
    for ((i=1; i<=CONCURRENT_CONNECTIONS; i++)); do
        "$temp_script" "$MYSQL_HOST" "$MYSQL_PORT" "$MYSQL_USER" "$MYSQL_PASSWORD" "$MYSQL_DATABASE" "$TEST_DURATION" "$i" &
        pids+=($!)
    done

    # 等待所有进程完成
    local total_operations=0
    for pid in "${pids[@]}"; do
        wait "$pid"
        local operations=$?
        total_operations=$((total_operations + operations))
    done

    local end_time=$(date +%s)
    local actual_duration=$((end_time - start_time))
    local ops_per_second=$(echo "scale=2; $total_operations / $actual_duration" | bc -l)

    # 清理临时脚本
    rm -f "$temp_script"

    log "压力测试完成"
    info "实际测试时间: ${actual_duration}秒"
    info "总操作数: $total_operations"
    info "平均操作速率: ${ops_per_second} OPS"

    # 显示当前表统计
    local current_records=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -sN -e "SELECT COUNT(*) FROM $MYSQL_DATABASE.$TEST_TABLE;" 2>/dev/null)
    info "测试表当前记录数: $current_records"
}

# 性能基准测试
run_benchmark() {
    log "执行性能基准测试..."

    # 确保测试环境已设置
    setup_test_environment

    echo "=== MySQL性能基准测试 ==="
    echo "测试时间: $(date)"
    echo "测试配置:"
    echo "  服务器: $MYSQL_HOST:$MYSQL_PORT"
    echo "  数据库: $MYSQL_DATABASE"
    echo "  测试表: $TEST_TABLE"
    echo ""

    # 连接测试
    echo "1. 连接测试"
    test_connection
    echo ""

    # 写入性能测试
    echo "2. 写入性能测试"
    test_write 10000
    echo ""

    # 读取性能测试
    echo "3. 读取性能测试"
    test_read 5000
    echo ""

    # 混合读写测试
    echo "4. 混合读写测试"
    log "执行混合读写测试 - 5000次写入 + 5000次读取..."

    # 写入测试
    test_write 5000

    # 读取测试
    test_read 5000
    echo ""

    # 获取数据库统计信息
    echo "5. 数据库统计信息"
    local table_stats=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -e "
        SELECT
            TABLE_NAME as '表名',
            TABLE_ROWS as '估计行数',
            DATA_LENGTH as '数据大小(字节)',
            INDEX_LENGTH as '索引大小(字节)',
            (DATA_LENGTH + INDEX_LENGTH) as '总大小(字节)'
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = '$MYSQL_DATABASE' AND TABLE_NAME = '$TEST_TABLE';
    " 2>/dev/null)

    echo "$table_stats"
    echo ""

    log "性能基准测试完成"
}

# 清理测试数据
cleanup_test_data() {
    log "清理测试数据..."
    check_mysql_connection

    # 删除测试表
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -e "DROP TABLE IF EXISTS $MYSQL_DATABASE.$TEST_TABLE;" 2>/dev/null

    # 询问是否删除测试数据库
    read -p "是否删除测试数据库 '$MYSQL_DATABASE'? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
            -e "DROP DATABASE IF EXISTS $MYSQL_DATABASE;" 2>/dev/null
        log "测试数据库已删除"
    else
        log "仅删除测试表，保留数据库"
    fi

    log "测试数据清理完成"
}

# 完整测试
run_full_test() {
    log "开始完整MySQL读写测试..."

    # 设置测试环境
    setup_test_environment

    # 执行各项测试
    echo ""
    test_connection

    echo ""
    test_write 5000

    echo ""
    test_read 2000

    echo ""
    log "完整测试完成"
}

# 主函数
main() {
    # 检查必要的工具
    if ! command -v bc >/dev/null 2>&1; then
        error "需要安装 bc 工具进行数学计算"
    fi

    case "$1" in
        "test")
            run_full_test
            ;;
        "connection")
            test_connection
            ;;
        "write")
            setup_test_environment
            test_write "$2"
            ;;
        "read")
            test_read "$2"
            ;;
        "stress")
            test_stress
            ;;
        "benchmark")
            run_benchmark
            ;;
        "cleanup")
            cleanup_test_data
            ;;
        "setup")
            setup_test_environment
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