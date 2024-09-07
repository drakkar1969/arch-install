# Arch Linux Installation Guide (UEFI)

---

## A. Bootable USB

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

Format the `boot` partition:

```bash
sudo mkfs.fat -F32 /dev/sda1
```

Format the data partition:

```bash
sudo mkfs.ext4 -L "USBData" /dev/sda2
```

### 2. Copy Arch Linux ISO

Mount the `boot` partition:

```bash
sudo mkdir -p /mnt/usb
sudo mount /dev/sda1 /mnt/usb
```

Extract the Arch Linux ISO to the `boot` partition:

```bash
sudo bsdtar -x --exclude=syslinux/ -f archlinux-2022.07.01-x86_64.iso -C /mnt/usb
```

Replace `archlinux-2022.07.01-x86_64.iso` with the path to the Arch Linux ISO.

Unmount the `boot` partition:

```bash
sudo umount -R /mnt/usb
sudo rm -Rf /mnt/usb
```

Change the label of the `boot` partition to ensure booting:

```bash
sudo fatlabel /dev/sda1 ARCH_202207
```

Replace `ARCH_202207` with the correct version of the Arch Linux ISO, in format `ARCH_YYYYMM`.

---

## B. Pre-Installation

### 1. Set Keyboard Layout

> Note: this step is only required for non-US keyboards

The default keymap is US. Set your keymap with the command:

```bash
loadkeys it
```

Replace `it` with your actual keymap.

Available layouts can be listed with:

```bash
ls /usr/share/kbd/keymaps/**/*.map.gz
```

### 2. Check UEFI Mode

To verify that UEFI boot mode is enabled, list the `efivars` directory:

```bash
ls /sys/firmware/efi/efivars
```

If the directory does not exist, the system may be in MBR/BIOS mode.

### 3. Enable Internet Connection

> Note: not required for VirtualBox/GNOME Boxes installation

Wired internet connection is enabled by default.

To enable wireless connection:

```bash
iwctl
```

```bash
[iwd] device list
[iwd] station [wlan0] scan             # replace [wlan0] with your device name from the previous command
[iwd] station [wlan0] get-networks
[iwd] station [wlan0] connect [SSID]   # replace [SSID] with your network name from the previous command
[iwd] quit
```

To test the internet connection:

```bash
ping -c 3 www.google.com
```

### 4. Update System Clock

Ensure the system clock is accurate:

```bash
timedatectl set-ntp true
```

To check the status, use `timedatectl` without parameters.

### 5. Partition Disks

This section assumes that `/dev/nvme0n1` is the primary SSD.

You can use the `lsblk` command to check this.

__Warning: this will destroy all data on the disk__.

#### a. Create Partitions

Run `gdisk` to partition the primary SSD:

```bash
gdisk /dev/nvme0n1
```

```
GPT fdisk (gdisk) version 1.0.9

Partition table scan:
  MBR: protective
  BSD: not present
  APM: not present
  GPT: present

Found valid GPT with protective MBR; using GPT.

Command (? for help):
```

Delete any existing partitions using the `d` command.

Use the `n` command repeatedly to create new partitions with the following parameters:

Partition no.|First sector  |Last Sector|Hex code|Comment
-------------|--------------|-----------|--------|---------------------
1            |default (2048)|+512M      |EF00    |ESP
2            |default       |+40G       |8300    |Root
3            |default       |+16G       |8200    |Swap
4            |default       |default    |8300    |Home

If dual booting with Windows, use the following parameters:

Partition no.|First sector  |Last Sector|Hex code|Comment
-------------|--------------|-----------|--------|---------------------
1            |default (2048)|+512M      |EF00    |ESP
2            |default       |+16M       |0C01    |Microsoft reserved
3            |default       |+40G       |0700    |Windows
4            |default       |+300M      |2700    |Windows Recovery (RE)
5            |default       |+40G       |8300    |Root
6            |default       |+16G       |8200    |Swap
7            |default       |default    |8300    |Home

Use the `p` command to check the partition structure:

```
Disk /dev/nvme0n1: 2000409264 sectors, 953.9 GiB
Model: SAMSUNG MZVLQ1T0HBLB-00B                
Sector size (logical/physical): 512/512 bytes
Disk identifier (GUID): A8683D17-4FEE-4E97-9C13-9A8E2160F60E
Partition table holds up to 128 entries
Main partition table begins at sector 2 and ends at sector 33
First usable sector is 34, last usable sector is 2000409230
Partitions will be aligned on 2048-sector boundaries
Total free space is 2669 sectors (1.3 MiB)

Number  Start (sector)    End (sector)  Size       Code  Name
   1            2048         1050623   512.0 MiB   EF00  EFI system partition
   2         1050624         1083391   16.0 MiB    0C01  Microsoft reserved
   3         1083392        84969471   40.0 GiB    0700  Microsoft basic data
   4        84969472        85583871   300.0 MiB   2700  Windows RE
   5        85583872       169469951   40.0 GiB    8300  Linux filesystem
   6       169469952       203024383   16.0 GiB    8200  Linux swap
   7       203024384      2000408575   837.1 GiB   8300  Linux filesystem
```

