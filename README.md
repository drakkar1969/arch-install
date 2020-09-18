Download and execute the `arch-install.sh` script:

```shell
curl https://raw.githubusercontent.com/drakkar1969/arch-install/master/arch-install.sh
bash arch-install.sh
```
After completing installation, change root into the new system:

```shell
arch-chroot /mnt /bin/bash
```

Download and execute the post-installation script `arch-post-install.sh`:

```shell
curl https://raw.githubusercontent.com/drakkar1969/arch-install/master/arch-post-install.sh
bash arch-post-install.sh
```
