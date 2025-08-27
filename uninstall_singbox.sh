#!/bin/bash
set -e

echo "🛑 正在卸载 sing-box 和 subconverter..."

# 停止并禁用 sing-box
systemctl stop sing-box || true
systemctl disable sing-box || true

# 删除配置和程序
rm -rf /etc/sing-box
apt purge -y sing-box
apt autoremove -y

# 停止并删除 subconverter
pkill -f subconverter || true
rm -rf /opt/subconverter

echo "✅ 卸载完成"
