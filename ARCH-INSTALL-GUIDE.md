# Arch Linux Installation Guide (UEFI)

## A. Pre-Installation

### 1. Set Keyboard Layout

> Note: this step is only required for non-US keyboards

The default keymap is US. Set your keymap with the command:

```bash
loadkeys it
```

Replace `it` with your actual keymap.

Available layouts can be listed with:

```bash
localectl list-keymaps
```

### 2. Set Console Font

Set the console font:

```bash
setfont ter-128b
```

Replace `ter-128b` with your font name. Available fonts can be listed with:

```bash
ls /usr/share/kbd/consolefonts
```

### 3. Check UEFI Mode

To verify that UEFI boot mode is enabled, list the `efivars` directory:

```bash
cat /sys/firmware/efi/fw_platform_size
```

If the command does not return `64`, the system may be in MBR/BIOS mode.

### 4. Enable Internet Connection

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

### 5. Update System Clock

Ensure the system clock is accurate:

```bash
timedatectl set-ntp true
```

To check the status, use `timedatectl` without parameters.

### 6. Create Partitions

This section assumes that `/dev/nvme0n1` is the primary SSD.

You can use the `lsblk` command to check this.

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

#### a. Installing Arch Linux only (no dual boot)

Delete any existing partitions using the `d` command.

Use the `n` command repeatedly to create the Arch Linux partitions with the following parameters:

Partition no.|First sector  |Last Sector|Hex code|Comment
-------------|--------------|-----------|--------|---------------------
1            |default (2048)|+512M      |EF00    |ESP
2            |default       |+40G       |8300    |Root
3            |default       |+16G       |8200    |Swap
4            |default       |default    |8300    |Home

#### b. Installing Arch Linux alongside an existing Windows install (dual boot)

Add new Arch Linux partitions with `n` command, using the following parameters:

Partition no.|First sector  |Last Sector|Hex code|Comment
-------------|--------------|-----------|--------|---------------------
default      |default       |+40G       |8300    |Root
default      |default       |+16G       |8200    |Swap
default      |default       |default    |8300    |Home

**Do not create a new ESP partition, do not delete/modify existing Windows partitions.**

#### c. Installing both Arch Linux and Windows from scratch (dual boot)

Delete any existing partitions using the `d` command.

Use the `n` command repeatedly to create the Arch Linux/Windows partitions with the following parameters:

Partition no.|First sector  |Last Sector|Hex code|Comment
-------------|--------------|-----------|--------|---------------------
1            |default (2048)|+512M      |EF00    |ESP
2            |default       |+16M       |0C01    |Microsoft reserved
3            |default       |+40G       |0700    |Windows
4            |default       |+300M      |2700    |Windows Recovery (RE)
5            |default       |+40G       |8300    |Root
6            |default       |+16G       |8200    |Swap
7            |default       |default    |8300    |Home

When done partitioning, use the `p` command to check the partition structure, for example:

```
Disk /dev/nvme0n1: 2000409264 sectors, 953.9 GiB
Model: ESO01TBHLCJ-EL1-2AK                     
Sector size (logical/physical): 512/512 bytes
Disk identifier (GUID): A9FCE571-4748-4B2C-A67B-B3E619E6DF85
Partition table holds up to 128 entries
Main partition table begins at sector 2 and ends at sector 33
First usable sector is 34, last usable sector is 2000409230
Partitions will be aligned on 2048-sector boundaries
Total free space is 2669 sectors (1.3 MiB)

Number  Start (sector)    End (sector)  Size       Code  Name
   1            2048          534527   260.0 MiB   EF00  EFI system partition
   2          534528          567295   16.0 MiB    0C01  Microsoft reserved ...
   3          567296       134785023   64.0 GiB    0700  Basic data partition
   4      1956368384      1958465535   1024.0 MiB  2700  Basic data partition
   5      1958465536      1998311423   19.0 GiB    2700  Basic data partition
   6      1998311424      2000408575   1024.0 MiB  FFFF  EFI system partition
   7       134785024       218671103   40.0 GiB    8300  Linux filesystem
   8       218671104       252225535   16.0 GiB    8200  Linux swap
   9       252225536      1956368383   812.6 GiB   8300  Linux filesystem
```

If everything is correct, use the `w` command to save partitions and exit `gdisk`.

### 7. Format Partitions

#### a. Installing Arch Linux only (no dual boot)

Format the `ESP` partition:

```bash
mkfs.fat -F32 -n "ESP" /dev/nvme0n1p1
```

Activate the `swap` partition:

```bash
mkswap /dev/nvme0n1p3
swapon /dev/nvme0n1p3
```

Format the `root` partition:

