#!/usr/bin/env bash
set -e

NE_VERSION="1.7.0"
INSTALL_DIR="/opt/node_exporter"
BIN_PATH="/usr/local/bin/node_exporter"
SERVICE_FILE="/etc/systemd/system/node_exporter.service"

echo "==> Detecting architecture..."
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)   ARCH="amd64" ;;
  aarch64)  ARCH="arm64" ;;
  armv7l)   ARCH="armv7" ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "==> Installing dependencies..."
command -v curl >/dev/null 2>&1 || \
  (apt update && apt install -y curl) || \
  (yum install -y curl)

echo "==> Creating node_exporter user..."
id node_exporter >/dev/null 2>&1 || \
  useradd -rs /bin/false node_exporter

echo "==> Downloading node_exporter v${NE_VERSION}..."
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

curl -LO "https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}/node_exporter-${NE_VERSION}.linux-${ARCH}.tar.gz"

tar zxvf node_exporter-*.tar.gz
cp node_exporter-*/node_exporter "$BIN_PATH"
chown node_exporter:node_exporter "$BIN_PATH"
chmod +x "$BIN_PATH"

echo "==> Creating systemd service..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=$BIN_PATH \\
  --web.listen-address=0.0.0.0:9100 \\
  --collector.systemd \\
  --collector.processes

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "==> Reloading systemd & starting service..."
systemctl daemon-reload
systemctl enable node_exporter
systemctl restart node_exporter

echo "==> Cleaning up..."
rm -rf "$TMP_DIR"

echo "===================================="
echo "node_exporter installed successfully"
echo "Listening on :9100"
echo "===================================="
