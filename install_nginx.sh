#!/bin/bash
# 通用 Linux 系统编译安装 Nginx（支持手动输入版本号）
# 必须以 root 用户执行

set -e

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 用户执行此脚本 (sudo $0)"
    exit 1
fi

# 检测包管理器及安装依赖函数
install_deps() {
    if command -v apt &> /dev/null; then
        echo "检测到 apt (Debian/Ubuntu)"
        apt update -y
        apt install -y wget gcc make libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev
    elif command -v yum &> /dev/null; then
        echo "检测到 yum (RHEL/CentOS 7)"
        yum install -y wget gcc make pcre-devel zlib-devel openssl-devel
    elif command -v dnf &> /dev/null; then
        echo "检测到 dnf (Fedora/RHEL 8+)"
        dnf install -y wget gcc make pcre-devel zlib-devel openssl-devel
    elif command -v zypper &> /dev/null; then
        echo "检测到 zypper (openSUSE/SLES)"
        zypper refresh
        zypper install -y wget gcc make pcre-devel zlib-devel libopenssl-devel
    elif command -v apk &> /dev/null; then
        echo "检测到 apk (Alpine Linux)"
        apk update
        apk add wget gcc make pcre-dev zlib-dev openssl-dev
    else
        echo "错误：无法识别的包管理器，请手动安装依赖（gcc, make, pcre, zlib, openssl 开发包）"
        exit 1
    fi
}

# 输入版本号
read -p "请输入要安装的 Nginx 版本号 (例如 1.26.2): " NGINX_VERSION
if [[ ! "$NGINX_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "错误：版本号格式不正确，请使用类似 1.26.2 的格式"
    exit 1
fi

echo "即将安装 Nginx 版本: $NGINX_VERSION"

# 安装编译依赖
install_deps

# 下载源码
echo "=== 下载 Nginx ${NGINX_VERSION} 源码 ==="
wget "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"

# 解压
echo "=== 解压源码 ==="
tar -zxvf "nginx-${NGINX_VERSION}.tar.gz"
cd "nginx-${NGINX_VERSION}"

# 配置编译选项（如需增减模块可自行修改）
echo "=== 配置编译选项 ==="
./configure --prefix=/usr/local/nginx \
            --with-http_ssl_module \
            --with-http_v2_module \
            --with-http_v3_module \
            --with-stream \
            --with-stream_ssl_module \
            --with-http_realip_module \
            --with-stream_ssl_preread_module

# 编译并安装
echo "=== 编译并安装 ==="
make && make install

# 清理源码包
cd ..
echo "=== 清理源码包 ==="
rm -rf "nginx-${NGINX_VERSION}" "nginx-${NGINX_VERSION}.tar.gz"

# 启动 Nginx
echo "=== 启动 Nginx ==="
if pgrep nginx > /dev/null; then
    echo "检测到已有 nginx 进程，正在停止..."
    /usr/local/nginx/sbin/nginx -s stop || pkill nginx
    sleep 1
fi

/usr/local/nginx/sbin/nginx

if pgrep nginx > /dev/null; then
    echo "Nginx ${NGINX_VERSION} 已成功启动"
    echo "安装路径: /usr/local/nginx"
    echo "配置文件: /usr/local/nginx/conf/nginx.conf"
    echo "可执行文件: /usr/local/nginx/sbin/nginx"
    echo "管理命令: /usr/local/nginx/sbin/nginx -s {stop|reload|reopen}"
else
    echo "Nginx 启动失败，请检查日志"
    exit 1
fi
