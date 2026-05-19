## 🔒 一键修改SSH端口以及启用密钥登录
```bash
curl -fsSL https://raw.githubusercontent.com/gsllpga/ServerTools/refs/heads/main/secure_ssh.sh -o secure_ssh.sh
chmod +x secure_ssh.sh
./secure_ssh.sh
```

## 🔒 编译安装 Nginx
```bash
curl -fsSL https://raw.githubusercontent.com/gsllpga/ServerTools/refs/heads/main/install_nginx.sh -o install_nginx.sh
chmod +x install_nginx.sh
./install_nginx.sh
```

## 🔒 一键部署Prometheus探针
```bash
curl -fsSL https://raw.githubusercontent.com/gsllpga/ServerTools/main/node_exporter_manager.sh -o node_exporter_manager.sh
chmod +x node_exporter_manager.sh
./node_exporter_manager.sh

```

## 🔒 一键部署BBR
```bash
wget --no-check-certificate -O /opt/bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh
chmod 755 /opt/bbr.sh
/opt/bbr.sh
```

## 🔒 bage DE BBR
```bash
cat > /etc/sysctl.conf << EOF
fs.file-max = 6815744
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.ip_forward=1
net.ipv4.conf.all.route_localnet=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
EOF
sysctl -p && sysctl --system

```
