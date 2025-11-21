#!/bin/bash

# Docker 镜像构建脚本
set -e

IMAGE_NAME="laiye-tools-debug"
IMAGE_TAG="v1.0.0"
PUSH=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH=true
            shift
        ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
        ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --push              推送到镜像仓库"
            echo "  --tag TAG           指定标签 (默认: v1.0.0)"
            echo "  --help, -h          显示帮助信息"
            exit 0
        ;;
        *)
            echo "未知选项: $1"
            echo "使用 --help 查看帮助"
            exit 1
        ;;
    esac
done

echo "🏗️  开始构建 Docker 镜像..."
echo "镜像名称: $IMAGE_NAME:$IMAGE_TAG"
echo "推送到仓库: $PUSH"
echo ""
echo "📦 包含的应用脚本:"
echo "  - mysql_backup_restore.sh     MySQL备份恢复工具"
echo "  - mysql_read_write_test.sh    MySQL读写性能测试"
echo "  - mysql_table_size_analyzer.sh MySQL表大小分析工具"
echo "  - rabbitmq_vhost_manager.sh  RabbitMQ虚拟主机管理"

# 构建命令
if [ "$PUSH" = true ]; then
    echo "执行命令: docker build --tag $IMAGE_NAME:$IMAGE_TAG ."
    docker build --tag $IMAGE_NAME:$IMAGE_TAG .
    echo "推送镜像: docker push $IMAGE_NAME:$IMAGE_TAG"
    docker push $IMAGE_NAME:$IMAGE_TAG
else
    echo "执行命令: docker build --tag $IMAGE_NAME:$IMAGE_TAG ."
    docker build --tag $IMAGE_NAME:$IMAGE_TAG .
fi

if [ $? -eq 0 ]; then
    echo "✅ 镜像构建成功!"

    if [ "$PUSH" = true ]; then
        echo "镜像已推送到仓库!"
        echo "拉取命令: docker pull $IMAGE_NAME:$IMAGE_TAG"
    else
        echo "运行命令: docker run -it --rm $IMAGE_NAME:$IMAGE_TAG"
    fi

    echo ""
    echo "🔍 镜像信息:"
    docker images | grep $IMAGE_NAME | head -5
else
    echo "❌ 镜像构建失败!"
    exit 1
fi