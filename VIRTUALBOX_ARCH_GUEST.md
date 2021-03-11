## VirtualBox: Installing Arch Linux as Guest

#### Enable UEFI Mode

Go to `Settings -> System` and enable the `Enable EFI (special OSes only)` checkbox.

Note: booting from UEFI may hang the first time for a minute or two.

#### Allocate Base Memory

To run GNOME with GDM, ensure the guest system has at least 2048 MB of base memory in `Settings -> System`.

#### Enable Shared Clipboard

To enable copy and paste between host and guest, go to `Settings -> General -> Advanced` and select `Bidirectional` in the shared clipboard dropdown.

#### Install Guest Additions

In the guest system, install the Guest Additions:

```bash
sudo pacman -S virtualbox-guest-utils
```

#### Load VirtualBox Kernel Modules

To load the VirtualBox kernel modules automatically, enable the `vboxservice` service:

```bash
sudo systemctl enable vboxservice.service
```

This will also enable time synchronization between host and guest systems.

#### Reboot

Reboot the guest system:

```bash
reboot
```

#### Enable Shared Folders

Add the user in the guest system to the `vboxsf` group, which should have been created during installation of the Guest Additions:

```bash
sudo usermod -aG vboxsf [username]
```

Replace `[username]` with the guest system username.

Create a new shared folder in `Settings -> Shared Folders` under `Machine Folders`. For example:

```bash
Folder path: /home/drakkar/Scratch/VBOXSHARE
Folder name: VirtualBoxShare
Read-only: Yes
Auto-mount: Yes
Mount point: /media/VirtualBoxShare
Make permanent: Yes
```
