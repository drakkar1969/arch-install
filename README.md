# Arch Linux Installation

### Set Keyboard Layout

Set the keyboard layout, if different from US keyboard:

```bash
loadkeys it
```

 Replace `it`  with your keyboard layout. Available layouts can be listed with:

```bash
ls /usr/share/kbd/keymaps/**/*.map.gz
```

### Connect to Wifi

To enable wireless connection:

```bash
iwctl
```

```bash
[iwd] device list
[iwd] station [wlan0] scan	# replace [wlan0] with your device name from the previous command
[iwd] station [wlan0] get-networks
[iwd] station [wlan0] connect [SSID]	# replace [SSID] with your network name from the previous command
[iwd] quit
```

To test the internet connection:

```bash
ping -c 3 www.google.com
```

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