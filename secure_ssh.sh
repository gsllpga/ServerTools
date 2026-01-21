#!/bin/bash

set -e

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.bak.$(date +%F_%H-%M-%S)"
SSH_USER="${SUDO_USER:-$USER}"

echo "========== SSH 安全加固脚本 =========="
echo "当前用户: $SSH_USER"
echo

# ---------- 收集信息 ----------
read -p "是否修改 SSH 端口？(y/n): " CHANGE_PORT
if [[ "$CHANGE_PORT" =~ ^[Yy]$ ]]; then
    read -p "请输入新的 SSH 端口 (1-65535): " NEW_PORT
    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
        echo "❌ 端口号不合法"
        exit 1
    fi
fi

read -p "是否启用 Key 登录？(y/n): " ENABLE_KEY
if [[ "$ENABLE_KEY" =~ ^[Yy]$ ]]; then
    read -p "请粘贴 SSH 公钥（ssh-rsa / ssh-ed25519 等）: " SSH_KEY
    if [[ -z "$SSH_KEY" ]]; then
        echo "❌ 公钥不能为空"
        exit 1
    fi
fi

read -p "是否禁用密码登录？(y/n): " DISABLE_PASSWORD

echo
echo "========== 配置确认 =========="
[[ "$CHANGE_PORT" =~ ^[Yy]$ ]] && echo "✔ 修改端口为: $NEW_PORT" || echo "✘ 不修改端口"
[[ "$ENABLE_KEY" =~ ^[Yy]$ ]] && echo "✔ 启用 Key 登录" || echo "✘ 不启用 Key 登录"
[[ "$DISABLE_PASSWORD" =~ ^[Yy]$ ]] && echo "✔ 禁用密码登录" || echo "✘ 不禁用密码登录"
echo

read -p "确认执行以上修改？(y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo "已取消" && exit 0

# ---------- 开始执行 ----------
echo
echo "▶ 备份 sshd_config 到 $BACKUP_FILE"
cp "$SSHD_CONFIG" "$BACKUP_FILE"

# 统一替换或追加配置
set_sshd_option() {
    local key="$1"
    local value="$2"
    if grep -qE "^[# ]*$key" "$SSHD_CONFIG"; then
        sed -i "s|^[# ]*$key.*|$key $value|" "$SSHD_CONFIG"
    else
        echo "$key $value" >> "$SSHD_CONFIG"
    fi
}

# 修改端口
if [[ "$CHANGE_PORT" =~ ^[Yy]$ ]]; then
    set_sshd_option "Port" "$NEW_PORT"
fi

# 启用 Key 登录
if [[ "$ENABLE_KEY" =~ ^[Yy]$ ]]; then
    set_sshd_option "PubkeyAuthentication" "yes"
    set_sshd_option "AuthorizedKeysFile" ".ssh/authorized_keys"

    USER_HOME=$(eval echo "~$SSH_USER")
    SSH_DIR="$USER_HOME/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    touch "$AUTH_KEYS"

    if ! grep -qF "$SSH_KEY" "$AUTH_KEYS"; then
        echo "$SSH_KEY" >> "$AUTH_KEYS"
    fi

    chmod 600 "$AUTH_KEYS"
    chown -R "$SSH_USER:$SSH_USER" "$SSH_DIR"
fi

# 禁用密码登录 & root 密码登录
if [[ "$DISABLE_PASSWORD" =~ ^[Yy]$ ]]; then
    set_sshd_option "PasswordAuthentication" "no"
    set_sshd_option "PermitRootLogin" "prohibit-password"
fi

# SSH 配置测试
echo
echo "▶ 检查 SSH 配置..."
sshd -t || {
    echo "❌ SSH 配置校验失败，已恢复备份"
    cp "$BACKUP_FILE" "$SSHD_CONFIG"
    exit 1
}

# 重启 SSH 服务
echo "▶ 重启 SSH 服务..."
if systemctl is-active sshd &>/dev/null; then
    systemctl restart sshd
elif systemctl is-active ssh &>/dev/null; then
    systemctl restart ssh
else
    service ssh restart || service sshd restart
fi

echo
echo "✅ SSH 配置完成！"
echo "⚠️ 请不要关闭当前 SSH，新开一个窗口测试新端口/Key 无误后再关闭"
