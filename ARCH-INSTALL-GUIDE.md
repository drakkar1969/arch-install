# 	Arch Linux Installation Guide (UEFI)
---
## Bootable USB

To create a bootable USB from a CD image, use the following command:

```bash
dd bs=4M if=path-to-image.iso of=/dev/sdX status=progress && sync
```

Where `path-to-image.iso` is the full path of the CD image, and `/dev/sdX` is the USB device to write to.

---
## Pre-Installation

#### Set Keyboard Layout

The default keymap is US. Set your keymap with the command (replace `it` with your actual keymap):

```bash
loadkeys it
```

Available layouts can be listed with:

```bash
ls /usr/share/kbd/keymaps/**/*.map.gz
```

#### Check UEFI Mode

To verify that UEFI boot mode is enabled, list the `efivars` directory:

```bash
ls /sys/firmware/efi/efivars
```

If the directory does not exist, the system may be in MBR/BIOS mode.

#### Enable Internet Connection

Wired internet connection is enabled by default.

To enable wireless connection:

```bash
iwctl
device list
# replace [wlan0] with your device name from the previous command
station [wlan0] scan
station [wlan0] get-networks
# replace [SSID] with your network name from the previous command
station [wlan0] connect [SSID]
quit
```

To test the internet connection:

```bash
ping -c 3 www.google.com
```

#### Update System Clock

Ensure the system clock is accurate:

```bash
timedatectl set-ntp true
```
To check the status, use `timedatectl` without parameters.

#### Partition Disks

This section assumes that:

* `/dev/nvme0n1` is the primary SSD

* `/dev/sda` is the additional HDD

You can use the `lsblk` command to check this.

##### 1. Create Partitions

__Warning__: this will destroy all data on the disk.
Run `parted` to partition the __primary SSD__:

```bash
parted /dev/nvme0n1
```

Create a partition table (GPT):

```bash
(parted) mklabel gpt
```
Create `boot` partition of type `ESP` (EFI system partition) and set boot flag:

```bash
(parted) mkpart ESP fat32 1MiB 513MiB
(parted) set 1 boot on
```
Create `root` partition:

```bash
(parted) mkpart primary ext4 513MiB 50GiB
```

Create `swap` partition:

```bash
(parted) mkpart primary linux-swap 50GiB 66GiB
```

Create `home` partition:

```bash
(parted) mkpart primary ext4 66GiB 100%
```

Verify partitions and exit `parted`:

```bash
(parted) print
(parted) quit
```

Partition the __additional HDD__:

```bash
parted /dev/sda
```

Create a partition table (GPT):

```bash
(parted) mklabel gpt
```

Create a data partition:

```bash
(parted) mkpart primary ext4 1MiB 100%
```

Verify partitions and exit `parted`:

```bash
(parted) print
(parted) quit
```

##### 2. Format Partitions

Format the `ESP` partition:

```bash
mkfs.fat -F32 /dev/nvme0n1p1
```

Activate the `swap` partition:

```bash
mkswap /dev/nvme0n1p3
swapon /dev/nvme0n1p3
```

Format the `root` partition:

```bash
mkfs.ext4 /dev/nvme0n1p2
```

Format the `home` partition (**do this only if the `home` partition is not empty**):

```bash
mkfs.ext4 /dev/nvme0n1p4
```

Format the data partition on the additional HDD (**do this only if the data partition is not empty**):

```bash
mkfs.ext4 /dev/sda1
```

##### 3. Mount Partitions

Mount the `root` partition:

```bash
mount /dev/nvme0n1p2 /mnt
```

Mount the `home` partition:

```bash
mkdir /mnt/home
mount /dev/nvme0n1p4 /mnt/home
```

Mount the `ESP boot` partition:

```bash
mkdir /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
```

Use the `lsblk` command to verify partitions are correctly mounted.

---
## Installation

#### Install Base Packages

```bash
pacstrap /mnt base base-devel linux linux-firmware
```

#### Generate Fstab File

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

In case of errors, __do not run the command a second time__, edit the `fstab` file manually.

#### Change Root into New System

```bash
arch-chroot /mnt /bin/bash
```

The last argument (optional) specifies to use the `bash` shell (the default is `sh`).

---
## System Configuration

#### Set Keyboard layout

Make the keyboard layout permanent (replace `it` with your keymap):

```bash
echo KEYMAP=it > /etc/vconsole.conf
```

#### Configure Timezone

Set the time zone:

```bash
TIMEZONE="Europe/Sarajevo"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
```

The timezone format is `Region/City` where _Region_ and _City_ depend on location. To check available timezones, see the files/folders in `/usr/share/zoneinfo/`.

#### Sync Hardware Clock

Set hardware clock to UTC:

```bash
hwclock --systohc --utc
```

#### Configure Locale

Uncomment locales in the `/etc/locale.gen` file:

```bash
LOCALE_US="en_US.UTF-8"
LOCALE_DK="en_DK.UTF-8"

sed -i "/#$LOCALE_US/ s/^#//" /etc/locale.gen
sed -i "/#$LOCALE_DK/ s/^#//" /etc/locale.gen
```

