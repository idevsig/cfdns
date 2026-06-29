FROM alpine:latest AS builder

WORKDIR /app

RUN apk add curl jq

RUN <<EOF
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m | tr '[:upper:]' '[:lower:]')"
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH="arm64"
fi

DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/XIU2/CloudflareSpeedTest/releases/latest" | jq -r --arg os "$OS" --arg arch "$ARCH" '
        .assets[] 
        | select(.name | test($os) and test($arch)) 
        | .browser_download_url
    ')
curl -fsSL "$DOWNLOAD_URL" | tar -xzvf -
EOF

FROM alpine:latest
LABEL maintainer="Jetsung Chan<i@jetsung.com>"

WORKDIR /app

RUN apk add --no-cache curl bash jq cronie

COPY --from=builder /app/cfst /usr/local/bin/cfst
COPY --from=builder /app/ip.txt /app/ip.txt

COPY scripts/cfspeedtest.sh /usr/local/bin/cfspeedtest.sh
COPY scripts/cfdns.sh /usr/local/bin/cfdns
COPY README.md /app/README.md

RUN chmod +x /usr/local/bin/cfspeedtest.sh
RUN chmod +x /usr/local/bin/cfdns

RUN mkdir ~/.cache

RUN printf "%b" '#!'"/usr/bin/env bash\n \
if [ \"\$1\" = \"daemon\" ];  then \n \
 exec crond -n -s -m off \n \
else \n \
 exec -- \"\$@\"\n \
fi\n" >/entry.sh && chmod +x /entry.sh

VOLUME /app

ENTRYPOINT ["/entry.sh"]

CMD ["--help"]
