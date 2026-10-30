FROM alpine:3.24

# latest = 跟随各自仓库的最新 release；也可传具体版本号固定，例如
#   --build-arg SINGBOX_TAG=v1.14.4 --build-arg CLOUDFLARED_VERSION=2026.10.6
ARG TARGETARCH
ARG SINGBOX_TAG=latest
ARG CLOUDFLARED_VERSION=latest

RUN set -eux; \
    apk add --no-cache ca-certificates tzdata xz; \
    case "${TARGETARCH}" in \
      amd64) A=amd64 ;; \
      arm64) A=arm64 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    if [ "${SINGBOX_TAG}" = "latest" ]; then \
      SB_URL="https://github.com/clerzg/vtunx/releases/latest/download/sing-box-linux-${A}.tar.xz"; \
    else \
      SB_URL="https://github.com/clerzg/vtunx/releases/download/${SINGBOX_TAG}/sing-box-linux-${A}.tar.xz"; \
    fi; \
    if [ "${CLOUDFLARED_VERSION}" = "latest" ]; then \
      CFD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${A}"; \
    else \
      CFD_URL="https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${A}"; \
    fi; \
    wget -qO /tmp/sb.tar.xz "${SB_URL}"; \
    tar -xJf /tmp/sb.tar.xz -C /usr/local/bin/ sing-box; \
    chmod +x /usr/local/bin/sing-box; \
    wget -qO /usr/local/bin/cloudflared "${CFD_URL}"; \
    chmod +x /usr/local/bin/cloudflared; \
    rm -f /tmp/sb.tar.xz; \
    mkdir -p /etc/sing-box

COPY entry.sh /entry.sh
RUN chmod +x /entry.sh

ENTRYPOINT ["/entry.sh"]
