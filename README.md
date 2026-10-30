# vtunx

一键安装 sing-box（vmess + ws），可选挂 Cloudflare Tunnel。

支持 **Alpine / Debian / Ubuntu**，自动识别 init 系统（Alpine 用 openrc，Debian/Ubuntu 用 systemd）。

## 变量

| 变量 | 说明 |
|---|---|
| `TPORT` | vmess 端口 |
| `TUUID` | vmess uuid |
| `THOST` | vmess host（隧道域名） |
| `TTOKEN` | Cloudflare Tunnel token |

规则：

- **4 个全传** → 部署 vmess + cloudflare tunnel
- **全部不传** → 只部署 vmess（随机端口 + 随机 uuid）
- **只传一部分** → 报错退出

## 脚本安装（Alpine / Debian / Ubuntu）

**传参部署（vmess + tunnel）** —— 先 `export` 再执行，管道里的 `sh` 才拿得到变量：

```bash
export TPORT=你的端口
export TUUID=你的uuid
export THOST=你的域名
export TTOKEN=你的cloudflare隧道token
wget -qO- https://github.com/vtunx/vtunx-node/raw/refs/heads/main/i.sh | sh
```

**不传参（仅 vmess，随机端口 + 随机 uuid）**：

```bash
wget -qO- https://github.com/vtunx/vtunx-node/raw/refs/heads/main/i.sh | sh
```

脚本结束会直接打印节点链接。

## Docker 部署

镜像：`ghcr.io/vtunx/vtunx-node:latest`（amd64 / arm64）

```bash
docker run -d --name sing-box --restart unless-stopped \
  -e TPORT=你的端口 \
  -e TUUID=你的uuid \
  -e THOST=你的域名 \
  -e TTOKEN=你的cloudflare隧道token \
  ghcr.io/vtunx/vtunx-node:latest
```

不传任何 `-e` 即为随机端口 + 随机 uuid 模式。

节点链接（隧道模式）：

```
vmess://<UUID>@<你的域名>:443?type=ws&security=tls#节点名
```

说明：
- 容器内已内置 sing-box 与 cloudflared，启动不联网下载
- 隧道模式回源 `ws://127.0.0.1:<TPORT>`，端口在容器内独立，不与宿主冲突
- 开机自启由 `--restart unless-stopped` 负责，不需要 openrc
