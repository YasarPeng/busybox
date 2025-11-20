#!/bin/bash

# 多架构构建脚本
set -e

IMAGE_NAME="multi-tool-debug"
IMAGE_TAG="latest"
PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"

# 检查是否安装了 buildx
if ! docker buildx version >/dev/null 2>&1; then
    echo "❌ Docker buildx 未安装或未启用"
    echo "请先启用 Docker buildx: docker buildx install"
    exit 1
fi

# 创建 buildx 构建器（如果不存在）
BUILDER_NAME="multiarch-builder"
if ! docker buildx ls | grep -q $BUILDER_NAME; then
    echo "创建多架构构建器..."
    docker buildx create --name $BUILDER_NAME --use --bootstrap
else
    echo "使用现有的多架构构建器..."
    docker buildx use $BUILDER_NAME
fi

# 解析命令行参数
BUILD_TYPE="local"
PUSH=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH=true
            shift
            ;;
        --platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --push              推送到镜像仓库"
            echo "  --platforms PLAT   指定平台 (默认: linux/amd64,linux/arm64,linux/arm/v7)"
            echo "  --tag TAG           指定标签 (默认: latest)"
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

echo "🏗️  开始构建多架构 Docker 镜像..."
echo "镜像名称: $IMAGE_NAME:$IMAGE_TAG"
echo "支持平台: $PLATFORMS"
echo "推送到仓库: $PUSH"

# 构建命令
BUILD_CMD="docker buildx build"
BUILD_CMD="$BUILD_CMD --platform $PLATFORMS"
BUILD_CMD="$BUILD_CMD --tag $IMAGE_NAME:$IMAGE_TAG"

if [ "$PUSH" = true ]; then
    BUILD_CMD="$BUILD_CMD --push"
else
    BUILD_CMD="$BUILD_CMD --load"
fi

BUILD_CMD="$BUILD_CMD ."

echo "执行命令: $BUILD_CMD"
eval $BUILD_CMD

if [ $? -eq 0 ]; then
    echo "✅ 镜像构建成功!"

    if [ "$PUSH" = false ]; then
        echo "运行命令 (x86_64): docker run -it --rm $IMAGE_NAME:$IMAGE_TAG"
        echo "运行命令 (ARM64): docker run -it --rm --platform linux/arm64 $IMAGE_NAME:$IMAGE_TAG"
    else
        echo "镜像已推送到仓库!"
        echo "拉取命令: docker pull $IMAGE_NAME:$IMAGE_TAG"
    fi

    echo ""
    echo "🔍 镜像信息:"
    docker buildx imagetools inspect $IMAGE_NAME:$IMAGE_TAG 2>/dev/null || echo "本地构建，无法查看多平台信息"
else
    echo "❌ 镜像构建失败!"
    exit 1
fi