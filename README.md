# OpenWrt x86/64 — Sophos XG125 Rev 3.0

> Custom OpenWrt 25.12.2 firmware for the Sophos XG125 Rev 3.0 appliance with LuCI web interface, WireGuard, and OpenVPN support.> 
---

## 📋 Table of Contents

- [Hardware Overview](#hardware-overview)
- [What You Need](#what-you-need)
- [Step 1 — Connect via Serial Console (PuTTY)](#step-1--connect-via-serial-console-putty)
- [Step 2 — Disable USB Configuration Lock](#step-2--disable-usb-configuration-lock)
- [Step 3 — Boot a Live Linux USB](#step-3--boot-a-live-linux-usb)
- [Step 4 — Flash OpenWrt](#step-4--flash-openwrt)
- [Step 5 — First Boot & Web Access](#step-5--first-boot--web-access)
- [Network Port Layout](#network-port-layout)
- [Default Credentials](#default-credentials)
- [Troubleshooting](#troubleshooting)

---

## Hardware Overview

| Item | Detail |
|---|---|
| Device | Sophos XG125 Rev 3.0 |
| Architecture | x86/64 |
| Serial Port | DB9 / RJ45 console port |
| Baud Rate | 115200 |
| Internal Storage | mSATA / SSD (shown as `sda`) |
| LAN Port | **Port 5** eth0 |
| WAN Port | **Port 6** eth1 |
|    change it via luci or shell command |
| LAN Port | **Port 1** eth5 |
| WAN Port | **Port 2** eth6 |
![OpenWrt Screenshot](https://raw.githubusercontent.com/sali9043/openwrt-sophos-xg125/main/Screenshot%202026-04-26%20224822.png)
![OpenWrt Screenshot](https://raw.githubusercontent.com/sali9043/openwrt-sophos-xg125/main/Screenshot%202026-04-26%20224838.png)
---

## What You Need

- PC or laptop with PuTTY installed
- USB-to-Serial adapter (if no DB9 port on your PC)
- Serial cable — DB9 or RJ45 console cable (40cm / 60cm)
- 1× USB flash drive (any size, for live Linux)
- Internet connection on the XG125 during install

---

## Step 1 — Connect via Serial Console (PuTTY)

The Sophos XG125 has no video output during early boot. You **must** use serial console.

### Cable Setup

```
PC (USB) ──► USB-to-Serial Adapter ──► DB9/RJ45 Cable ──► XG125 Console Port
```

> Use a **40cm or 60cm** cable — longer cables can cause signal issues at 115200 baud.

### PuTTY Configuration

1. Open **PuTTY**
2. Select **Serial** as connection type
3. Set the following:

| PuTTY Setting | Value |
|---|---|
| Connection type | Serial |
| Serial line | `COM3` (check Device Manager for your port) |
| Speed (Baud rate) | `115200` |
| Data bits | `8` |
| Stop bits | `1` |
| Parity | `None` |
| Flow control | `None` |

4. Click **Open**
5. Power on the XG125 — you should see boot messages appear

> **Tip:** If you see garbage characters, your baud rate is wrong. Make sure it is exactly `115200`.

### PuTTY Screenshot Guide

```
┌─────────────────────────────────────┐
│ PuTTY Configuration                 │
│                                     │
│ ○ SSH                               │
│ ○ Telnet                            │
│ ● Serial          ◄── select this   │
│                                     │
│ Serial line:  COM3                  │
│ Speed:        115200   ◄── critical │
└─────────────────────────────────────┘
```

---

## Step 2 — Disable USB Configuration Lock

Sophos XG125 Rev 3.0 has a **USB boot/config lock** that must be disabled before booting from USB.

### From the Serial Console (Sophos Shell)

When the XG125 boots into Sophos firmware, log in via PuTTY serial console:

```
Username: admin
Password: admin  (or your set password)
```

Then navigate the menu or run:

```bash
# Enter advanced shell
system diagnostics
```

Look for USB boot options and **disable** the USB configuration restore feature, or enter BIOS:

### From BIOS (Recommended)

1. Power on the XG125
2. Watch the serial console in PuTTY
3. Press **`Delete`** or **`F2`** repeatedly as soon as you see the POST screen
4. Navigate to **Boot** menu
5. Set **USB** as the **first boot device**
6. **Disable** "USB Configuration Restore" if present
7. Save and Exit (`F10`)

---

## Step 3 — Boot a Live Linux USB

1. Download **Ubuntu Server** or **Alpine Linux** ISO
2. Flash to USB with [Balena Etcher](https://etcher.balena.io/) or Rufus
3. Insert USB into the XG125
4. Power on — watch PuTTY for boot menu
5. Select USB drive to boot

Once booted into the live Linux environment, you will have a shell prompt.

---

## Step 4 — Flash OpenWrt

You have two options:

### Option A — One-Line Installer (Recommended)

Make sure the XG125 has internet access via **Port 5 (LAN)**, then run:

```bash
curl -sL https://raw.githubusercontent.com/sali9043/openwrt-sophos-xg125/refs/heads/main/install-openwrt.sh | ash
```

The script will:
- ✅ Check internet connection
- ✅ Download the OpenWrt image automatically
- ✅ List available disks
- ✅ Ask for confirmation before flashing
- ✅ Flash to your chosen disk
- ✅ Optionally expand the root partition
- ✅ Reboot when done

### Option B — Manual Flash

If you already have the image file on a USB drive:

```bash
# Find your target disk (internal SSD)
for dev in /sys/block/sd*; do
  name=$(basename "$dev")
  size=$(( $(cat /sys/block/${name}/size) / 2097152 ))
  echo "/dev/${name}  ${size} GB"
done

# Flash (replace sda with your disk)
gunzip -c openwrt-25.12.2-x86-64-generic-ext4-combined.img.gz | dd of=/dev/sda bs=1M conv=fsync status=progress

# Sync and reboot
sync && reboot
```

> ⚠️ **Warning:** Double-check your disk target. `dd` will destroy all data on the target disk without further warning.

---

## Step 5 — First Boot & Web Access

1. Remove the USB flash drive
2. Power on the XG125
3. Wait ~30 seconds for OpenWrt to boot (watch progress in PuTTY)
4. Connect your PC to **Port 5 (LAN)**
5. Open a browser and go to:

```
http://192.168.1.1
```

### LuCI Web Interface Login

| Field | Value |
|---|---|
| URL | `http://192.168.1.1` |
| Username | `root` |
| Password | *(leave blank — no password)* |

> 🔒 **Security:** Set a password immediately after first login via **System → Administration → Password**

---

## Network Port Layout

```
Sophos XG125 Rev 3.0 — Rear Panel
┌──────────────────────────────────────────────┐
│  [Port 1] [Port 2] [Port 3] [Port 4] [Port 5] [Port 6]  │
│                                  LAN ──┘       └── WAN   │
└──────────────────────────────────────────────┘
```

| Port | Role | OpenWrt Interface | Default IP |
|---|---|---|---|
| Port 5 | **LAN** | `br-lan` | `192.168.1.1` |
| Port 6 | **WAN** | `wan` | DHCP from ISP |

> Connect your PC to **Port 5** to access LuCI. Connect your ISP modem/ONT to **Port 6**.

---

## Default Credentials

| Service | URL / Access | Username | Password |
|---|---|---|---|
| LuCI Web UI | `http://192.168.1.1` | `root` | *(none)* |
| SSH | `ssh root@192.168.1.1` | `root` | *(none)* |
| Serial Console | PuTTY @ 115200 | `root` | *(none)* |

---

## Troubleshooting

### No output in PuTTY
- Check baud rate is exactly `115200`
- Check COM port number in Windows Device Manager
- Try a different USB-to-Serial adapter
- Use a shorter cable (40cm recommended)

### Cannot access http://192.168.1.1
- Make sure your PC is connected to **Port 5**
- Set your PC to DHCP or manually assign IP `192.168.1.2/24`
- Wait 60 seconds after power on before trying
- Check serial console for boot errors

### USB not booting
- Confirm USB boot is enabled in BIOS
- Disable USB Configuration Restore in Sophos settings
- Try a different USB port on the XG125
- Re-flash the live Linux USB with Etcher

### Flash failed / dd errors
- Run `dmesg | tail -20` to check for disk errors
- Try a different USB port for the live Linux drive
- Check internal SSD is detected: `ls /sys/block/sd*`

### Wrong disk flashed
- Do not panic — re-flash the correct disk
- The image file is still in `/tmp/openwrt-installer/` if using the script

---

## Installed Packages

| Package | Purpose |
|---|---|
| `luci` | Web management interface |
| `kmod-igb` | Intel 1G NIC driver |
| `kmod-ixgbe` | Intel 10G NIC driver |
| `openvpn-openssl` | OpenVPN server/client |
| `luci-app-openvpn` | OpenVPN LuCI interface |
| `wireguard-tools` | WireGuard VPN tools |
| `kmod-wireguard` | WireGuard kernel module |
| `luci-app-wireguard` | WireGuard LuCI interface |
| `luci-app-firewall` | Firewall management |

---

## Repository Structure

```
openwrt-sophos-xg125/
├── .github/
│   └── workflows/
│       └── build.yml                                    # GitHub Actions build
├── install-openwrt.sh                                   # One-line installer script
├── openwrt-25.12.2-x86-64-generic-ext4-combined.img.gz # Pre-built firmware image
└── README.md                                            # This file
```

---

## License

This project is provided as-is for personal and educational use.
OpenWrt is licensed under GPL-2.0. See [openwrt.org](https://openwrt.org) for details.

---

<p align="center">
  Built with ❤️ for the Sophos XG125 community
</p>
