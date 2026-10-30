# vtunx

一键部署 sing-box（vmess + ws），可选挂 Cloudflare Tunnel。支持 Alpine / Debian / Ubuntu。

## 变量

| 变量 | 说明 |
|---|---|
| `TPORT` | vmess 端口 |
| `TUUID` | vmess uuid |
| `THOST` | 隧道域名 |
| `TTOKEN` | Cloudflare Tunnel token |

规则：**4 个全传** → vmess + tunnel；**全不传** → 仅 vmess（随机端口/uuid）；**只传部分** → 报错。

## 脚本安装

```bash
# vmess + tunnel
wget -qO- https://github.com/vtunx/vtunx-node/raw/refs/heads/main/i.sh | TPORT='你的端口' TUUID='你的uuid' THOST='你的域名' TTOKEN='你的token' sh

# 仅 vmess（随机端口/uuid）
wget -qO- https://github.com/vtunx/vtunx-node/raw/refs/heads/main/i.sh | sh
```

执行完直接打印节点链接。

## Docker

```bash
docker run -d --restart unless-stopped \
  -e TPORT=你的端口 -e TUUID=你的uuid \
  -e THOST=你的域名 -e TTOKEN=你的token \
  ghcr.io/vtunx/vtunx-node:1.9.7
```

不传 `-e` 即随机端口/uuid 模式。隧道节点链接：`vmess://<UUID>@<你的域名>:443?type=ws&security=tls#节点名`。

内置 sing-box 1.9.7 与 cloudflared，启动不联网下载；版本升级需改 `Dockerfile`/`i.sh` 中的标签。