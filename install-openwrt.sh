#!/bin/bash
# OpenWrt Installer Script
# Repo: https://github.com/sali9043/openwrt-sophos-xg125

set -e

# ─── Config ───────────────────────────────────────────────
REPO_RAW="https://raw.githubusercontent.com/sali9043/openwrt-sophos-xg125/refs/heads/main"
IMAGE_NAME="openwrt-25.12.2-x86-64-generic-ext4-combined.img.gz"
IMAGE_URL="${REPO_RAW}/${IMAGE_NAME}"
TMP_DIR="/tmp/openwrt-installer"

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
echo "║  github.com/sali9043/openwrt-sophos-xg125║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ─── Must run as root ─────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}ERROR: Please run as root${NC}"
  echo "Run: curl -sL ${REPO_RAW}/install-openwrt.sh | sudo bash"
  exit 1
fi

# ─── Check internet ───────────────────────────────────────
echo -e "${YELLOW}Checking internet connection...${NC}"
if ! curl -sf --max-time 10 https://github.com > /dev/null; then
  echo -e "${RED}ERROR: No internet connection. Please connect and retry.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ Internet OK${NC}"
echo ""

# ─── Install dependencies ─────────────────────────────────
echo -e "${YELLOW}Installing required tools...${NC}"
if command -v apt-get &>/dev/null; then
  apt-get install -y -qq curl wget parted e2fsprogs pv 2>/dev/null
elif command -v apk &>/dev/null; then
  apk add -q curl wget parted e2fsprogs pv 2>/dev/null
fi
echo -e "${GREEN}✔ Tools ready${NC}"
echo ""

# ─── Download image ───────────────────────────────────────
mkdir -p "$TMP_DIR"
IMAGE_PATH="${TMP_DIR}/${IMAGE_NAME}"

if [ -f "$IMAGE_PATH" ]; then
  echo -e "${YELLOW}Image already downloaded, skipping...${NC}"
else
  echo -e "${YELLOW}Downloading OpenWrt image from GitHub...${NC}"
  echo "URL: $IMAGE_URL"
  echo ""
  curl -L --progress-bar "$IMAGE_URL" -o "$IMAGE_PATH"
  echo ""
  echo -e "${GREEN}✔ Download complete${NC}"
fi
echo ""

# ─── List available disks ─────────────────────────────────
echo -e "${YELLOW}Available disks:${NC}"
echo "─────────────────────────────────────────────────────"
lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v loop
echo "─────────────────────────────────────────────────────"
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
  rm -rf "$TMP_DIR"
  exit 0
fi

# ─── Unmount any partitions ───────────────────────────────
echo ""
echo -e "${YELLOW}Unmounting partitions on $TARGET...${NC}"
umount ${TARGET}* 2>/dev/null || true
sleep 1

# ─── Flash image ──────────────────────────────────────────
echo ""
echo -e "${YELLOW}Flashing OpenWrt to $TARGET...${NC}"
echo ""

if command -v pv &>/dev/null; then
  # With progress bar via pv
  gunzip -c "$IMAGE_PATH" | pv | dd of="$TARGET" bs=1M conv=fsync
else
  # Fallback
  gunzip -c "$IMAGE_PATH" | dd of="$TARGET" bs=1M status=progress conv=fsync
fi

sync
echo ""
echo -e "${GREEN}✔ Flash complete!${NC}"

# ─── Expand root partition ────────────────────────────────
echo ""
read -rp "Expand root partition to fill disk? (recommended) [y/N]: " EXPAND

if [[ "$EXPAND" =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Expanding root partition...${NC}"

  PART_NUM=$(parted "$TARGET" print | grep ext4 | awk '{print $1}' | tail -1)

  parted "$TARGET" ---pretend-input-tty resizepart "$PART_NUM" 100% <<EOF
Yes
EOF

  partprobe "$TARGET"
  sleep 2

  # Handle nvme naming
  if [[ "$TARGET" == *"nvme"* ]]; then
    PART="${TARGET}p${PART_NUM}"
  else
    PART="${TARGET}${PART_NUM}"
  fi

  e2fsck -f "$PART" || true
  resize2fs "$PART"
  echo -e "${GREEN}✔ Partition expanded${NC}"
fi

# ─── Cleanup ──────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Cleaning up...${NC}"
rm -rf "$TMP_DIR"

# ─── Done ─────────────────────────────────────────────────
echo ""
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════╗"
echo "║         Installation Complete!           ║"
echo "║                                          ║"
echo "║  1. Remove USB/live drive                ║"
echo "║  2. Reboot the device                    ║"
echo "║  3. Access LuCI at http://192.168.1.1    ║"
echo "║  4. Default login: root / (no password)  ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

read -rp "Reboot now? [y/N]: " REBOOT
if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
  reboot
fi
