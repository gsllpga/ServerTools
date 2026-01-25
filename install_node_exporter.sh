#!/usr/bin/env bash
set -e

SERVICE_NAME="node_exporter"
BIN_PATH="/usr/local/bin/node_exporter"
SERVICE_FILE="/etc/systemd/system/node_exporter.service"
DOWNLOAD_BASE="https://github.com/prometheus/node_exporter/releases/latest/download"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用 root 用户运行${NC}"
    exit 1
  fi
}

pause() {
  read -rp "按回车键继续..."
}

get_arch() {
  case "$(uname -m)" in
    x86_64) echo "linux-amd64" ;;
    aarch64|arm64) echo "linux-arm64" ;;
    *)
      echo -e "${RED}不支持的架构$(uname -m)${NC}"
      exit 1
      ;;
  esac
}

check_port() {
  local port=$1
  if ! [[ "$port" =~ ^[0-9]+$ ]] || ((port < 1024 || port > 65535)); then
    echo -e "${RED}端口必须是 1024-65535 之间的数字${NC}"
    return 1
  fi

  if ss -lnt | awk '{print $4}' | grep -q ":$port$"; then
    echo -e "${RED}端口 $port 已被占用${NC}"
    return 1
  fi
  return 0
}

input_port() {
  while true; do
    read -rp "请输入监听端口 [9100]: " PORT
    PORT=${PORT:-9100}
    check_port "$PORT" && break
  done
}

create_service() {
  cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
ExecStart=$BIN_PATH --web.listen-address=0.0.0.0:$PORT
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now node_exporter
}

install_node_exporter() {
  echo -e "${GREEN}开始安装 Node Exporter${NC}"
  input_port

  ARCH=$(get_arch)
  TMP_DIR=$(mktemp -d)
  cd "$TMP_DIR"

  curl -LO "$DOWNLOAD_BASE/node_exporter-$ARCH.tar.gz"
  tar xf node_exporter-$ARCH.tar.gz
  cp node_exporter-*/node_exporter "$BIN_PATH"
  chmod +x "$BIN_PATH"

  create_service

  echo -e "${GREEN}安装完成，监听端口：$PORT${NC}"
}

update_node_exporter() {
  if [[ ! -f "$BIN_PATH" ]]; then
    echo -e "${RED}未安装 node_exporter${NC}"
    return
  fi

  echo -e "${GREEN}更新 Node Exporter${NC}"
  ARCH=$(get_arch)
  TMP_DIR=$(mktemp -d)
  cd "$TMP_DIR"

  curl -LO "$DOWNLOAD_BASE/node_exporter-$ARCH.tar.gz"
  tar xf node_exporter-$ARCH.tar.gz
  systemctl stop node_exporter
  cp node_exporter-*/node_exporter "$BIN_PATH"
  chmod +x "$BIN_PATH"
  systemctl start node_exporter

  echo -e "${GREEN}更新完成${NC}"
}

change_port() {
  if [[ ! -f "$SERVICE_FILE" ]]; then
    echo -e "${RED}node_exporter 未安装${NC}"
    return
  fi

  input_port
  sed -i "s/--web.listen-address=.*/--web.listen-address=0.0.0.0:$PORT/" "$SERVICE_FILE"

  systemctl daemon-reload
  systemctl restart node_exporter

  echo -e "${GREEN}端口已修改为 $PORT${NC}"
}

uninstall_node_exporter() {
  echo -e "${YELLOW}确认卸载 node_exporter？[y/N]${NC}"
  read -r confirm
  [[ "$confirm" != "y" ]] && return

  systemctl stop node_exporter || true
  systemctl disable node_exporter || true
  rm -f "$SERVICE_FILE" "$BIN_PATH"
  systemctl daemon-reload

  echo -e "${GREEN}已卸载${NC}"
}

status_node_exporter() {
  systemctl status node_exporter --no-pager
}

menu() {
  clear
  echo "========== Node Exporter Manager =========="
  echo "1) 安装 node_exporter"
  echo "2) 更新 node_exporter"
  echo "3) 修改监听端口"
  echo "4) 查看服务状态"
  echo "5) 卸载 node_exporter"
  echo "0) 退出"
  echo "=========================================="
  read -rp "请选择: " choice

  case "$choice" in
    1) install_node_exporter ;;
    2) update_node_exporter ;;
    3) change_port ;;
    4) status_node_exporter ;;
    5) uninstall_node_exporter ;;
    0) exit 0 ;;
    *) echo -e "${RED}无效选项${NC}" ;;
  esac

  pause
}

check_root
while true; do
  menu
done
