#!/bin/bash
set -e

# 安装依赖
apt update && apt install -y curl jq git sing-box python3-minimal

# 生成参数
UUID=$(sing-box generate uuid)
KEYPAIR=$(sing-box generate reality-keypair)
PRIVATE_KEY=$(echo "$KEYPAIR" | grep "PrivateKey" | awk '{print $2}')
PUBLIC_KEY=$(echo "$KEYPAIR" | grep "PublicKey" | awk '{print $2}')
SHORT_ID=$(openssl rand -hex 4)
IP=$(curl -s ifconfig.me)

# 写入 sing-box 配置
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

# 安装 subconverter
cd /opt
if [ ! -d "subconverter" ]; then
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/tindy2013/subconverter/releases/latest" | jq -r '.tag_name')
    curl -fsSL "https://github.com/tindy2013/subconverter/releases/download/${LATEST_VERSION}/subconverter_linux64.tar.gz" -o subconverter.tar.gz
    tar -zxvf subconverter.tar.gz
    rm subconverter.tar.gz
fi

# 写入 subconverter systemd 服务文件
cat > /etc/systemd/system/subconverter.service <<EOF
[Unit]
Description=subconverter service
After=network.target

[Service]
ExecStart=/opt/subconverter/subconverter
WorkingDirectory=/opt/subconverter
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

# 创建 VLESS 文件
mkdir -p /var/www/vless
VLESS_URL_RAW="vless://$UUID@$IP:443?encryption=none&security=reality&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&sni=www.cloudflare.com"
echo "$VLESS_URL_RAW" > /var/www/vless/vless.txt

# 写入 python 轻量级服务器 systemd 服务文件
cat > /etc/systemd/system/vless-server.service <<EOF
[Unit]
Description=VLESS Link Server
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server 8080
WorkingDirectory=/var/www/vless
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sing-box subconverter vless-server
systemctl restart sing-box subconverter vless-server

# 输出信息
VLESS_URL_ENCODED=$(echo "$VLESS_URL_RAW" | sed 's/ /%20/g')

echo -e "\n✅ Sing-box 已安装并运行"
echo "-----------------------------------"
echo "UUID:        $UUID"
echo "Reality 公钥: $PUBLIC_KEY"
echo "Short ID:    $SHORT_ID"
echo "VPS IP:      $IP"
echo "-----------------------------------"
echo "Clash 订阅链接:"
echo "http://$IP:25500/sub?target=clash&url=http://$IP:8080/vless.txt"
echo "-----------------------------------"
