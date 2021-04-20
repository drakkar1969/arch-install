# Arch Linux Installation

## Installation

Download and execute the `arch-install.bash` script:

```shell
curl -LJO https://raw.githubusercontent.com/drakkar1969/arch-install/master/arch-install.bash
bash arch-install.bash
```
After completing installation, change root into the new system:

```shell
arch-chroot /mnt
```

## Post-Installation

Execute the post-installation script `arch-post-install.bash`:

```shell
bash arch-post-install.bash
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
