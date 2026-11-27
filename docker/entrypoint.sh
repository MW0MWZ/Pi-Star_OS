#!/bin/sh
# Container entrypoint: what /etc/init.d/pistar-mcp's start_pre does on the
# OS (the x86_64 package ships no init scripts), then MCP in the foreground.
set -e

CONFIG="${PISTAR_MCP_CONFIG:-/etc/pistar-mcp/pistar-mcp.ini}"

# Seed empty persistent directories (host bind mounts start empty) from
# the package defaults kept in the image, as pistar-bindmounts does
for d in $PISTAR_PERSIST_DIRS; do
	mkdir -p "/$d"
	if [ -z "$(ls -A "/$d" 2>/dev/null)" ] && [ -d "/usr/share/pistar-docker/defaults/$d" ]; then
		cp -a "/usr/share/pistar-docker/defaults/$d/." "/$d/"
		echo "Seeded /$d from package defaults"
	fi
done

if [ ! -f "$CONFIG" ] && [ -f /etc/pistar-mcp/pistar-mcp.ini.example ]; then
	echo "Creating $CONFIG from example"
	cp /etc/pistar-mcp/pistar-mcp.ini.example "$CONFIG"
fi

# Modem configs from the package templates, as mmdvmhost's post-install
# does (a fresh volume over /etc/mmdvmhost starts from the image copy, but
# keep this for volumes created before the package seeded them)
for name in MMDVM-Host MMDVM-Display MMDVM-Info; do
	if [ ! -f /etc/mmdvmhost/$name.ini ] && [ -f /usr/share/mmdvmhost/$name.ini.example ]; then
		cp /usr/share/mmdvmhost/$name.ini.example /etc/mmdvmhost/$name.ini
	fi
done
[ -f /etc/mmdvmhost/RSSI.dat ] || cp /usr/share/mmdvmhost/RSSI_MMDVM_HS.dat /etc/mmdvmhost/RSSI.dat 2>/dev/null || true

mkdir -p /etc/pistar-mcp/certs /var/lib/pistar-mcp/backups /var/log/pistar-mcp /var/log/mmdvmhost /run/pistar
chown mmdvm:mmdvm /var/log/mmdvmhost 2>/dev/null || true

echo "Serial devices visible in the container:"
ls -l /dev/ttyACM* /dev/ttyUSB* /dev/serial/by-id 2>/dev/null || echo "  (none: is the hotspot plugged in and passed with --device?)"

exec /usr/bin/pistar-mcp --config "$CONFIG" "$@"
