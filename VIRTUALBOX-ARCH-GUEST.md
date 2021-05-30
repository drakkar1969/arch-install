## VirtualBox: Installing Arch Linux as Guest

#### 1. System Settings

| Option           | Settings Section      | Details                                                      |
| ---------------- | --------------------- | ------------------------------------------------------------ |
| UEFI Mode        | System -> Motherboard | Enable the `Enable EFI (special OSes only)` checkbox         |
| RAM              | System -> Motherboard | Select at least 2048 MB of base memory to run GNOME          |
| CPU              | System -> Processor   | Select at least 2 processors to run GNOME                    |
| Networking       | Network -> Advanced   | Select the `Paravitualized Network (virtio-net)` in the `Adapter Type` dropdown for best performance |
| Shared Clipboard | General -> Advanced   | Select `Bidirectional` in the `Shared clipboard` dropdown    |

#### 2. Install Guest Additions

Install the Guest Additions in the guest system:

```bash
sudo pacman -S virtualbox-guest-utils
```

#### 3. Load VirtualBox Kernel Modules

To load the VirtualBox kernel modules automatically, enable the `vboxservice` service in the guest system:

```bash
sudo systemctl enable vboxservice.service
```

This will also enable time synchronization between host and guest systems.

#### 4. Enable Shared Folders

Add the user in the guest system to the `vboxsf` group, which should have been created during installation of the Guest Additions:

```bash
sudo usermod -aG vboxsf [username]
```

Replace `[username]` with the guest system username.

Create a new shared folder in `Settings -> Shared Folders` under `Machine Folders`. For example:

```bash
Folder path: /home/drakkar/Scratch/VBOXSHARE   # Note: on host system
Folder name: VirtualBoxShare
Read-only: No
Auto-mount: Yes
Mount point: /media/VirtualBoxShare   # Note: on guest system
Make permanent: Yes
```

#### 5. Restart

Restart the guest system to apply settings.
