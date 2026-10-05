# shellcheck shell=sh
# bootslot.sh - per-slot boot files on the boot partition
# Part of Pi-Star OS. Sourced by pistar-upgrade, pistar-rollback,
# pistar-slot-info, the pistar-boot-layout service and the image build.
#
# Each root slot has its own directory on the boot partition holding its
# kernels, device trees, overlays and cmdline.txt:
#
#   /boot/firmware/slotA/   root=/dev/mmcblk0p2
#   /boot/firmware/slotB/   root=/dev/mmcblk0p3
#
# The firmware picks one through os_prefix in config.txt, so switching
# slots is a single small write and an upgrade never touches the running
# slot's boot files. GPU firmware (start*.elf, fixup*.dat, bootcode.bin)
# stays shared at the root: it is loaded before config.txt is read.

BOOTSLOT_FW_DIR="${PISTAR_FW_DIR:-/boot/firmware}"
BOOTSLOT_DISK="${PISTAR_DISK:-/dev/mmcblk0}"

# slot_part SLOT - partition number for slot A or B
slot_part() {
	case "$1" in
		A) echo 2 ;;
		B) echo 3 ;;
		*) return 1 ;;
	esac
}

# slot_dev SLOT - block device for slot A or B
slot_dev() {
	echo "${BOOTSLOT_DISK}p$(slot_part "$1")"
}

# other_slot SLOT - the other slot
other_slot() {
	case "$1" in
		A) echo B ;;
		B) echo A ;;
		*) return 1 ;;
	esac
}

# boot_prefix - os_prefix currently set in config.txt ("" if none)
boot_prefix() {
	sed -n 's/^[[:space:]]*os_prefix[[:space:]]*=[[:space:]]*//p' \
		"$BOOTSLOT_FW_DIR/config.txt" 2>/dev/null | tail -1 | tr -d '\r' | sed 's/[[:space:]]*$//'
}

# active_slot - slot selected by config.txt (A or B), or "" on the old
# shared layout
active_slot() {
	case "$(boot_prefix)" in
		slotA/) echo A ;;
		slotB/) echo B ;;
		*) echo "" ;;
	esac
}

# make_cmdline TEMPLATE SLOT - print TEMPLATE's kernel command line with
# root= pointing at SLOT, plus panic=10 (a panicking kernel reboots rather
# than hangs) and fsck.repair=yes
make_cmdline() {
	line=$(head -1 "$1" | tr -d '\r')
	dev=$(slot_dev "$2")
	case "$line" in
		*root=*) line=$(echo "$line" | sed "s|root=[^ ]*|root=$dev|") ;;
		*) line="$line root=$dev" ;;
	esac
	case " $line " in *" panic="*) ;; *) line="$line panic=10" ;; esac
	case " $line " in *" fsck.repair="*) ;; *) line="$line fsck.repair=yes" ;; esac
	echo "$line" | sed 's/^ *//'
}

# install_slot_boot SRC SLOT CMDLINE_TEMPLATE - (re)build SLOT's boot
# directory from the kernels, device trees and overlays in SRC (a
# /boot/firmware tree). Built as slotX.new and renamed into place, so an
# interruption leaves the previous copy intact.
install_slot_boot() {
	src="$1"
	slot="$2"
	template="$3"
	dest="$BOOTSLOT_FW_DIR/slot$slot"
	new="$dest.new"

	rm -rf "$new"
	mkdir -p "$new"
	found=0
	for f in "$src"/kernel*.img; do
		[ -f "$f" ] || continue
		cp "$f" "$new/"
		found=1
	done
	if [ "$found" -eq 0 ]; then
		rm -rf "$new"
		echo "bootslot: no kernel*.img in $src" >&2
		return 1
	fi
	for f in "$src"/*.dtb; do
		[ -f "$f" ] && cp "$f" "$new/"
	done
	if [ -d "$src/overlays" ]; then
		cp -r "$src/overlays" "$new/overlays"
	fi
	make_cmdline "$template" "$slot" > "$new/cmdline.txt"
	sync

	rm -rf "$dest.old"
	[ -d "$dest" ] && mv "$dest" "$dest.old"
	mv "$new" "$dest"
	rm -rf "$dest.old"
	sync
}

# set_active_slot SLOT - point config.txt's os_prefix at SLOT. The managed
# block is replaced by writing a temp file and renaming it over config.txt.
set_active_slot() {
	slot="$1"
	cfg="$BOOTSLOT_FW_DIR/config.txt"
	tmp="$cfg.tmp"
	[ -d "$BOOTSLOT_FW_DIR/slot$slot" ] || {
		echo "bootslot: $BOOTSLOT_FW_DIR/slot$slot does not exist" >&2
		return 1
	}
	# Drop any previous managed block and stray os_prefix lines
	awk '
		/^# >>> Pi-Star OS boot slot/ { skip = 1; next }
		/^# <<< Pi-Star OS boot slot/ { skip = 0; next }
		skip { next }
		/^[[:space:]]*os_prefix[[:space:]]*=/ { next }
		{ print }
	' "$cfg" > "$tmp"
	# os_prefix must apply to every model, so it needs an [all] filter -
	# unless the section in force at the end of the file already is one.
	filter=""
	last=$(sed -n 's/^[[:space:]]*\(\[[^]]*\]\).*/\1/p' "$tmp" | tail -1)
	if [ -n "$last" ] && [ "$last" != "[all]" ]; then
		filter="[all]
"
	fi
	cat >> "$tmp" <<EOF
# >>> Pi-Star OS boot slot (managed by pistar-upgrade / pistar-rollback)
# The active slot's kernels, device trees, overlays and cmdline.txt live
# under os_prefix. If this slot won't boot, edit this file on a PC and
# change slot$slot/ to slot$(other_slot "$slot")/.
${filter}os_prefix=slot$slot/
# <<< Pi-Star OS boot slot
EOF
	sync
	mv "$tmp" "$cfg"
	sync
}