If everything is correct, use the `w` command to save partitions, and then `q` to exit `gdisk`.

#### b. Format Partitions

Format the `ESP` partition (**do this only if Windows is not already installed**):

```bash
mkfs.fat -F32 -n "ESP" /dev/nvme0n1p1
```

Format the Windows data and recovery partitions (**do this only if Windows is not already installed**):

```bash
mkfs.ntfs -f /dev/nvme0n1p3
mkfs.ntfs -f /dev/nvme0n1p4
```

Activate the `swap` partition:

```bash
mkswap /dev/nvme0n1p6
swapon /dev/nvme0n1p6
```

Format the `root` partition:

```bash
mkfs.ext4 -L "Root" /dev/nvme0n1p5
```

Format the `home` partition (**do this only if the `home` partition is empty**):

```bash
mkfs.ext4 -L "Home" /dev/nvme0n1p7
```

#### c. Mount Partitions

Mount the `root` partition:

```bash
mount /dev/nvme0n1p5 /mnt
```

Mount the `ESP` partition:

```bash
mount --mkdir /dev/nvme0n1p1 /mnt/boot
```

Mount the `home` partition:

```bash
mount --mkdir /dev/nvme0n1p7 /mnt/home
```

Use the `lsblk` command to verify partitions are correctly mounted.

---

## C. Installation

### 1. Install Base Packages

Update the Arch Linux keyring:

```bash
pacman -Syy
pacman -S archlinux-keyring
```

Install the base packages:

```bash
pacstrap /mnt base base-devel linux linux-firmware sof-firmware nano man-db man-pages
```

### 2. Generate Fstab File

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

In case of errors, __do not run the command a second time__, edit the `fstab` file manually.

### 3. Change Root into New System

```bash
arch-chroot /mnt
```

---

## D. System Configuration

### 1. Set Keyboard layout

> Note: this step is only required for non-US keyboards

Make the keyboard layout permanent:

```bash
echo KEYMAP=it > /etc/vconsole.conf
```

Replace `it` with your keymap.

### 2. Configure Timezone

Set the time zone:

```bash
TIMEZONE="Europe/Rome"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
```

The timezone format is `Region/City` where _Region_ and _City_ depend on location. To check available timezones, see the files/folders in `/usr/share/zoneinfo/`.

### 3. Sync Hardware Clock

Set the hardware clock to UTC:

```bash
hwclock --systohc --utc
```

### 4. Configure Locale

Uncomment locales in the `/etc/locale.gen` file:

```bash
LOCALE_US="en_US.UTF-8"
LOCALE_IE="en_IE.UTF-8"

sed -i "/#$LOCALE_US/ s/^#//" /etc/locale.gen
sed -i "/#$LOCALE_IE/ s/^#//" /etc/locale.gen
```

Generate locales:

```bash
locale-gen
```

Create locale configuration file:

```bash
cat > /etc/locale.conf <<-LOCALECONF
  LANG=$locale_US
  LC_MEASUREMENT=$locale_IE
  LC_PAPER=$locale_IE
  LC_TIME=$locale_IE
LOCALECONF
```

### 5. Configure Hostname

Create the `hostname` file:

```bash
PCNAME="SamsungBook2"
echo $PCNAME > /etc/hostname
```

Create the `hosts` file:

```bash
cat > /etc/hosts <<-HOSTSFILE
  127.0.0.1       localhost
  ::1             localhost
  127.0.1.1       ${pc_name}.localdomain      ${pc_name}
HOSTSFILE
```

### 6. Configure Pacman

Enable color output and parallel downloads in pacman:

```bash
sed -i -f - /etc/pacman.conf <<-PACMAN_CONF
  s/#Color/Color/
  s/#ParallelDownloads/ParallelDownloads/
PACMAN_CONF
```

Configure ZST compression for packages:

```bash
sed -i -f - /etc/makepkg.conf <<-MAKEPKG_CONF
  /^OPTIONS=/ s/ debug/ !debug/
  /^COMPRESSZST=/ c COMPRESSZST=(zstd -c -T0 -)
MAKEPKG_CONF
```

### 7. Enable Multilib Repository (Optional)

Enable the `multilib` repository:

```bash
sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf
```

Refresh package databases:

```bash
pacman -Syy
```

### 8. Configure Root Password

To set the root password, run the following command and input a password:

```bash
passwd
```

