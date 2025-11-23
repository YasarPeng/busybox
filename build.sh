#!/bin/bash

# Docker 镜像构建脚本
set -e

IMAGE_NAME="laiye-tools-debug"
IMAGE_TAG="v1.0.0"
PUSH=false
ARCH="amd64"
DOCKERFILE="Dockerfile_amd64"

# 检测系统架构
detect_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            ARCH="amd64"
            IMAGE_TAG="amd64"
            DOCKERFILE="Dockerfile_amd64"
        ;;
        aarch64|arm64)
            ARCH="arm64"
            IMAGE_TAG="arm64"
            DOCKERFILE="Dockerfile_arm64"
        ;;
        *)
            echo "❌ 不支持的架构: $arch"
            echo "支持的架构: amd64, arm64"
            exit 1
        ;;
    esac
}

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
        --arch)
            ARCH="$2"
            if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
                echo "❌ 不支持的架构: $ARCH"
                echo "支持的架构: amd64, arm64"
                exit 1
            fi
            shift 2
        ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --push              推送到镜像仓库"
            echo "  --tag TAG           指定标签 (默认: v1.0.0)"
            echo "  --arch ARCH         指定架构 (amd64|arm64, 默认自动检测)"
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

# 如果未指定架构，则自动检测
if [[ -z "$ARCH" ]]; then
    detect_architecture
else
    # 根据指定架构设置Dockerfile
    case $ARCH in
        amd64)
            DOCKERFILE="Dockerfile_amd64"
        ;;
        arm64)
            DOCKERFILE="Dockerfile_arm64"
        ;;
    esac
fi

# 检查Dockerfile是否存在
if [[ ! -f "$DOCKERFILE" ]]; then
    echo "❌ Dockerfile不存在: $DOCKERFILE"
    exit 1
fi

echo "🏗️  开始构建 Docker 镜像..."
echo "镜像名称: $IMAGE_NAME:$IMAGE_TAG"
echo "架构: $ARCH"
echo "Dockerfile: $DOCKERFILE"
echo "推送到仓库: $PUSH"
echo ""
echo "📦 包含的应用脚本:"
echo "  - mysql_backup_restore.sh     MySQL备份恢复工具"
echo "  - mysql_read_write_test.sh    MySQL读写性能测试"
echo "  - mysql_table_size_analyzer.sh MySQL表大小分析工具"
echo "  - rabbitmq_vhost_manager.sh  RabbitMQ虚拟主机管理"

# 构建命令
if [ "$PUSH" = true ]; then
    echo "执行命令: docker build --tag $IMAGE_NAME:$IMAGE_TAG --file $DOCKERFILE ."
    docker build --tag $IMAGE_NAME:$IMAGE_TAG --file $DOCKERFILE .
    echo "推送镜像: docker push $IMAGE_NAME:$IMAGE_TAG"
    docker push $IMAGE_NAME:$IMAGE_TAG
else
    echo "执行命令: docker build --tag $IMAGE_NAME:$IMAGE_TAG --file $DOCKERFILE ."
    docker build --tag $IMAGE_NAME:$IMAGE_TAG --file $DOCKERFILE .
fi

if [ $? -eq 0 ]; then
    echo "✅ 镜像构建成功!"
    echo "架构: $ARCH"
    echo "镜像标签: $IMAGE_NAME:$IMAGE_TAG"
    
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