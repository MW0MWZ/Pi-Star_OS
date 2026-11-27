# Pi-Star (MCP + MMDVM stack) on x86_64 Alpine, for development and testing
# with a USB-serial hotspot. Not the OS image: no A/B slots, no boot
# partition, no WiFi management. MCP runs in the foreground as PID 1's
# child and supervises the radio services itself.

ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION}
ARG ALPINE_VERSION

# openssl: MCP verifies dashboard logins against /etc/shadow with
# `openssl passwd` (BusyBox mkpasswd alone fails); the OS image has it too
RUN wget -qO /etc/apk/keys/hamradio.rsa.pub https://apk.pistar.uk/hamradio.rsa.pub \
 && echo "https://apk.pistar.uk/v${ALPINE_VERSION}/community" >> /etc/apk/repositories \
 && apk add --no-cache \
      tini \
      ca-certificates \
      tzdata \
      openssl \
      sudo \
      shadow \
      pi-star

# Same account the image creates; MCP's login checks /etc/shadow
RUN adduser -D -s /bin/sh pi-star \
 && addgroup pi-star wheel \
 && echo "pi-star:raspberry" | chpasswd \
 && addgroup pi-star dialout \
 && echo "pi-star" > /etc/hostname

# The directories Pi-Star OS keeps on /data (relative to /). run.sh
# bind-mounts each from the host data directory; a copy of the package
# defaults is kept so the entrypoint can seed empty ones, as
# pistar-bindmounts does on the OS.
ENV PISTAR_PERSIST_DIRS="etc/mmdvmhost etc/dmrclients etc/dstarclients etc/ysfclients etc/nxdnclients etc/p25clients etc/fmclients etc/aprsclients etc/pocsagclients etc/dstarrepeater etc/pistar-mcp var/lib/pistar-mcp"
RUN for d in $PISTAR_PERSIST_DIRS; do \
      mkdir -p "/$d" "/usr/share/pistar-docker/defaults/$d" \
      && cp -a "/$d/." "/usr/share/pistar-docker/defaults/$d/"; \
    done

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80 443
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