### 9. Add New User with Sudo Privileges

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
bash -c 'echo "%wheel ALL=(ALL) ALL" | (EDITOR="tee -a" visudo -f /etc/sudoers.d/99_wheel)'
```

### 10. Install Boot Loader

Install `grub` and `efibootmgr`:

```bash
pacman -S grub efibootmgr
```

_Optionally_ install `os-prober` (only needed to detect other operating systems in a dual boot scenario):

```bash
pacman -S os-prober
```

Install the `grub` boot loader:

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --removable
```

Install the `microcode` package (Intel CPUs):

```bash
pacman -S intel-ucode
```

Enable 'os-prober' if installed:

```bash
sed -i '/^#GRUB_DISABLE_OS_PROBER/ c GRUB_DISABLE_OS_PROBER=false' /etc/default/grub
```

_Optionally_ add custom GRUB entries (shutdown and restart):

```bash
cat >> /etc/grub.d/40_custom <<-CUSTOM_GRUB
	menuentry 'System shutdown' --class shutdown {
	    echo 'System shutting down...'
	    halt
	}

	menuentry 'System restart' --class restart {
	    echo 'System rebooting...'
	    reboot
	}
CUSTOM_GRUB

```

Generate the `grub.cfg` file (this will also enable automatic `microcode` updates):

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

---

## E. Desktop Environment

### 1. Install Video Drivers

> Note: not required for VirtualBox/GNOME Boxes installation

#### a. Intel

Install the Mesa OpenGL driver:

```bash
pacman -S --needed --asdeps mesa
```

> Note: the `xf86-video-intel` Intel driver is optional, see https://wiki.archlinux.org/index.php/Intel_graphics#Installation.

_Optionally_ install the Intel VA-API driver for hardware video acceleration:

```bash
pacman -S intel-media-driver libva-utils
```

#### b. nVidia (proprietary drivers)

Install the nVidia video drivers:

```bash
pacman -S nvidia nvidia-prime
```

Enable the DRM kernel mode setting, to ensure that the Wayland session is available in GNOME:

```bash
KERNEL_PARAMS=$(cat /etc/default/grub | grep 'GRUB_CMDLINE_LINUX_DEFAULT=' | cut -f2 -d'"')
KERNEL_PARAMS+=" nvidia-drm.modeset=1"
sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/ c GRUB_CMDLINE_LINUX_DEFAULT=\"$KERNEL_PARAMS\"" /etc/default/grub
```

And re-generate the `grub.cfg` file:

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

#### c. Nouveau (open-source nVidia drivers)

Install the Mesa OpenGL driver:

```bash
pacman -S --needed --asdeps mesa
```

Install the open source Nouveau driver for nVidia:

```bash
pacman -S xf86-video-nouveau
```

### 2. Install PipeWire

Install PipeWire packages as dependencies:

```bash
pacman -S --asdeps pipewire pipewire-pulse pipewire-alsa wireplumber gst-plugin-pipewire rtkit
```

### 3. Install GNOME

Install Network Manager and GNOME package group (press `ENTER` to select all packages when prompted):

```bash
pacman -S networkmanager gnome --ignore epiphany,gnome-characters,gnome-clocks,gnome-contacts,gnome-logs,gnome-maps,gnome-music,gnome-software,gnome-tour,orca,rygel,totem
```

If prompted to select provider(s), select default options.

Install optional GNOME dependencies:

```bash
pacman -S --asdeps power-profiles-daemon fwupd system-config-printer
```

Install GNOME extras:

```bash
pacman -S gnome-tweaks file-roller dconf-editor
```

Enable the `gdm` (GNOME Display Manager) login screen:

```bash
systemctl enable gdm.service
```

Enable the Network Manager service:

```bash
systemctl enable NetworkManager.service
```

### 4. Enable Bluetooth

Install Bluetooth packages:

```bash
pacman -S --needed bluez bluez-utils bluez-tools
```

Enable power status reporting:

```bash
mkdir -p /etc/systemd/system/bluetooth.service.d

cat > /etc/systemd/system/bluetooth.service.d/10-experimental.conf <<-BLUETOOTH_POWER
  [Service]
  ExecStart=
  ExecStart=/usr/lib/bluetooth/bluetoothd -E
BLUETOOTH_POWER
```

Enable the Bluetooth service:

```bash
systemctl enable bluetooth.service
```

### 5. Install Multimedia Codecs

Install needed codecs:

```bash
pacman -S --needed libmad gstreamer gst-libav gst-plugins-base gst-plugins-bad gst-plugins-good gst-plugins-ugly
```

_Optionally_ install the VA-API plugin for hardware video acceleration:

```bash
pacman -S --needed gstreamer-vaapi
```

### 6. Reboot

Exit the `chroot` environment:

```bash
exit
```

Unmount partitions:

```bash
umount -R /mnt
```

Restart the machine to boot into GNOME:

```bash
reboot
```