```bash
mkfs.ext4 -L "Root" /dev/nvme0n1p2
```

Format the `home` partition (**do this only if the `home` partition is empty**):

```bash
mkfs.ext4 -L "Home" /dev/nvme0n1p4
```

#### b. Installing Arch Linux alongside an existing Windows install (dual boot)

> Check partition IDs using the `lsblk` command

Activate the `swap` partition:

```bash
mkswap /dev/nvme0n1p3
swapon /dev/nvme0n1p3
```

Format the `root` partition:

```bash
mkfs.ext4 -L "Root" /dev/nvme0n1p2
```

Format the `home` partition (**do this only if the `home` partition is empty**):

```bash
mkfs.ext4 -L "Home" /dev/nvme0n1p4
```

**Do not format the ESP partition or existing Windows partitions.**

#### c. Installing both Arch Linux and Windows from scratch (dual boot)

Format the `ESP` partition:

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

### 8. Mount Partitions

> Check partition IDs using the `lsblk` command

Mount the `root` partition:

```bash
mount /dev/nvme0n1p2 /mnt
```

Mount the `ESP` partition:

```bash
mount --mkdir /dev/nvme0n1p1 /mnt/boot
```

Mount the `home` partition:

```bash
mount --mkdir /dev/nvme0n1p4 /mnt/home
```

Use the `lsblk` command to verify partitions are correctly mounted.

---

## B. Installation

### 1. Install Base Packages

Update the Arch Linux keyring:

```bash
pacman -Syy
pacman -S archlinux-keyring
```

Install the base packages:

```bash
pacstrap /mnt base base-devel linux linux-firmware sof-firmware nano man-db man-pages terminus-font
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

## C. System Configuration

### 1. Console Settings

Make the keyboard layout and console font permanent:

```bash
cat > /etc/vconsole.conf <<-VCONSOLE_CONF
  KEYMAP=it
  FONT=ter-128b
VCONSOLE_CONF
```

Replace `it` with your keymap and `ter-128b` with your preferred console font.

> Note: the `KEYMAP=...` line is only required for non-US keyboards

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
PCNAME="LG-GRAM"
echo $PCNAME > /etc/hostname
```

### 6. Configure Pacman

Enable color output and parallel downloads in pacman:

```bash
sed -i -f - /etc/pacman.conf <<-PACMAN_CONF
  s/#Color/Color/
  s/#ParallelDownloads/ParallelDownloads/
PACMAN_CONF
```

Disable debug builds and configure ZST compression for packages:

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

Enable `os-prober` if installed:

```bash
sed -i '/^#GRUB_DISABLE_OS_PROBER/ c GRUB_DISABLE_OS_PROBER=false' /etc/default/grub
```

Disable watchdogs by adding the `modprobe.blacklist=iTCO_wdt` kernel parameter in GRUB's configuration:

```bash
kernel_params=$(cat /etc/default/grub | grep 'GRUB_CMDLINE_LINUX_DEFAULT=' | cut -f2 -d'"')

params="modprobe.blacklist=iTCO_wdt"

if [[ $kernel_params != *"$params"* ]]; then kernel_params+=" $params"; fi

sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/ c GRUB_CMDLINE_LINUX_DEFAULT=\"$kernel_params\"" /etc/default/grub
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

## D. Desktop Environment

### 1. Install Video Drivers

> Note: not required for VirtualBox/GNOME Boxes installation

Install the Mesa OpenGL driver:

```bash
pacman -S --needed --asdeps mesa
```

_Optionally_ install the Intel VA-API driver for hardware video acceleration:

```bash
pacman -S intel-media-driver libva-utils
```

### 2. Install PipeWire

Install PipeWire packages as dependencies:

```bash
pacman -S --asdeps pipewire pipewire-pulse pipewire-jack wireplumber gst-plugin-pipewire rtkit
```

### 3. Install GNOME

Install Network Manager and GNOME package group (press `ENTER` to select all packages when prompted):

```bash
pacman -S networkmanager gnome --ignore epiphany,gnome-characters,gnome-clocks,gnome-contacts,gnome-logs,gnome-maps,gnome-music,gnome-software,gnome-tour,orca,totem
```

If prompted to select provider(s), select default options.

Install optional power profiles daemon:

```bash
pacman -S --asdeps power-profiles-daemon
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
pacman -S --needed bluez bluez-utils
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
pacman -S --needed libmad gstreamer gst-libav gst-plugins-base gst-plugins-bad gst-plugins-good gst-plugins-ugly gst-plugin-va
```

_Optionally_ install the VA-API plugin for hardware video acceleration:

```bash
pacman -S --needed gst-plugin-va
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
