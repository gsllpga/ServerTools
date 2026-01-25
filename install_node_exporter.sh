#!/usr/bin/env bash

NE_VERSION="1.10.2"
BIN_PATH="/usr/local/bin/node_exporter"
SERVICE_FILE="/etc/systemd/system/node_exporter.service"
DEFAULT_PORT=9100

# ---------- utils ----------
require_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 root 运行"
    exit 1
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64) echo "amd64" ;;
    aarch64) echo "arm64" ;;
    armv7l) echo "armv7" ;;
    *) echo "unsupported" ;;
  esac
}

read_port() {
  while true; do
    read -rp "请输入监听端口 [默认 ${DEFAULT_PORT}，范围 1-65535]: " INPUT
    PORT=${INPUT:-$DEFAULT_PORT}
    if [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then
      break
    fi
    echo "❌ 端口无效"
  done
}

service_exists() {
  systemctl list-unit-files | grep -q "^node_exporter.service"
}

download_node_exporter() {
  ARCH=$(detect_arch)
  if [ "$ARCH" = "unsupported" ]; then
    echo "❌ 不支持的架构" >&2
    exit 1
  fi

  URL="https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}/node_exporter-${NE_VERSION}.linux-${ARCH}.tar.gz"
  TMP=$(mktemp -d)

  echo "⬇️  下载 node_exporter v${NE_VERSION} (${ARCH})..." >&2
  curl -fL "$URL" -o "$TMP/node_exporter.tar.gz"

  if ! file "$TMP/node_exporter.tar.gz" | grep -q gzip; then
    echo "❌ 下载文件不是 gzip，可能被劫持" >&2
    exit 1
  fi

  tar zxf "$TMP/node_exporter.tar.gz" -C "$TMP"

  echo "$TMP/node_exporter-${NE_VERSION}.linux-${ARCH}/node_exporter"
}

# ---------- actions ----------
install_node_exporter() {
  if service_exists; then
    echo "⚠️ node_exporter 已安装"
    return
  fi

  read_port
  command -v curl >/dev/null || (apt update && apt install -y curl)

  id node_exporter &>/dev/null || useradd -rs /bin/false node_exporter

  BIN_SRC=$(download_node_exporter)

  install -m 755 "$BIN_SRC" "$BIN_PATH"
  chown node_exporter:node_exporter "$BIN_PATH"

  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=${BIN_PATH} --web.listen-address=0.0.0.0:${PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now node_exporter

  echo "✅ 安装完成，端口：${PORT}"
}

update_node_exporter() {
  if ! service_exists; then
    echo "❌ 未安装"
    return
  fi

  BIN_SRC=$(download_node_exporter)
  systemctl stop node_exporter
  install -m 755 "$BIN_SRC" "$BIN_PATH"
  chown node_exporter:node_exporter "$BIN_PATH"
  systemctl start node_exporter

  echo "✅ 更新完成"
}

change_port() {
  if ! service_exists; then
    echo "❌ 未安装"
    return
  fi

  read_port
  sed -i "s|--web.listen-address=.*|--web.listen-address=0.0.0.0:${PORT}|" "$SERVICE_FILE"
  systemctl daemon-reload
  systemctl restart node_exporter

  echo "✅ 端口已修改为 ${PORT}"
}

status_node_exporter() {
  systemctl status node_exporter --no-pager
}

uninstall_node_exporter() {
  read -rp "确认卸载？[y/N]: " C
  [[ "$C" =~ ^[Yy]$ ]] || return

  systemctl stop node_exporter
  systemctl disable node_exporter
  rm -f "$SERVICE_FILE" "$BIN_PATH"
  userdel node_exporter 2>/dev/null || true
  systemctl daemon-reload

  echo "✅ 已卸载"
}

# ---------- menu ----------
require_root

while true; do
  echo
  echo "========== Node Exporter Manager =========="
  echo "1) 安装 node_exporter"
  echo "2) 更新 node_exporter"
  echo "3) 修改监听端口"
  echo "4) 查看服务状态"
  echo "5) 卸载 node_exporter"
  echo "0) 退出"
  echo "=========================================="
  read -rp "请选择: " CHOICE

  case "$CHOICE" in
    1) install_node_exporter ;;
    2) update_node_exporter ;;
    3) change_port ;;
    4) status_node_exporter ;;
    5) uninstall_node_exporter ;;
    0) exit 0 ;;
    *) echo "❌ 无效选项" ;;
  esac
done