Generate locales:

```bash
locale-gen
```

Export locale variables:

```bash
echo LANG=$LOCALE_US > /etc/locale.conf
echo LC_MEASUREMENT=$LOCALE_DK >> /etc/locale.conf
echo LC_MONETARY=$LOCALE_US >> /etc/locale.conf
echo LC_NUMERIC=$LOCALE_US >> /etc/locale.conf
echo LC_PAPER=$LOCALE_DK >> /etc/locale.conf
echo LC_TIME=$LOCALE_DK >> /etc/locale.conf

export LANG=$LOCALE_US
export LC_MEASUREMENT=$LOCALE_DK
export LC_MONETARY=$LOCALE_US
export LC_NUMERIC=$LOCALE_US
export LC_PAPER=$LOCALE_DK
export LC_TIME=$LOCALE_DK
```

#### Configure Hostname

Create the `hostname` file:

```bash
PCNAME="ProBook450"
echo $PCNAME > /etc/hostname
```

Create the `hosts` file:

```bash
echo "127.0.0.1       localhost" > /etc/hosts
echo "::1             localhost" >> /etc/hosts
echo "127.0.1.1       ${PCNAME}.localdomain       ${PCNAME}" >> /etc/hosts
```

#### Enable Multilib Repository

Enable the `multilib` repository:

```bash
sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf
```

Refresh package databases:

```bash
pacman -Syy
```

#### Configure Root Password

To set the root password, run the following command and input a password:

```bash
passwd
```

#### Add New User with Sudo Privileges

Add new user:

```bash
NEWUSER="drakkar"
USERDESC="draKKar"
useradd -m -G wheel -c $USERDESC -s /bin/bash $NEWUSER
```

Verify that the new user has been created with the command `id $NEWUSER`.

Create a password for the new user (specify at prompt):

```bash
passwd $NEWUSER
```

Allow the new user to issue commands as root, i.e. with `sudo`:

```bash
bash -c 'echo "%wheel ALL=(ALL) ALL" | (EDITOR="tee -a" visudo)'
```

#### Install Boot Loader

Install the two packages `grub` and `os-prober` (`os-prober` is only needed to detect other operating systems in a dual boot scenario). For UEFI/GPT systems, the package `efibootmgr` is also required:

```bash
pacman -S grub efibootmgr os-prober
```

Install the `grub` boot loader:

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
```

Install the `microcode` package (Intel CPUs):

```bash
pacman -S intel-ucode
```

Generate the `grub.cfg` file (this will also enable automatic `microcode` updates):

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

> **For installation in VirtualBox only**:
>
> Copy the bootable `.efi` stub to ensure system will boot in UEFI mode:
>
> ```bash
> mkdir /boot/EFI/boot/
> cp /boot/EFI/grub/grubx64.efi /boot/EFI/boot/bootx64.efi
> ```

#### Enable Wifi after Reboot

Install Network Manager:

```bash
pacman -S networkmanager
```

Enable the Network Manager service:

```bash
systemctl enable NetworkManager.service
```

#### Reboot

Exit the `chroot` environment:

```bash
exit
```

Unmount the `boot`, `home` and `root` partitions:

```bash
umount -R /mnt/boot
umount -R /mnt/home
umount -R /mnt
```

Restart the machine:

```bash
reboot
```

## Desktop Environment

#### Enable Internet Connection

```bash
nmcli device wifi "SSID" password "PASSWD"
```

Replace `SSID` and `PASSWD` with your wifi network and password.

To test the internet connection:

```bash
ping -c 3 www.google.com
```

#### Install Xorg Graphical Environment

Install Xorg:

```bash
sudo pacman -S xorg-server
```

Install X widgets for testing:

```bash
sudo pacman -S xorg-xinit xorg-twm xterm
```

Test that the Xorg environment is working with the command `startx`. To exit the graphical environment type `exit`.

#### Install Video Drivers

Install the nVidia video drivers (`nvidia-libgl` is not required, as `xorg-server` provides OpenGL support through the `mesa` package):

```bash
sudo pacman -S nvidia
```

For 32-bit support on 64-bit machines:

```bash
sudo pacman -S lib32-virtualgl lib32-nvidia-utils
```

If prompted to select provider(s), select default options.

Make sure that the `lib32-nvidia-libgl` package is not installed.

Install the Intel VA-API driver for hardware video acceleration

```bash
sudo pacman -S intel-media-driver
```

#### Install GNOME

Install GNOME package group (press `ENTER` to select all packages when prompted):

```bash
sudo pacman -S gnome --ignore epiphany,gnome-books,gnome-boxes,gnome-calendar,gnome-clocks,gnome-contacts,gnome-dictionary,gnome-documents,gnome-maps,gnome-photos,gnome-software,orca
```

If prompted to select provider(s), select default options.

#### Enable GDM Display Manager

Enable the `gdm` (GNOME Display Manager) login screen:

```bash
sudo systemctl enable gdm.service
```

#### Reboot

Restart the machine to boot into GNOME:

```bash
reboot
```
