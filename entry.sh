#!/bin/sh
set -e

[ -n "${TPORT}" ] || { echo "错误: 未设置 TPORT"; exit 1; }
[ -n "${TUUID}" ] || { echo "错误: 未设置 TUUID"; exit 1; }

mkdir -p /etc/sing-box
cat > /etc/sing-box/config.json <<EOF
{"log":{"disabled":true},"inbounds":[{"type":"vmess","listen":"::","listen_port":${TPORT},"users":[{"uuid":"${TUUID}"}],"transport":{"type":"ws"}}],"outbounds":[{"type":"direct"}]}
EOF

if [ -n "${TTOKEN}" ]; then
    cloudflared tunnel --no-autoupdate run --token "${TTOKEN}" &
    echo "cloudflared 已启动（隧道模式，回源 ws://127.0.0.1:${TPORT}）"
fi

echo "sing-box 监听端口: ${TPORT}"
exec sing-box run -c /etc/sing-box/config.json
