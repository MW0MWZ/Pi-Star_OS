#!/usr/bin/env bash
# Build and run Pi-Star in a container with a USB-serial hotspot.
#
#   docker/run.sh                 # pass the hotspot found now (ttyACM*/ttyUSB*)
#   docker/run.sh --hotplug       # share host /dev so the modem can re-enumerate
#                                 # (firmware flashing, unplug/replug)
#   docker/run.sh -- --debug      # anything after -- goes to pistar-mcp
#
# Env: HTTP_PORT (8880), HTTPS_PORT (8443), NAME (pistar), IMAGE (pistar-x86),
#      DATA_DIR (docker/data: persistent config, laid out like the OS's /data)
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
NAME=${NAME:-pistar}
IMAGE=${IMAGE:-pistar-x86}
HTTP_PORT=${HTTP_PORT:-8880}
HTTPS_PORT=${HTTPS_PORT:-8443}
DATA_DIR=${DATA_DIR:-$HERE/data}

hotplug=
while [ $# -gt 0 ]; do
	case "$1" in
		--hotplug) hotplug=1; shift ;;
		--) shift; break ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done
mcp_args=("$@")

args=(
	--name "$NAME" --hostname pi-star --rm -it
	-p "$HTTP_PORT:80" -p "$HTTPS_PORT:443"
	--tmpfs /run
	-e TZ="$(cat /etc/timezone 2>/dev/null || echo UTC)"
)
# The directories Pi-Star OS keeps on /data, bind-mounted from a host
# directory with the same layout (DATA_DIR/etc/mmdvmhost -> /etc/mmdvmhost).
# Empty ones are seeded from the package defaults by the entrypoint.
mkdir -p "$DATA_DIR"
DATA_DIR=$(cd "$DATA_DIR" && pwd)
for d in etc/mmdvmhost etc/dmrclients etc/dstarclients etc/ysfclients \
         etc/nxdnclients etc/p25clients etc/fmclients etc/aprsclients \
         etc/pocsagclients etc/dstarrepeater etc/pistar-mcp var/lib/pistar-mcp; do
	mkdir -p "$DATA_DIR/$d"
	args+=(-v "$DATA_DIR/$d:/$d")
done

if [ -n "$hotplug" ]; then
	# Host /dev, plus cgroup access to ttyACM (166), ttyUSB (188) and raw
	# USB (189, for dfu-util/stm32flash) whatever their minor numbers
	args+=(-v /dev:/dev
		--device-cgroup-rule='c 166:* rmw'
		--device-cgroup-rule='c 188:* rmw'
		--device-cgroup-rule='c 189:* rmw')
else
	shopt -s nullglob
	devs=(/dev/ttyACM* /dev/ttyUSB*)
	if [ ${#devs[@]} -eq 0 ]; then
		echo "No /dev/ttyACM* or /dev/ttyUSB* found: plug in the hotspot, or use --hotplug" >&2
		exit 1
	fi
	for dev in "${devs[@]}"; do args+=(--device "$dev"); done
	# by-id names (MCP's modem detection looks there); the links are
	# relative (../../ttyACM0) so they resolve to the passed device
	[ -d /dev/serial ] && args+=(-v /dev/serial:/dev/serial:ro)
fi

docker build -t "$IMAGE" "$HERE"
exec docker run "${args[@]}" "$IMAGE" "${mcp_args[@]}"
