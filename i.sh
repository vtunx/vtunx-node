#!/bin/sh

# ---------- 系统检测 ----------
if [ -f /etc/alpine-release ]; then
    INIT="openrc"
elif [ -f /etc/debian_version ]; then
    INIT="systemd"
else
    echo "❌ 错误：仅支持 Alpine / Debian / Ubuntu"
    exit 1
fi

SB_BIN="/usr/local/bin/sing-box"
CONFIG_PATH="/etc/sing-box"
CONFIG_FILE="${CONFIG_PATH}/config.json"
CFD_BIN="/usr/local/bin/cloudflared"
MY_RELEASE_URL="https://github.com/vtunx/vtunx-node/releases/latest/download"

if [ "${INIT}" = "openrc" ]; then
    SB_INIT_FILE="/etc/init.d/sing-box"
    CFD_INIT_FILE="/etc/init.d/cloudflared"
else
    SB_INIT_FILE="/etc/systemd/system/sing-box.service"
    CFD_INIT_FILE="/etc/systemd/system/cloudflared.service"
fi

# ============ 环境变量 ============
# TPORT  : vmess 端口
# TUUID  : vmess uuid
# THOST  : vmess host
# TTOKEN : Cloudflare Tunnel token
# 4 个都传 -> 部署 vmess + cloudflare tunnel
# 都不传   -> 只部署 vmess（随机端口 + 随机 uuid）
# 少传     -> 报错退出
# ==================================

# ---------- 依赖 ----------
if [ "${INIT}" = "openrc" ]; then
    command -v xz >/dev/null 2>&1 || apk add --no-cache xz >/dev/null 2>&1
else
    if ! command -v wget >/dev/null 2>&1 || ! command -v xz >/dev/null 2>&1; then
        echo "安装依赖"
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq wget xz-utils ca-certificates >/dev/null 2>&1
    fi
fi

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

if wget -qO /tmp/sing-box.tar.xz "${DOWNLOAD_URL}" && \
   tar -xJf /tmp/sing-box.tar.xz -C /usr/local/bin/ sing-box; then
    chmod +x ${SB_BIN}
    rm -f /tmp/sing-box.tar.xz
else
    rm -f /tmp/sing-box.tar.xz
    echo "错误: 无法下载sing-box"
    exit 1
fi

if [ ! -s ${SB_BIN} ]; then
    echo "错误: sing-box 二进制缺失"
    exit 1
fi

# ---------- 参数判定 ----------
if [ -n "${TPORT}" ] && [ -n "${TUUID}" ] && [ -n "${THOST}" ] && [ -n "${TTOKEN}" ]; then
    MODE="tunnel"
    PORT="${TPORT}"
    UUID="${TUUID}"
    HOST="${THOST}"
    echo "✔ 已传入全部变量，启用 vmess + cloudflare tunnel"
elif [ -z "${TPORT}" ] && [ -z "${TUUID}" ] && [ -z "${THOST}" ] && [ -z "${TTOKEN}" ]; then
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
mkdir -p ${CONFIG_PATH}

cat <<EOF > ${CONFIG_FILE}
{"log":{"disabled":true},"inbounds":[{"type":"vmess","listen":"::","listen_port":${PORT},"users":[{"uuid":"${UUID}"}],"transport":{"type":"ws"}}],"outbounds":[{"type":"direct"}]}
EOF

# ---------- sing-box 服务 ----------
if [ "${INIT}" = "openrc" ]; then
    cat << 'EOF' > ${SB_INIT_FILE}
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
    chmod +x ${SB_INIT_FILE}
    rc-update add sing-box default >/dev/null 2>&1
    rc-service sing-box restart >/dev/null 2>&1
else
    cat << 'EOF' > ${SB_INIT_FILE}
[Unit]
Description=Sing-box Minimal Service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=always
RestartSec=1
Environment=GOGC=10
Environment=GOMEMLIMIT=20MiB

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable sing-box >/dev/null 2>&1
    systemctl restart sing-box >/dev/null 2>&1
fi

# ---------- cloudflare tunnel ----------
if [ "${MODE}" = "tunnel" ]; then
    echo "下载 cloudflared"
    mkdir -p /usr/local/bin
    if wget -qO ${CFD_BIN} "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${SB_ARCH}"; then
        chmod +x ${CFD_BIN}
    else
        echo "错误: 无法下载 cloudflared"
        exit 1
    fi

    if [ "${INIT}" = "openrc" ]; then
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
    else
        cat << EOF > ${CFD_INIT_FILE}
[Unit]
Description=Cloudflare Tunnel Service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token ${TTOKEN}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload >/dev/null 2>&1
        systemctl enable cloudflared >/dev/null 2>&1
        systemctl restart cloudflared >/dev/null 2>&1
    fi
fi

# ---------- 输出信息 ----------
INFO=$(wget -qO- -T 5 "https://www.cloudflare.com/cdn-cgi/trace")
if [ -z "${INFO}" ]; then
    INFO=$(wget -qO- -T 5 "https://1.1.1.1/cdn-cgi/trace")
fi
IP=$(echo "${INFO}" | awk -F= '/^ip=/ {print $2}')
LOC=$(echo "${INFO}" | awk -F= '/^loc=/ {print $2}')

if [ "${INIT}" = "openrc" ]; then
    ST_CMD="rc-service sing-box status"
    ST_CMD_CFD="rc-service cloudflared status"
else
    ST_CMD="systemctl status sing-box"
    ST_CMD_CFD="systemctl status cloudflared"
fi

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
    echo "Tunnel: 已启用（cloudflared，回源 ws://127.0.0.1:${PORT}）"
fi
echo ""
echo "查看状态: ${ST_CMD}"
if [ "${MODE}" = "tunnel" ]; then
    echo "查看隧道: ${ST_CMD_CFD}"
fi
echo ""
echo "开机自启已设置：sing-box"
if [ "${MODE}" = "tunnel" ]; then
    echo "开机自启已设置：cloudflared"
fi
echo ""
