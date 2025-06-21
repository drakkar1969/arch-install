# Arch Linux Installation

### Set Keyboard Layout

Set the keyboard layout, if different from US keyboard:

```bash
loadkeys it
```

Replace `it` with your keyboard layout. Available layouts can be listed with:

```bash
localectl list-keymaps
```

### Set Console Font

Set the console font:

```bash
setfont ter-128b
```

Replace `ter-128b` with your font name. Available fonts can be listed with:

```bash
ls /usr/share/kbd/consolefonts
```

### Connect to Wifi

Enable wireless connection:

```bash
iwctl
```

```bash
[iwd] device list
[iwd] station [wlan0] scan              # replace [wlan0] with your device name from the previous command
[iwd] station [wlan0] get-networks
[iwd] station [wlan0] connect [SSID]    # replace [SSID] with your network name from the previous command
[iwd] quit
```

To test the internet connection, use the command `ping -c 3 www.google.com`.

### Run Install Script

Download and execute the `arch-install.bash` script:

```shell
curl -LJO https://raw.githubusercontent.com/drakkar1969/arch-install/master/arch-install.bash
bash arch-install.bash
```

After completing installation, restart to boot into GNOME:

```shell
reboot
```

## Installation Guide

For step-by-step manual installation, see the [Arch Linux Installation Guide](ARCH-INSTALL-GUIDE.md).

## Virtual Machines

See the [GNOME Boxes](GNOME-BOXES-ARCH-GUEST.md) and [VirtualBox](VIRTUALBOX-ARCH-GUEST.md) guides to install Arch Linux as the guest system in a virtual machine.

## Bootable USB

See the [Bootable USB Guide](BOOTABLE-USB-GUIDE.md) for how to create a bootable USB from the Arch Linux ISO.
