# Arch Linux Installation

## Installation

Download and execute the `arch-install.sh` script:

```shell
curl -LJO https://raw.githubusercontent.com/drakkar1969/arch-install/master/arch-install.sh
bash arch-install.sh
```
After completing installation, change root into the new system:

```shell
arch-chroot /mnt /bin/bash
```

## Post-Installation

Execute the post-installation script `arch-post-install.sh`:

```shell
bash arch-post-install.sh
```

Exit the `chroot` environment:

```shell
exit
```

Unmount partitions:

```shell
umount -R /mnt/boot
umount -R /mnt/home
umount -R /mnt
```

Restart to boot into GNOME:

```shell
reboot
```
