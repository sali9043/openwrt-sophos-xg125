#!/bin/bash
# OpenWrt Installer Script
# Usage: bash install-openwrt.sh

set -e

# ─── Colors ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── Banner ───────────────────────────────────────────────
clear
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════╗"
echo "║       OpenWrt x86/64 Installer           ║"
echo "║       For Sophos XG125                   ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ─── Must run as root ─────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}ERROR: Please run as root (sudo bash install-openwrt.sh)${NC}"
  exit 1
fi

# ─── Find the OpenWrt image ───────────────────────────────
echo -e "${YELLOW}Looking for OpenWrt image...${NC}"

IMAGE=$(find /media /mnt /run/media -name "openwrt-*.img.gz" 2>/dev/null | head -1)

if [ -z "$IMAGE" ]; then
  echo -e "${RED}ERROR: No openwrt-*.img.gz found on any mounted USB drive.${NC}"
  echo "Please mount your USB drive and try again."
  echo ""
  echo "Manual mount example:"
  echo "  mkdir /mnt/usb && mount /dev/sdb1 /mnt/usb"
  exit 1
fi

echo -e "${GREEN}Found image: $IMAGE${NC}"
echo ""

# ─── List available disks ─────────────────────────────────
echo -e "${YELLOW}Available disks:${NC}"
echo "─────────────────────────────────────────"
lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v loop
echo "─────────────────────────────────────────"
echo ""

# ─── Select target disk ───────────────────────────────────
read -rp "Enter target disk (e.g. sda, nvme0n1): " DISK
TARGET="/dev/$DISK"

if [ ! -b "$TARGET" ]; then
  echo -e "${RED}ERROR: $TARGET is not a valid block device.${NC}"
  exit 1
fi

# ─── Show disk info & confirm ─────────────────────────────
echo ""
echo -e "${YELLOW}Target disk info:${NC}"
lsblk "$TARGET"
echo ""
DISK_SIZE=$(lsblk -d -o SIZE "$TARGET" | tail -1 | xargs)
echo -e "${RED}WARNING: ALL DATA on $TARGET ($DISK_SIZE) will be DESTROYED!${NC}"
echo ""
read -rp "Type 'YES' to confirm and begin installation: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
  echo "Installation cancelled."
  exit 0
fi

# ─── Unmount any partitions on target disk ────────────────
echo ""
echo -e "${YELLOW}Unmounting any partitions on $TARGET...${NC}"
umount ${TARGET}* 2>/dev/null || true
sleep 1

# ─── Flash image ──────────────────────────────────────────
echo ""
echo -e "${YELLOW}Flashing OpenWrt to $TARGET...${NC}"
echo "This may take a few minutes, please wait."
echo ""

gunzip -c "$IMAGE" | dd of="$TARGET" bs=1M status=progress conv=fsync
sync

echo ""
echo -e "${GREEN}✔ Flash complete!${NC}"

# ─── Expand root partition (optional) ─────────────────────
echo ""
read -rp "Expand root partition to fill disk? (recommended) [y/N]: " EXPAND

if [[ "$EXPAND" =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Expanding root partition...${NC}"
  
  # Install parted if missing
  if ! command -v parted &>/dev/null; then
    apt-get install -y parted &>/dev/null || \
    apk add parted &>/dev/null || true
  fi

  # Get partition info
  PART_NUM=$(parted "$TARGET" print | grep ext4 | awk '{print $1}' | tail -1)
  
  parted "$TARGET" ---pretend-input-tty resizepart "$PART_NUM" 100% << EOF
Yes
EOF

  # Resize filesystem
  partprobe "$TARGET"
  sleep 1
  PART="${TARGET}${PART_NUM}"
  # Handle nvme partition naming (nvme0n1p2 not nvme0n12)
  if [[ "$TARGET" == *"nvme"* ]]; then
    PART="${TARGET}p${PART_NUM}"
  fi

  e2fsck -f "$PART" || true
  resize2fs "$PART"
  echo -e "${GREEN}✔ Partition expanded.${NC}"
fi

# ─── Done ─────────────────────────────────────────────────
echo ""
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════╗"
echo "║         Installation Complete!           ║"
echo "║                                          ║"
echo "║  1. Remove USB drive                     ║"
echo "║  2. Reboot the device                    ║"
echo "║  3. Access LuCI at http://192.168.1.1    ║"
echo "║  4. Default login: root / (no password)  ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

read -rp "Reboot now? [y/N]: " REBOOT
if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
  reboot
fi
