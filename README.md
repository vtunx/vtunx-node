# vmesss

Alpine 系统安装（sing-box + cloudflare tunnel）：

```
wget -qO- https://github.com/clerzg/vmesss/raw/refs/heads/main/i.sh | sh
```

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

## Docker 部署

镜像：`ghcr.io/clerzg/vmesss:latest`（amd64 / arm64）

```bash
docker run -d --name sing-box --restart unless-stopped \
  -e TPORT=11800 \
  -e TUUID=你的uuid \
  -e THOST=你的域名 \
  -e TTOKEN=你的cloudflare隧道token \
  ghcr.io/clerzg/vmesss:latest
```

节点链接（隧道模式）：

```
vmess://<UUID>@<你的域名>:443?type=ws&security=tls#节点名
```

说明：
- 容器内已内置 sing-box 与 cloudflared，启动不联网下载
- 隧道模式回源 `ws://127.0.0.1:<TPORT>`，端口在容器内独立，不与宿主冲突
- 开机自启由 `--restart unless-stopped` 负责，不需要 openrc
