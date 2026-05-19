#!/bin/bash

# ==============================
# Nginx 一键编译安装脚本
# 默认版本：1.29.8
# 安装目录：/usr/local/nginx
# ==============================

set -e

DEFAULT_VERSION="1.29.8"

echo "=============================="
echo " Nginx 编译安装脚本"
echo "=============================="

read -p "请输入要安装的 Nginx 版本（默认 ${DEFAULT_VERSION}）: " NGINX_VERSION

# 如果用户直接回车
if [ -z "$NGINX_VERSION" ]; then
    NGINX_VERSION=$DEFAULT_VERSION
fi

echo ""
echo "即将安装 Nginx ${NGINX_VERSION}"
echo ""

# 安装依赖
echo ">>> 安装依赖..."
apt update -y

apt install -y \
    gcc \
    make \
    wget \
    tar \
    libpcre3 \
    libpcre3-dev \
    zlib1g \
    zlib1g-dev \
    libssl-dev

# 下载源码
cd /usr/local/src

echo ">>> 下载 Nginx ${NGINX_VERSION}..."
wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz

# 解压
echo ">>> 解压源码..."
tar -zxvf nginx-${NGINX_VERSION}.tar.gz

cd nginx-${NGINX_VERSION}

# 编译配置
echo ">>> 配置编译参数..."
./configure \
--prefix=/usr/local/nginx \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_v3_module \
--with-stream \
--with-stream_ssl_module \
--with-http_realip_module \
--with-stream_ssl_preread_module

# 编译安装
echo ">>> 开始编译..."
make -j$(nproc)

echo ">>> 开始安装..."
make install

# 创建 systemd 服务
echo ">>> 创建 systemd 服务..."

cat > /etc/systemd/system/nginx.service <<EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=network.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s quit
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# 重载 systemd
systemctl daemon-reload

# 设置开机启动
systemctl enable nginx

# 启动 nginx
systemctl start nginx

echo ""
echo "=============================="
echo " Nginx ${NGINX_VERSION} 安装完成"
echo "=============================="
echo ""

# 显示版本
/usr/local/nginx/sbin/nginx -v

echo ""
echo "常用命令："
echo "启动: systemctl start nginx"
echo "停止: systemctl stop nginx"
echo "重启: systemctl restart nginx"
echo "状态: systemctl status nginx"
echo "配置文件: /usr/local/nginx/conf/nginx.conf"
echo ""
