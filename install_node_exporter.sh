#!/usr/bin/env bash
set -e

NE_VERSION="1.10.2"
BIN_PATH="/usr/local/bin/node_exporter"
SERVICE_FILE="/etc/systemd/system/node_exporter.service"
DEFAULT_PORT=9100

# ---------- utils ----------
require_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
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
  read -rp "Enter listen port [default: ${DEFAULT_PORT}]: " INPUT
  PORT=${INPUT:-$DEFAULT_PORT}

  if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "Invalid port"
    exit 1
  fi
}

service_exists() {
  systemctl list-unit-files | grep -q node_exporter.service
}

# ---------- actions ----------
install_node_exporter() {
  if service_exists; then
    echo "node_exporter already installed"
    return
  fi

  read_port
  ARCH=$(detect_arch)
  [ "$ARCH" = "unsupported" ] && echo "Unsupported arch" && exit 1

  echo "Installing node_exporter (${ARCH})..."

  command -v curl >/dev/null || (apt update && apt install -y curl)

  id node_exporter &>/dev/null || useradd -rs /bin/false node_exporter

  TMP=$(mktemp -d)
  cd "$TMP"

  curl -LO https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}/node_exporter-${NE_VERSION}.linux-${ARCH}.tar.gz
  tar zxf node_exporter-*.tar.gz
  cp node_exporter-*/node_exporter "$BIN_PATH"

  chown node_exporter:node_exporter "$BIN_PATH"
  chmod +x "$BIN_PATH"

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

  echo "Installed successfully on port ${PORT}"
}

update_node_exporter() {
  if ! service_exists; then
    echo "node_exporter not installed"
    return
  fi

  ARCH=$(detect_arch)
  TMP=$(mktemp -d)
  cd "$TMP"

  echo "Updating node_exporter..."
  curl -LO https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}/node_exporter-${NE_VERSION}.linux-${ARCH}.tar.gz
  tar zxf node_exporter-*.tar.gz

  systemctl stop node_exporter
  cp node_exporter-*/node_exporter "$BIN_PATH"
  chown node_exporter:node_exporter "$BIN_PATH"
  chmod +x "$BIN_PATH"
  systemctl start node_exporter

  echo "Update complete"
}

change_port() {
  if ! service_exists; then
    echo "node_exporter not installed"
    return
  fi

  read_port
  sed -i "s/--web.listen-address=.*/--web.listen-address=0.0.0.0:${PORT}/" "$SERVICE_FILE"

  systemctl daemon-reload
  systemctl restart node_exporter

  echo "Port changed to ${PORT}"
}

uninstall_node_exporter() {
  if ! service_exists; then
    echo "node_exporter not installed"
    return
  fi

  read -rp "Are you sure to uninstall? [y/N]: " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || return

  systemctl stop node_exporter
  systemctl disable node_exporter

  rm -f "$SERVICE_FILE"
  rm -f "$BIN_PATH"
  userdel node_exporter 2>/dev/null || true

  systemctl daemon-reload

  echo "node_exporter uninstalled"
}

# ---------- menu ----------
require_root

while true; do
  echo
  echo "========== Node Exporter Manager =========="
  echo "1) Install node_exporter"
  echo "2) Update node_exporter"
  echo "3) Change listen port"
  echo "4) Uninstall node_exporter"
  echo "0) Exit"
  echo "=========================================="
  read -rp "Please select an option: " CHOICE

  case "$CHOICE" in
    1) install_node_exporter ;;
    2) update_node_exporter ;;
    3) change_port ;;
    4) uninstall_node_exporter ;;
    0) exit 0 ;;
    *) echo "Invalid choice" ;;
  esac
done
