FROM alpine:3.24

ARG TARGETARCH
ARG SINGBOX_TAG=v1.14.4
ARG CLOUDFLARED_VERSION=2026.10.6

RUN set -eux; \
    apk add --no-cache ca-certificates tzdata xz; \
    case "${TARGETARCH}" in \
      amd64) A=amd64 ;; \
      arm64) A=arm64 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    wget -qO /tmp/sb.tar.xz \
      "https://github.com/clerzg/vtunx/releases/download/${SINGBOX_TAG}/sing-box-linux-${A}.tar.xz"; \
    tar -xJf /tmp/sb.tar.xz -C /usr/local/bin/ sing-box; \
    chmod +x /usr/local/bin/sing-box; \
    wget -qO /usr/local/bin/cloudflared \
      "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${A}"; \
    chmod +x /usr/local/bin/cloudflared; \
    rm -f /tmp/sb.tar.xz; \
    mkdir -p /etc/sing-box

COPY entry.sh /entry.sh
RUN chmod +x /entry.sh

ENTRYPOINT ["/entry.sh"]
