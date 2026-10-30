#!/bin/sh

if [ ! -f /etc/alpine-release ]; then
    echo "❌ 错误：仅支持 Alpine Linux"
    exit 1
fi

SB_BIN="/usr/local/bin/sing-box"
CONFIG_PATH="/etc/sing-box"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/sing-box"
CFD_BIN="/usr/local/bin/cloudflared"
CFD_INIT_FILE="/etc/init.d/cloudflared"
MY_RELEASE_URL="https://github.com/clerzg/vmesss/releases/latest/download"

# ============ 环境变量 ============
# TPORT  : vmess 端口
# TUUID  : vmess uuid
# THOST  : vmess host
# TTOKEN : Cloudflare Tunnel token
# 4 个都传 -> 部署 vmess + cloudflare tunnel
# 都不传   -> 只部署 vmess（随机端口 + 随机 uuid）
# ==================================

echo "检测架构"
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) SB_ARCH="amd64" ;;
    aarch64|arm64) SB_ARCH="arm64" ;;
    *) SB_ARCH="amd64" ;;
esac

# ---------- 下载 sing-box ----------
echo "下载 sing-box"
DOWNLOAD_URL="${MY_RELEASE_URL}/sing-box-linux-${SB_ARCH}.tar.xz"
mkdir -p /usr/local/bin

wget -qO- "${DOWNLOAD_URL}" | tar -xJ -C /usr/local/bin/

if [ $? -eq 0 ] && [ -s ${SB_BIN} ]; then
    chmod +x ${SB_BIN}
else
    echo "错误: 无法下载sing-box"
    exit 1
fi

# ---------- 参数判定 ----------
if [ -n "${TPORT}" ] && [ -n "${TUUID}" ] && [ -n "${THOST}" ] && [ -n "${TTOKEN}" ]; then
    MODE="tunnel"
    PORT="${TPORT}"
    UUID="${TUUID}"
    HOST="${THOST}"
    echo "✔ 已传入全部变量，启用 vmess + cloudflare tunnel"
else
    MODE="vmess"
    # 随机端口
    PORT=$(awk 'BEGIN{srand(); print int(rand()*50000)+10000}')
    # 随机 uuid
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
    echo "✔ 未传入完整变量，仅部署 vmess（随机端口/uuid）"
fi

# ---------- sing-box 配置 ----------
mkdir -p ${CONFIG_PATH}

cat <<EOF > ${CONFIG_FILE}
{"log":{"disabled":true},"inbounds":[{"type":"vmess","listen":"::","listen_port":${PORT},"users":[{"uuid":"${UUID}"}],"transport":{"type":"ws"}}],"outbounds":[{"type":"direct"}]}
EOF

# ---------- sing-box 服务 ----------
cat << 'EOF' > ${INIT_FILE}
#!/sbin/openrc-run
description="Sing-box Minimal Service"
command="/usr/local/bin/sing-box"
command_args="run -c /etc/sing-box/config.json"
pidfile="/run/${RC_SVCNAME}.pid"
command_background="yes"

export GOGC=10
export GOMEMLIMIT=20MiB

respawn_delay=1
respawn_max=0
EOF

chmod +x ${INIT_FILE}
rc-update add sing-box default >/dev/null 2>&1
rc-service sing-box restart >/dev/null 2>&1

# ---------- cloudflare tunnel ----------
if [ "${MODE}" = "tunnel" ]; then
    echo "下载 cloudflared"
    mkdir -p /usr/local/bin
    wget -qO ${CFD_BIN} "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${SB_ARCH}"
    if [ $? -eq 0 ] && [ -s ${CFD_BIN} ]; then
        chmod +x ${CFD_BIN}
    else
        echo "错误: 无法下载 cloudflared"
        exit 1
    fi

    cat << EOF > ${CFD_INIT_FILE}
#!/sbin/openrc-run
description="Cloudflare Tunnel Service"
command="/usr/local/bin/cloudflared"
command_args="tunnel --no-autoupdate run --token ${TTOKEN}"
pidfile="/run/\${RC_SVCNAME}.pid"
command_background="yes"
output_log="/var/log/cloudflared.log"
error_log="/var/log/cloudflared.log"

respawn_delay=5
respawn_max=0
EOF

    chmod +x ${CFD_INIT_FILE}
    rc-update add cloudflared default >/dev/null 2>&1
    rc-service cloudflared restart >/dev/null 2>&1
fi

# ---------- 输出信息 ----------
INFO=$(wget -qO- "https://1.1.1.1/cdn-cgi/trace")
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
[ "${MODE}" = "tunnel" ] && echo "Tunnel: 已启用（cloudflared，回源 ws://127.0.0.1:${PORT}）"
echo ""
echo "查看状态: rc-service sing-box status"
[ "${MODE}" = "tunnel" ] && echo "查看隧道: rc-service cloudflared status"
echo ""
echo "开机自启已设置：sing-box${MODE:+$([ "${MODE}" = "tunnel" ] && echo ' / cloudflared')}"
echo ""
