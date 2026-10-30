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
CFD_BIN="/usr/local/bin/cloudflared"
CONFIG_PATH="/etc/sing-box"

if [ "${INIT}" = "openrc" ]; then
    SB_INIT_FILE="/etc/init.d/sing-box"
    CFD_INIT_FILE="/etc/init.d/cloudflared"
    rc-service sing-box stop >/dev/null 2>&1
    rc-service cloudflared stop >/dev/null 2>&1
    rc-update del sing-box default >/dev/null 2>&1
    rc-update del cloudflared default >/dev/null 2>&1
else
    SB_INIT_FILE="/etc/systemd/system/sing-box.service"
    CFD_INIT_FILE="/etc/systemd/system/cloudflared.service"
    systemctl stop sing-box cloudflared >/dev/null 2>&1
    systemctl disable sing-box cloudflared >/dev/null 2>&1
    systemctl daemon-reload >/dev/null 2>&1
fi

# ---------- 删除 ----------
rm -f "${SB_INIT_FILE}" "${CFD_INIT_FILE}" "${SB_BIN}" "${CFD_BIN}"
rm -rf "${CONFIG_PATH}"
rm -f /var/log/cloudflared.log

echo "🎉 已卸载 sing-box 与 cloudflared"