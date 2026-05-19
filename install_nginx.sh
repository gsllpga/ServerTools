#!/bin/bash
# 通用 Linux 系统编译安装 Nginx（支持手动输入版本号 / 最新版 / 默认版）
# 自动添加 systemd 服务并设置开机自启
# 必须以 root 用户执行

set -e

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 用户执行此脚本 (sudo $0)"
    exit 1
fi

# 获取最新稳定版 Nginx 版本号（从官网抓取）
get_latest_nginx_version() {
    echo "正在从 nginx.org 获取最新稳定版版本号..."
    LATEST_VERSION=$(curl -s https://nginx.org/en/download.html | grep -oP 'nginx-\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -z "$LATEST_VERSION" ]; then
        echo "警告：获取最新版本失败，将使用默认版本 1.29.8"
        echo "1.29.8"
    else
        echo "$LATEST_VERSION"
    fi
}

# 提示输入版本号
read -p "请输入 Nginx 版本号 (直接回车默认 1.29.8，输入 latest 自动获取最新版): " INPUT_VERSION

if [ -z "$INPUT_VERSION" ]; then
    NGINX_VERSION="1.29.8"
elif [ "$INPUT_VERSION" = "latest" ]; then
    NGINX_VERSION=$(get_latest_nginx_version)
else
    NGINX_VERSION="$INPUT_VERSION"
fi

# 简单验证版本号格式
if [[ ! "$NGINX_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "错误：版本号格式不正确，请使用类似 1.26.2 的格式"
    exit 1
fi

echo "将安装 Nginx 版本: $NGINX_VERSION"

# 检测包管理器并安装编译依赖
install_deps() {
    if command -v apt &> /dev/null; then
        echo "检测到 apt (Debian/Ubuntu)"
        apt update -y
        apt install -y wget curl gcc make libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev
    elif command -v yum &> /dev/null; then
        echo "检测到 yum (RHEL/CentOS 7)"
        yum install -y wget curl gcc make pcre-devel zlib-devel openssl-devel
    elif command -v dnf &> /dev/null; then
        echo "检测到 dnf (Fedora/RHEL 8+)"
        dnf install -y wget curl gcc make pcre-devel zlib-devel openssl-devel
    elif command -v zypper &> /dev/null; then
        echo "检测到 zypper (openSUSE/SLES)"
        zypper refresh
        zypper install -y wget curl gcc make pcre-devel zlib-devel libopenssl-devel
    elif command -v apk &> /dev/null; then
        echo "检测到 apk (Alpine Linux)"
        apk update
        apk add wget curl gcc make pcre-dev zlib-dev openssl-dev
    else
        echo "错误：无法识别的包管理器，请手动安装依赖（gcc, make, pcre, zlib, openssl 开发包）"
        exit 1
    fi
}

# 停止已有 nginx（如果正在运行）
stop_existing_nginx() {
    if pgrep nginx > /dev/null; then
        echo "检测到已有 nginx 进程，正在停止..."
        pkill -TERM nginx
        sleep 2
        # 强制杀死残留进程（如有）
        if pgrep nginx > /dev/null; then
            pkill -KILL nginx
        fi
        echo "已停止旧 nginx 进程"
    else
        echo "未检测到运行中的 nginx"
    fi
}

# 安装编译依赖
install_deps

# 停止旧进程（避免端口冲突及 pid 文件问题）
stop_existing_nginx

# 下载源码
echo "=== 下载 Nginx ${NGINX_VERSION} 源码 ==="
wget "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"

# 解压
echo "=== 解压源码 ==="
tar -zxvf "nginx-${NGINX_VERSION}.tar.gz"
cd "nginx-${NGINX_VERSION}"

# 配置编译选项
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

# 回到原目录，清理源码包
cd ..
echo "=== 清理源码包 ==="
rm -rf "nginx-${NGINX_VERSION}" "nginx-${NGINX_VERSION}.tar.gz"

# 创建 systemd 服务文件
echo "=== 创建 systemd 服务 ==="
cat > /etc/systemd/system/nginx.service <<EOF
[Unit]
Description=Nginx HTTP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s stop
PIDFile=/usr/local/nginx/logs/nginx.pid
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd，启用并启动服务
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx

# 检查服务状态
if systemctl is-active --quiet nginx; then
    echo "Nginx ${NGINX_VERSION} 已成功启动并设置为开机自启"
    echo "安装路径: /usr/local/nginx"
    echo "配置文件: /usr/local/nginx/conf/nginx.conf"
    echo "服务管理: systemctl {start|stop|restart|reload} nginx"
else
    echo "Nginx 启动失败，请检查日志: journalctl -u nginx"
    exit 1
fi
