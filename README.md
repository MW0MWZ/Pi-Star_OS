# Pi-Star OS - Next-Generation Pi-Star Platform

[![Build Status](https://github.com/MW0MWZ/Pi-Star_OS/actions/workflows/build.yml/badge.svg)](https://github.com/MW0MWZ/Pi-Star_OS/actions/workflows/build.yml)
[![Latest Release](https://img.shields.io/github/v/release/MW0MWZ/Pi-Star_OS)](https://github.com/MW0MWZ/Pi-Star_OS/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/MW0MWZ/Pi-Star_OS/total)](https://github.com/MW0MWZ/Pi-Star_OS/releases)
[![Alpine Version](https://img.shields.io/badge/Alpine-v3.23-0D597F)](https://alpinelinux.org)
[![Kernel](https://img.shields.io/badge/dynamic/json?url=https://raspine.pistar.uk/packages.json&query=$.kernel_version&label=Kernel&color=c51a4a)](https://www.raspberrypi.org)

> **Router-style upgrades for Pi-Star.** Raspberry Pi OS kernel with Alpine Linux userland, A/B root partitions for safe over-the-air updates, and zero-touch configuration from the boot partition.

## Key Features

| Feature | Description |
|---------|-------------|
| **A/B Root Partitions** | Safe upgrades with automatic rollback — if a new version fails, the system reverts itself |
| **Zero-Touch Configuration** | Drop `pistar-config.txt` on the boot partition to configure WiFi, SSH, hostname — works for first boot AND recovery |
| **Minimal Footprint** | Alpine Linux userland with musl libc — fits on a 4GB SD card with room to spare |
| **Persistent /data** | User data, SSH keys, and WiFi config survive upgrades via bind mounts from a dedicated partition |
| **Secure by Default** | SSH key-only auth, locked root account, minimal attack surface |
| **SD Card Friendly** | Logs on tmpfs to reduce write wear |
| **Full Pi Compatibility** | Official Raspberry Pi OS kernel and firmware for perfect hardware support |

## Quick Start

### 1. Download the Latest Image

<div align="center">

**[Download Latest Release](https://github.com/MW0MWZ/Pi-Star_OS/releases/latest)**

[All Releases](https://github.com/MW0MWZ/Pi-Star_OS/releases) |
[SHA256 Checksum](https://github.com/MW0MWZ/Pi-Star_OS/releases/latest)

</div>

### 2. Write to SD Card

```bash
# Extract the image
xz -d Pi-Star_OS-YYYY-MM-DD.img.xz

# Write to SD card (replace /dev/sdX with your SD card device)
sudo dd if=Pi-Star_OS-YYYY-MM-DD.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### 3. Configure Before First Boot (Optional)

Mount the boot partition and set up WiFi, SSH, etc. without ever needing a monitor or keyboard:

```bash
# Mount the boot partition
mount /dev/sdX1 /mnt

# Copy and edit the configuration template
cp /mnt/pistar-config.txt.sample /mnt/pistar-config.txt
nano /mnt/pistar-config.txt

# Unmount when done
umount /mnt
```

See [Boot Configuration](#boot-configuration) for all available options.

### 4. First Boot

Insert the SD card and power on your Raspberry Pi. Connect via SSH or console:

- **Username:** `pi-star`
- **Password:** `raspberry` (or your configured password)

> **Security Note:** Change the password immediately after first login using `passwd`

## Boot Configuration

Pi-Star OS includes a zero-touch configuration system. Drop a file on the boot partition to configure the system — no monitor, no keyboard, no network required.

### How It Works

1. On the boot partition, you'll find `pistar-config.txt.sample`
2. Copy it to `pistar-config.txt` and edit with your settings
3. On boot, the system processes the file and applies your configuration
4. **The config file is automatically deleted after processing for security**

This works for **first boot** and **recovery**. If your WiFi config breaks, pop the SD card into a PC, drop a new `pistar-config.txt` on the boot partition, put it back, and reboot. No reflashing required.

### Configuration Options

#### WiFi Networks

Configure multiple WiFi networks with priority ordering:

```ini
# Primary network
wifi_ssid=HomeNetwork
wifi_password=HomePassword

# Additional networks with priority (higher numbers = higher priority)
wifi_ssid_2=WorkNetwork
wifi_password_2=WorkPassword

wifi_ssid_3=MobileHotspot
wifi_password_3=HotspotPassword

# WiFi country code (affects available channels)
wifi_country=GB
```

#### User Security

```ini
# Set password for pi-star user
user_password=MySecurePassword

# Enable SSH password authentication (default is key-only)
enable_ssh_password=true

# Add SSH public key for secure access (recommended)
ssh_key=ssh-rsa AAAAB3NzaC1yc2EAAAA... user@example.com
```

#### System Settings

```ini
hostname=my-pistar
timezone=Europe/London
locale=en_GB.UTF-8
```

### Complete Example

```ini
# Pi-Star OS Boot Configuration
# WARNING: This file will be DELETED after processing for security!

# WiFi
wifi_ssid=MyHomeNetwork
wifi_password=MyHomePassword
wifi_ssid_2=WorkNetwork
wifi_password_2=WorkPassword
wifi_country=GB

# Security
user_password=MySecurePassword123!
enable_ssh_password=false
ssh_key=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDEx... user@example.com

# System
hostname=pistar-shack
timezone=Europe/London
locale=en_GB.UTF-8
```

## A/B Upgrade System

Pi-Star OS uses an A/B root partition scheme for safe, router-style upgrades. The system can update itself over the air and automatically roll back if something goes wrong.

### How It Works

```
Boot Partition (FAT32)
  slot.conf          - tracks active slot, pending state, boot counter
  cmdline.txt        - kernel command line (root= points to active slot)
  kernel*.img, *.dtb - kernel and device tree files (shared, updated on upgrade)

Slot A (ext4)        - root filesystem (active or inactive)
Slot B (ext4)        - root filesystem (active or inactive)
Data   (ext4)        - persistent user data, bind-mounted into rootfs
```

### Upgrade Flow

```
pistar-upgrade --install
  1. Downloads new rootfs to inactive slot
  2. Marks new slot as PENDING
  3. Reboots

Boot watchdog (pistar-boot-watchdog)
  4. Increments boot counter each boot while PENDING
  5. If counter exceeds 3, rolls back automatically

Health check (pistar-health-check)
  6. Waits for network connectivity
  7. If healthy, clears PENDING — upgrade confirmed
  8. If not, watchdog handles rollback on next reboot
```

### Commands

```bash
# Check for updates
sudo pistar-upgrade --check

# Download and install update to inactive slot
sudo pistar-upgrade --install

# View current slot status
pistar-slot-info

# Manual rollback to previous slot
sudo pistar-rollback
```

## Partition Layout

| Partition | Size | Format | Mount Point | Purpose |
|-----------|------|--------|-------------|---------|
| P1 | 256 MB | FAT32 | `/boot/firmware` | Boot files, kernel, firmware, config |
| P2 | 1.5 GB | ext4 | `/` (slot A) | Root filesystem A |
| P3 | 1.5 GB | ext4 | `/` (slot B) | Root filesystem B |
| P4 | Remaining | ext4 | `/data` | Persistent user data (expands on first boot) |

### What Persists Across Upgrades

The `/data` partition provides persistence. `/data/home` is bind-mounted via fstab. All `/data/etc/*/` directories are automatically bind-mounted over their `/etc/` counterparts by the `pistar-bindmounts` init script at boot — empty directories are seeded from rootfs defaults on first use.

| Path | Bind Mount Source | Contents |
|------|-------------------|----------|
| `/home` | `/data/home` | User home directories |
| `/etc/dropbear` | `/data/etc/dropbear` | SSH host keys |
| `/etc/wpa_supplicant` | `/data/etc/wpa_supplicant` | WiFi configuration |
| `/etc/mmdvmhost` | `/data/etc/mmdvmhost` | MMDVMHost configuration |
| `/etc/dmrclients` | `/data/etc/dmrclients` | DMR gateway/client configs |
| `/etc/dstarclients` | `/data/etc/dstarclients` | D-Star gateway/client configs |
| `/etc/ysfclients` | `/data/etc/ysfclients` | YSF gateway/client configs |
| `/etc/nxdnclients` | `/data/etc/nxdnclients` | NXDN gateway/client configs |
| `/etc/p25clients` | `/data/etc/p25clients` | P25 gateway/client configs |
| `/etc/fmclients` | `/data/etc/fmclients` | FM gateway/client configs |
| `/etc/aprsclients` | `/data/etc/aprsclients` | APRS gateway configs |
| `/etc/pocsagclients` | `/data/etc/pocsagclients` | POCSAG gateway configs |
| `/etc/dstarrepeater` | `/data/etc/dstarrepeater` | D-Star repeater configs |

Adding persistence for a new package is as simple as creating its `/data/etc/<name>/` directory.

## Boot Order

```
boot runlevel:
  localmount            mounts /boot/firmware, /data, /home bind mount
  pistar-bindmounts     bind mounts /data/etc/*/ over /etc/*/
  pistar-config         processes config file if present
  pistar-boot-watchdog  increments boot counter if PENDING
  pistar-data-resize    expands /data on first boot
  wpa_supplicant        connects to WiFi
  dhcpcd                gets IP address

default runlevel:
  pistar-health-check   validates network, clears PENDING
  dropbear              SSH server
```

## Compatibility

Pi-Star OS works with **all** Raspberry Pi models:

| Series | Models |
|--------|--------|
| **Classic** | Pi 1 Model A/B/B+ |
| **Zero** | Pi Zero, Zero W, Zero 2 W |
| **Standard** | Pi 2B, 3A+/B/B+, 4B, 5 |
| **Compute** | CM1, CM3, CM3+, CM4, CM4S |
| **Special** | Pi 400, Pi 500 |

## Network Configuration

### Ethernet
DHCP is enabled by default on `eth0`. No configuration needed.

### WiFi

**Method 1: Boot Configuration (Recommended)**
Use `pistar-config.txt` as described in [Boot Configuration](#boot-configuration).

**Method 2: Manual Configuration**
```bash
# Edit wpa_supplicant config (persists via /data bind mount)
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf

# Add a network block:
# network={
#     ssid="YourNetwork"
#     psk="YourPassword"
# }

# Restart wpa_supplicant
sudo rc-service wpa_supplicant restart
```

## Package Management

Pi-Star OS uses Alpine's `apk` package manager:

```bash
# Update package index
apk update

# Install packages
apk add nano htop git

# Search for packages
apk search nginx

# Remove packages
apk del package-name
```

## Service Management (OpenRC)

```bash
# List all services
rc-status

# Start/stop/restart services
rc-service dropbear restart

# Enable/disable at boot
rc-update add myservice default
rc-update del myservice default
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **No network** | Check cable/WiFi config, verify with `ip addr show` |
| **WiFi not connecting** | Check country code and password, inspect with `wpa_cli status` |
| **SSH refused** | Verify dropbear is running: `rc-service dropbear status` |
| **Config not applied** | File must be named exactly `pistar-config.txt` on the boot partition |
| **Boot loop** | Watchdog will auto-rollback after 3 failed boots |
| **Recovery** | Pop SD card out, mount boot partition on PC, drop `pistar-config.txt`, reboot |

## Technical Details

### What Comes From Where

**From Raspberry Pi OS:** Kernel images, device tree blobs, kernel modules (`/usr/lib/modules/*`), firmware blobs (`/usr/lib/firmware/*`), boot configuration files

**From Alpine Linux:** Complete userland (musl libc), OpenRC init system, BusyBox utilities, apk package manager, Dropbear SSH server

**Pi-Star OS Specific:** A/B partition scheme, boot watchdog and health check, upgrade/rollback system, boot configuration processor, persistent /data partition

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

```bash
git clone https://github.com/MW0MWZ/Pi-Star_OS.git
cd Pi-Star_OS
```

## License

This project combines components from:
- **Raspberry Pi OS** - [Raspberry Pi OS License](https://www.raspberrypi.org/documentation/linux/kernel/license.md)
- **Alpine Linux** - [Alpine License](https://www.alpinelinux.org/about/)

## Acknowledgments

- [Raspberry Pi Foundation](https://www.raspberrypi.org) for kernel and firmware
- [Alpine Linux Team](https://alpinelinux.org) for the minimal userland
- [RasPINE](https://github.com/MW0MWZ/RasPINE) for the base platform and APK repository
- The Amateur Radio community for continuous support

---

<div align="center">

**Built for the Raspberry Pi and Amateur Radio communities**

*Maintained by Andy Taylor (MW0MWZ)*

[Releases](https://github.com/MW0MWZ/Pi-Star_OS/releases) | [Issues](https://github.com/MW0MWZ/Pi-Star_OS/issues)

</div>
