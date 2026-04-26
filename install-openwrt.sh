#!/bin/sh
# OpenWrt Installer Script - ash/OpenWrt compatible
# Repo: https://github.com/sali9043/openwrt-sophos-xg125

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
printf "${BLUE}"
echo "╔══════════════════════════════════════════╗"
echo "║       OpenWrt x86/64 Installer           ║"
echo "║       For Sophos XG125                   ║"
echo "║  github.com/sali9043/openwrt-sophos-xg125║"
echo "╚══════════════════════════════════════════╝"
printf "${NC}"

# ─── Must run as root ─────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
  printf "${RED}ERROR: Please run as root${NC}\n"
  exit 1
fi

# ─── Check internet ───────────────────────────────────────
printf "${YELLOW}Checking internet connection...${NC}\n"
if ! curl -sf --max-time 10 https://github.com > /dev/null; then
  printf "${RED}ERROR: No internet connection.${NC}\n"
  exit 1
fi
printf "${GREEN}✔ Internet OK${NC}\n\n"

# ─── Install dependencies ─────────────────────────────────
printf "${YELLOW}Installing required tools...${NC}\n"
if command -v apk >/dev/null 2>&1; then
  apk add curl parted e2fsprogs fdisk >/dev/null 2>&1
elif command -v apt-get >/dev/null 2>&1; then
  apt-get install -y -qq curl parted e2fsprogs fdisk >/dev/null 2>&1
fi
printf "${GREEN}✔ Tools ready${NC}\n\n"

# ─── Download image ───────────────────────────────────────
mkdir -p "$TMP_DIR"
IMAGE_PATH="${TMP_DIR}/${IMAGE_NAME}"

if [ -f "$IMAGE_PATH" ]; then
  printf "${YELLOW}Image already downloaded, skipping...${NC}\n"
else
  printf "${YELLOW}Downloading OpenWrt image from GitHub...${NC}\n"
  echo "URL: $IMAGE_URL"
  echo ""
  curl -L --progress-bar "$IMAGE_URL" -o "$IMAGE_PATH"
  printf "\n${GREEN}✔ Download complete${NC}\n"
fi
echo ""

# ─── List available disks (no lsblk needed) ───────────────
printf "${YELLOW}Available disks:${NC}\n"
echo "─────────────────────────────────────────────────────"
for dev in /sys/block/*/; do
  name=$(basename "$dev")
  # Skip loop, ram, zram devices
  case "$name" in
    loop*|ram*|zram*) continue ;;
  esac
  size_bytes=$(cat "/sys/block/${name}/size" 2>/dev/null || echo 0)
  size_gb=$(awk "BEGIN {printf \"%.1f GB\", $size_bytes * 512 / 1024 / 1024 / 1024}")
  model=$(cat "/sys/block/${name}/device/model" 2>/dev/null | xargs || echo "Unknown")
  printf "  %-10s %-10s %s\n" "$name" "$size_gb" "$model"
done
echo "─────────────────────────────────────────────────────"
echo ""

# ─── Select target disk ───────────────────────────────────
printf "Enter target disk (e.g. sda, nvme0n1): "
read DISK
TARGET="/dev/$DISK"

if [ ! -b "$TARGET" ]; then
  printf "${RED}ERROR: $TARGET is not a valid block device.${NC}\n"
  exit 1
fi

# ─── Show disk info & confirm ─────────────────────────────
echo ""
printf "${YELLOW}Target disk info:${NC}\n"
fdisk -l "$TARGET" 2>/dev/null | head -5
echo ""
SIZE_BYTES=$(cat "/sys/block/${DISK}/size" 2>/dev/null || echo 0)
SIZE_GB=$(awk "BEGIN {printf \"%.1f\", $SIZE_BYTES * 512 / 1024 / 1024 / 1024}")
printf "${RED}WARNING: ALL DATA on $TARGET (${SIZE_GB} GB) will be DESTROYED!${NC}\n\n"
printf "Type 'YES' to confirm and begin installation: "
read CONFIRM

if [ "$CONFIRM" != "YES" ]; then
  echo "Installation cancelled."
  rm -rf "$TMP_DIR"
  exit 0
fi

# ─── Unmount any partitions ───────────────────────────────
echo ""
printf "${YELLOW}Unmounting partitions on $TARGET...${NC}\n"
umount ${TARGET}* 2>/dev/null || true
sleep 1

# ─── Flash image ──────────────────────────────────────────
echo ""
printf "${YELLOW}Flashing OpenWrt to $TARGET...${NC}\n\n"

gunzip -c "$IMAGE_PATH" | dd of="$TARGET" bs=1M conv=fsync
sync

printf "\n${GREEN}✔ Flash complete!${NC}\n"

# ─── Expand root partition ────────────────────────────────
echo ""
printf "Expand root partition to fill disk? (recommended) [y/N]: "
read EXPAND

if [ "$EXPAND" = "y" ] || [ "$EXPAND" = "Y" ]; then
  printf "${YELLOW}Expanding root partition...${NC}\n"

  PART_NUM=$(fdisk -l "$TARGET" | grep -i ext4 | awk '{print $1}' | tail -1 | grep -o '[0-9]*$')

  # Resize partition
  parted "$TARGET" ---pretend-input-tty resizepart "$PART_NUM" 100% <<EOF
Yes
EOF

  # Handle nvme naming
  if echo "$TARGET" | grep -q "nvme"; then
    PART="${TARGET}p${PART_NUM}"
  else
    PART="${TARGET}${PART_NUM}"
  fi

  sleep 2
  e2fsck -f "$PART" || true
  resize2fs "$PART"
  printf "${GREEN}✔ Partition expanded${NC}\n"
fi

# ─── Cleanup ──────────────────────────────────────────────
printf "\n${YELLOW}Cleaning up...${NC}\n"
rm -rf "$TMP_DIR"

# ─── Done ─────────────────────────────────────────────────
printf "${GREEN}"
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         Installation Complete!           ║"
echo "║                                          ║"
echo "║  1. Reboot the device                    ║"
echo "║  2. Access LuCI at http://192.168.1.1    ║"
echo "║  3. Default login: root / (no password)  ║"
echo "╚══════════════════════════════════════════╝"
printf "${NC}\n"

printf "Reboot now? [y/N]: "
read REBOOT
if [ "$REBOOT" = "y" ] || [ "$REBOOT" = "Y" ]; then
  reboot
fi
