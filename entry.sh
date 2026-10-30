#!/bin/sh
set -e

# ============ 环境变量 ============
# TPORT  : vmess 端口
# TUUID  : vmess uuid
# THOST  : vmess host（隧道域名）
# TTOKEN : Cloudflare Tunnel token
# 4 个都传 -> 部署 vmess + cloudflare tunnel
# 都不传   -> 只部署 vmess（随机端口 + 随机 uuid）
# 少传     -> 报错退出
# ==================================

if [ -n "${TPORT}" ] && [ -n "${TUUID}" ] && [ -n "${THOST}" ] && [ -n "${TTOKEN}" ]; then
    MODE="tunnel"
    PORT="${TPORT}"
    UUID="${TUUID}"
    HOST="${THOST}"
    echo "✔ 已传入全部变量，启用 vmess + cloudflare tunnel"
elif [ -z "${TPORT}" ] && [ -z "${TUUID}" ] && [ -z "${THOST}" ] && [ -z "${TTOKEN}" ]; then
    MODE="vmess"
    PORT=$(awk 'BEGIN{srand(); print int(rand()*50000)+10000}')
    if [ -f /proc/sys/kernel/random/uuid ]; then
        UUID=$(cat /proc/sys/kernel/random/uuid)
    else
        UUID=$(awk 'BEGIN{
            srand();
            split("abcdef0123456789", c, "");
            for(i=1;i<=36;i++) {
                if(i==9 || i==14 || i==19 || i==24) printf "-";
                else printf c[int(rand()*16)+1];
            }
            print "";
        }')
    fi
    HOST="gw.alicdn.com"
    echo "✔ 未传入任何变量，仅部署 vmess（随机端口/uuid）"
else
    GOT=""
    if [ -n "${TPORT}" ]; then GOT="${GOT} TPORT"; fi
    if [ -n "${TUUID}" ]; then GOT="${GOT} TUUID"; fi
    if [ -n "${THOST}" ]; then GOT="${GOT} THOST"; fi
    if [ -n "${TTOKEN}" ]; then GOT="${GOT} TTOKEN"; fi
    echo "❌ 错误：TPORT / TUUID / THOST / TTOKEN 必须全部传入，或全部不传" >&2
    echo "   当前已传入:${GOT}" >&2
    exit 1
fi

# ---------- sing-box 配置 ----------
mkdir -p /etc/sing-box
cat > /etc/sing-box/config.json <<EOF
{"log":{"disabled":true},"inbounds":[{"type":"vmess","listen":"::","listen_port":${PORT},"users":[{"uuid":"${UUID}"}],"transport":{"type":"ws"}}],"outbounds":[{"type":"direct"}]}
EOF

# ---------- cloudflare tunnel ----------
if [ "${MODE}" = "tunnel" ]; then
    cloudflared tunnel --no-autoupdate run --token "${TTOKEN}" &
    echo "✔ cloudflared 已启动（回源 ws://127.0.0.1:${PORT}）"
fi

# ---------- 输出信息 ----------
INFO=$(wget -qO- -T 5 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null || true)
if [ -z "${INFO}" ]; then
    INFO=$(wget -qO- -T 5 https://1.1.1.1/cdn-cgi/trace 2>/dev/null || true)
fi
IP=$(echo "${INFO}" | awk -F= '/^ip=/ {print $2}')
LOC=$(echo "${INFO}" | awk -F= '/^loc=/ {print $2}')

echo ""
echo "🎉 部署完成！"
echo ""
echo "🚀节点链接："
echo "vmess://${UUID}@${IP}:${PORT}?type=ws&host=${HOST}#${LOC}"
if [ "${MODE}" = "tunnel" ]; then
    echo "vmess://${UUID}@${HOST}:443?type=ws&security=tls#${LOC}"
fi
echo ""
echo "端口: ${PORT}"
echo "UUID: ${UUID}"
echo "Host: ${HOST}"
if [ "${MODE}" = "tunnel" ]; then
    echo "Tunnel: 已启用"
fi
echo ""

exec sing-box run -c /etc/sing-box/config.json
