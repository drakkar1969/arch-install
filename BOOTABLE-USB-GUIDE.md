# Bootable USB Guide (UEFI)

This section assumes that `/dev/sda` is the USB drive. You can use the `lsblk` command to check this.

__Warning: this will destroy all data on the USB drive__.

Unmount any mounted partitions on the USB drive:

```bash
sudo umount -R /path/to/mount
```

Replace `/path/to/mount` with the directory name(s) where USB partitions are mounted. Mount points can be found with the command `mount | grep sda`.

### 1. Create and Format Partitions

Run `parted` to partition the USB drive:

```bash
sudo parted /dev/sda
```

Create a partition table (GPT):

```bash
(parted) mklabel gpt
```

Create a `boot` partition of type `ESP` (EFI system partition) and set `boot` flag:

```bash
(parted) mkpart ESP fat32 1MiB 4GiB
(parted) set 1 boot on
```

Create a data partition in the remaining space:

```bash
(parted) mkpart data ext4 4GiB 100%
```

Verify partitions and exit `parted`:

```bash
(parted) print
(parted) quit
```

Format the `ESP` partition:

```bash
sudo mkfs.fat -F32 /dev/sda1
```

Format the data partition:

```bash
sudo mkfs.ext4 -L "USBData" /dev/sda2
```

### 2. Copy Arch Linux ISO to USB

Mount the `ESP` partition:

```bash
sudo mkdir -p /mnt/usb
sudo mount /dev/sda1 /mnt/usb
```

Extract the Arch Linux ISO to the `ESP` partition:

```bash
sudo bsdtar -x --exclude=syslinux/ -f archlinux-2022.07.01-x86_64.iso -C /mnt/usb
```

Replace `archlinux-2022.07.01-x86_64.iso` with the path to the Arch Linux ISO.

Unmount the `ESP` partition:

```bash
sudo umount -R /mnt/usb
sudo rm -Rf /mnt/usb
```

Change the label of the `ESP` partition to ensure booting:

```bash
sudo fatlabel /dev/sda1 ARCH_202207
```

Replace `ARCH_202207` with the correct version of the Arch Linux ISO, in format `ARCH_YYYYMM`.
