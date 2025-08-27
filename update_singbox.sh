#!/bin/bash
set -e

echo "⬆️ 正在更新系统和 sing-box..."

# 更新系统和 sing-box
apt update
apt install -y sing-box

# 重启 sing-box
systemctl restart sing-box

echo "✅ sing-box 已更新并重启"
systemctl status sing-box --no-pager -l
