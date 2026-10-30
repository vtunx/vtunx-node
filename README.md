# vlesss


适用于 alpine 系统

安装命令
```
wget -qO- https://github.com/clerzg/vlesss/raw/refs/heads/main/i.sh | sh
```

## Docker 部署

镜像：`ghcr.io/clerzg/vmesss:latest`（amd64 / arm64）

```bash
docker run -d --name sing-box --restart unless-stopped \
  -e TPORT=11800 \
  -e TUUID=你的uuid \
  -e TTOKEN=你的cloudflare隧道token \
  ghcr.io/clerzg/vmesss:latest
```

| 变量 | 必填 | 说明 |
|---|---|---|
| `TPORT` | 是 | vmess 监听端口 |
| `TUUID` | 是 | vmess uuid |
| `TTOKEN` | 否 | Cloudflare Tunnel token，不传则只跑 vmess 直连 |

节点链接（隧道模式）：

```
vmess://<UUID>@<你的域名>:443?type=ws&security=tls#节点名
```

说明：
- 容器内已内置 sing-box 与 cloudflared，启动不联网下载
- 隧道模式回源 `ws://127.0.0.1:<TPORT>`，端口在容器内独立，不与宿主冲突
- 开机自启由 `--restart unless-stopped` 负责，不需要 openrc
