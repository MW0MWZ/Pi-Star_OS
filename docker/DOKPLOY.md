# Running under Dokploy

The hotspot must be plugged into the server Dokploy deploys the service to.

1. **Traefik**: add `dokploy-traefik.yml` as `/etc/dokploy/traefik/dynamic/pistar.yml`
   (Traefik → File System → `dynamic`). It lets Traefik talk HTTPS to the
   dashboard's self-signed certificate. MCP redirects `:80` to `:443` and
   ignores `X-Forwarded-Proto`, so proxying to `:80` would loop.
2. **Create → Compose**, type **Docker Compose** (not *Stack*: Swarm cannot
   pass USB devices or cgroup rules).
   - Provider: this Git repo, branch with `docker/`.
   - Compose path: `./docker/docker-compose.yml`
3. **Environment**: `PISTAR_DOMAIN=pistar.example.com`, `TZ=Europe/London`,
   optionally `HTTPS_PORT` (direct LAN port, default 8443).
4. Do **not** add a domain in the Domains tab: the compose file carries its
   own Traefik labels (HTTPS backend), and Dokploy's generated ones would
   point at `:80`.
5. Deploy. Log in as `pi-star` / `raspberry` and change the password.

Configuration lives in named volumes (`etc-mmdvmhost`, `etc-pistar-mcp`, …),
seeded from the package defaults on first start; back them up with Dokploy's
volume backups. Host `/dev` is shared so the modem survives re-enumerating
(firmware flashing).
