# Arch Linux Installation

Set the keyboard layout, if different from US keyboard:

```bash
loadkeys it
```

 Replace `it`  with your keyboard layout. Available layouts can be listed with:

```bash
ls /usr/share/kbd/keymaps/**/*.map.gz
```

Download and execute the `arch-install.bash` script:

```shell
curl -LJO https://raw.githubusercontent.com/drakkar1969/arch-install/master/arch-install.bash
bash arch-install.bash
```

After completing installation, restart to boot into GNOME:

```shell
reboot
```