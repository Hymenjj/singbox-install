#!/bin/bash
set -e

# 安装依赖
apt update && apt install -y curl jq git sing-box

# 生成参数
UUID=$(sing-box generate uuid)
KEYPAIR=$(sing-box generate reality-keypair)
PRIVATE_KEY=$(echo "$KEYPAIR" | grep "PrivateKey" | awk '{print $2}')
PUBLIC_KEY=$(echo "$KEYPAIR" | grep "PublicKey" | awk '{print $2}')
SHORT_ID=$(openssl rand -hex 4)

# 写入配置
cat > /etc/sing-box/config.json <<EOF
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": 443,
      "users": [ { "uuid": "$UUID", "flow": "xtls-rprx-vision" } ],
      "tls": {
        "enabled": true,
        "server_name": "www.cloudflare.com",
        "reality": {
          "enabled": true,
          "handshake": { "server": "www.cloudflare.com", "server_port": 443 },
          "private_key": "$PRIVATE_KEY",
          "short_id": ["$SHORT_ID"]
        }
      }
    }
  ],
  "outbounds": [
    { "type": "direct" },
    { "type": "block", "tag": "block" }
  ]
}
EOF

# 启动 sing-box
systemctl enable sing-box
systemctl restart sing-box

# 安装 subconverter
cd /opt
if [ ! -d "subconverter" ]; then
  git clone https://github.com/tindy2013/subconverter.git
fi
cd subconverter
./subconverter >/dev/null 2>&1 &

# 输出信息
IP=$(curl -s ifconfig.me)
echo -e "\n✅ Sing-box 已安装并运行"
echo "-----------------------------------"
echo "UUID:        $UUID"
echo "Reality 公钥: $PUBLIC_KEY"
echo "Short ID:    $SHORT_ID"
echo "VPS IP:      $IP"
echo "-----------------------------------"
echo "Clash 订阅链接:"
echo "http://$IP:25500/sub?target=clash"
echo "-----------------------------------"
