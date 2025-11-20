# 使用 Alpine Linux 作为基础镜像以减小体积
FROM --platform=$BUILDPLATFORM alpine:3.18

# 添加标签信息
LABEL maintainer="pengyongshi" \
    description="Multi-tool container with MySQL, Redis, RabbitMQ, MinIO, etcdctl and network tools" \
    version="1.1"

# 设置环境变量
ENV TZ=Asia/Shanghai

# 安装所有必需的包，合并为单层以减小镜像大小
RUN apk add --no-cache \
    # 基础工具
    curl \
    wget \
    unzip \
    tar \
    bash \
    # 网络排查工具
    bind-tools \
    iproute2 \
    iputils-ping \
    busybox-extras \
    traceroute \
    nmap \
    tcpdump \
    mtr \
    # 进程和系统监控工具
    htop \
    iotop \
    lsof \
    strace \
    # 文本编辑和处理工具
    vim \
    jq \
    # 数据库客户端
    mysql-client \
    redis \
    # 其他工具
    ca-certificates \
    && rm -rf /var/cache/apk/*

# 安装 RabbitMQ 管理工具
RUN apk add --no-cache rabbitmq-server

# 安装 MinIO 客户端 (mc) - 支持多架构
ARG TARGETPLATFORM

RUN case "$TARGETPLATFORM" in \
    "linux/amd64") \
    curl -sSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc ;; \
    "linux/arm64") \
    curl -sSL https://dl.min.io/client/mc/release/linux-arm64/mc -o /usr/local/bin/mc ;; \
    "linux/arm/v7") \
    curl -sSL https://dl.min.io/client/mc/release/linux-arm/v7/mc -o /usr/local/bin/mc ;; \
    *) \
    echo "Unsupported architecture: $TARGETPLATFORM" && exit 1 ;; \
    esac \
    && chmod +x /usr/local/bin/mc

# 安装 etcdctl 工具 - 支持多架构
RUN case "$TARGETPLATFORM" in \
    "linux/amd64") \
    curl -sSL https://github.com/etcd-io/etcd/releases/download/v3.5.12/etcd-v3.5.12-linux-amd64.tar.gz -o etcd.tar.gz \
    && tar -xzvf etcd.tar.gz --strip-components=1 -C /usr/local/bin etcd-v3.5.12-linux-amd64/etcdctl \
    && rm etcd.tar.gz ;; \
    "linux/arm64") \
    curl -sSL https://github.com/etcd-io/etcd/releases/download/v3.5.12/etcd-v3.5.12-linux-arm64.tar.gz -o etcd.tar.gz \
    && tar -xzvf etcd.tar.gz --strip-components=1 -C /usr/local/bin etcd-v3.5.12-linux-arm64/etcdctl \
    && rm etcd.tar.gz ;; \
    "linux/arm/v7") \
    curl -sSL https://github.com/etcd-io/etcd/releases/download/v3.5.12/etcd-v3.5.12-linux-armv7.tar.gz -o etcd.tar.gz \
    && tar -xzvf etcd.tar.gz --strip-components=1 -C /usr/local/bin etcd-v3.5.12-linux-armv7/etcdctl \
    && rm etcd.tar.gz ;; \
    *) \
    echo "Unsupported architecture for etcdctl: $TARGETPLATFORM" && exit 1 ;; \
    esac \
    && chmod +x /usr/local/bin/etcdctl

# 创建工作目录
WORKDIR /apps

# 设置默认命令
CMD ["/bin/bash"]

