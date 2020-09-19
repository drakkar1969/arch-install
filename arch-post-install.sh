#!/bin/bash

#===========================================================================================================
# GLOBAL VARIABLES
#===========================================================================================================
MAINCHECKLIST=(0 0 0 0 0 0 0 0 0 0 0 0)
FMTCHECKLIST=(0 0 0 0)

RED='\033[1;31m'
GREEN='\033[1;32m'
RESET='\033[0m'

#===========================================================================================================
# HELPER FUNCTIONS
#===========================================================================================================
print_menu_item()
{
	local _INDEX=$1
	local _STATUS=$2
	local _ITEMNAME=$3

	local _CHECKMARK="${GREEN}OK${RESET}"

	if [[ $_STATUS -eq 0 ]]; then
		_CHECKMARK="  "
	fi

	echo -e "\n $_INDEX. [ $_CHECKMARK ] $_ITEMNAME"
}

print_submenu_heading()
{
	clear

	echo -e ":: ${GREEN}$1${RESET}\n"
}

print_progress_text()
{
	echo -e "${GREEN}==>${RESET} $1"
	echo ""
}

print_warning()
{
	echo -e "${RED}Warning:${RESET} $1"
}

print_file_contents()
{
	echo ""
	echo -e "---------------------------------------------------------------------------"
	echo -e "-- ${GREEN}$1${RESET}"
	echo -e "---------------------------------------------------------------------------"
	echo ""
	cat $1
	echo ""
	echo -e "---------------------------------------------------------------------------"
	echo ""
}

get_any_key()
{
	echo ""
	read -s -e -n 1 -p "Press any key to continue ..."
}

get_yn_confirmation()
{
	local _RESULTVAR=$1
	local _YNCHOICE="n"

	read -s -e -n 1 -p "Are you sure you want to continue [y/n]: " _YNCHOICE
	echo ""

	eval $_RESULTVAR="'$_YNCHOICE'"
}

get_user_variable()
{
	local _RESULTVAR=$1

	read -e -p "Enter $2: " -i "$3" _USERINPUT
	echo ""

	eval $_RESULTVAR="'$_USERINPUT'"
}

print_partition_structure()
{
	echo -e "---------------------------------------------------------------------------"
	echo -e "-- ${GREEN}Current partition structure${RESET}"
	echo -e "---------------------------------------------------------------------------"
	echo ""
	lsblk
	echo ""
	echo -e "---------------------------------------------------------------------------"
	echo ""
}

get_partition_info()
{
	local _BLKPARTINFO=$(lsblk --output NAME,SIZE,FSTYPE --paths --raw | grep -i $1)
	local _BLKPARTID=$(echo $_BLKPARTINFO | awk '{print $1}')
	local _BLKPARTSIZE=$(echo $_BLKPARTINFO | awk '{print $2}')
	local _BLKPARTFS=$(echo $_BLKPARTINFO | awk '{print $3}')

	echo -e "${GREEN}$_BLKPARTID${RESET} [type: ${GREEN}$_BLKPARTFS${RESET}; size: ${GREEN}$_BLKPARTSIZE${RESET}]"
}

#===========================================================================================================
# INSTALLATION FUNCTIONS
#===========================================================================================================
set_kbpermanent()
{
	print_submenu_heading "MAKE KEYBOARD LAYOUT PERMANENT"

	local _USERCONFIRM="n"

	get_user_variable KBCODE "keyboard layout" "it"

	echo -e "Make keyboard layout ${GREEN}${KBCODE}${RESET} permanent."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Setting keyboard layout"
		echo KEYMAP=$KBCODE > /etc/vconsole.conf

		MAINCHECKLIST[0]=1

		get_any_key
	fi
}

set_timezone()
{
	print_submenu_heading "CONFIGURE TIMEZONE"

	local _USERCONFIRM="n"

	get_user_variable TIMEZONE "timezone" "Europe/Warsaw"

	echo -e "Set the timezone to ${GREEN}${TIMEZONE}${RESET}."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Creating symlink for timezone $TIMEZONE"
		ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

		MAINCHECKLIST[1]=1

		get_any_key
	fi
}

sync_hwclock()
{
	print_submenu_heading "SYNC HARDWARE CLOCK"

	local _USERCONFIRM="n"

	echo -e "Sync hardware clock."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Setting hardware clock to UTC"
		hwclock --systohc --utc

		MAINCHECKLIST[2]=1

		get_any_key
	fi
}

set_locale()
{
	print_submenu_heading "CONFIGURE LOCALE"

	local _USERCONFIRM="n"

	get_user_variable LOCALE_US "language locale" "en_US"
	get_user_variable LOCALE_DK "format locale" "en_DK"

	echo -e "Set the language to ${GREEN}${LOCALE_US}${RESET} and the format locale to ${GREEN}${LOCALE_DK}${RESET}."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Setting language to $LOCALE_US and formats to $LOCALE_DK"
		LOCALE_US_UTF="$LOCALE_US.UTF-8"
		LOCALE_DK_UTF="$LOCALE_DK.UTF-8"

		sed -i "/#$LOCALE_US_UTF/ s/^#//" /etc/locale.gen
		sed -i "/#$LOCALE_DK_UTF/ s/^#//" /etc/locale.gen

		locale-gen

		cat > /etc/locale.conf <<-LOCALECONF
			LANG=$LOCALE_US_UTF
			LC_MEASUREMENT=$LOCALE_DK_UTF
			LC_MONETARY=$LOCALE_US_UTF
			LC_NUMERIC=$LOCALE_US_UTF
			LC_PAPER=$LOCALE_DK_UTF
			LC_TIME=$LOCALE_DK_UTF
		LOCALECONF

		export LANG=$LOCALE_US_UTF
		export LC_MEASUREMENT=$LOCALE_DK_UTF
		export LC_MONETARY=$LOCALE_US_UTF
		export LC_NUMERIC=$LOCALE_US_UTF
		export LC_PAPER=$LOCALE_DK_UTF
		export LC_TIME=$LOCALE_DK_UTF

		print_file_contents "/etc/locale.conf"

		MAINCHECKLIST[3]=1

		get_any_key
	fi
}

set_hostname()
{
	print_submenu_heading "CONFIGURE HOSTNAME"

	local _USERCONFIRM="n"

	get_user_variable PCNAME "hostname" "ProBook450"

	echo -e "Set the hostname to ${GREEN}${PCNAME}${RESET}."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Setting hostname to $PCNAME"
		echo $PCNAME > /etc/hostname

		cat > /etc/hosts <<-HOSTSFILE
			127.0.0.1       localhost
			::1             localhost
			127.0.1.1       ${PCNAME}.localdomain      ${PCNAME}
		HOSTSFILE

		print_file_contents "/etc/hostname"
		print_file_contents "/etc/hosts"

		MAINCHECKLIST[4]=1

		get_any_key
	fi
}

enable_multilib()
{
	print_submenu_heading "ENABLE MULTILIB REPOSITORY"

	local _USERCONFIRM="n"

	echo -e "Enable the multilib repository in ${GREEN}/etc/pacman.conf${RESET}."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Enabling multilib repository in /etc/pacman.conf"
		sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf

		print_file_contents "/etc/pacman.conf"

		print_progress_text "Refreshing package databases"
		pacman -Syy

		MAINCHECKLIST[5]=1

		get_any_key
	fi
}

root_password()
{
	print_submenu_heading "CONFIGURE ROOT PASSWORD"

	local _USERCONFIRM="n"

	echo -e "Set the password for the root user."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		passwd

		MAINCHECKLIST[6]=1

		get_any_key
	fi
}

add_sudouser()
{
	print_submenu_heading "ADD NEW USER WITH SUDO PRIVILEGES"

	local _USERCONFIRM="n"

	get_user_variable NEWUSER "user name" "drakkar"
	get_user_variable USERDESC "user description" "draKKar"

	echo -e "Create new user ${GREEN}${NEWUSER}${RESET} with sudo privileges."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Creating new user $NEWUSER"
		useradd -m -G wheel -c $USERDESC -s /bin/bash $NEWUSER

		print_progress_text "Setting password for user $NEWUSER"
		passwd $NEWUSER

		print_progress_text "Enabling sudo privileges for user $NEWUSER"
		bash -c 'echo "%wheel ALL=(ALL) ALL" | (EDITOR="tee -a" visudo)'

		print_progress_text "Verifying user $NEWUSER identity"
		id $NEWUSER

		MAINCHECKLIST[7]=1

		get_any_key
	fi
}

install_bootloader()
{
	print_submenu_heading "INSTALL BOOT LOADER"

	local _USERCONFIRM="n"

	echo -e "Install the grub bootloader."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Installing grub bootloader"
		pacman -S grub efibootmgr os-prober
		grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub

		print_progress_text "Installing microcode package"
		pacman -S intel-ucode

		print_progress_text "Copying .efi stub to ensure boot in UEFI mode"
		mkdir /boot/EFI/boot/
		cp /boot/EFI/grub/grubx64.efi /boot/EFI/boot/bootx64.efi

		print_progress_text "Generating grub.cfg file"
		grub-mkconfig -o /boot/grub/grub.cfg

		MAINCHECKLIST[8]=1

		get_any_key
	fi
}

install_xorg()
{
	print_submenu_heading "INSTALL XORG GRAPHICAL ENVIRONMENT"

	local _USERCONFIRM="n"

	echo -e "Install Xorg graphical environment."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Installing Xorg"
		echo -e "If prompted to select provider(s), select default options"
		echo ""
 		pacman -S xorg-server

		print_progress_text "Installing X widgets for testing"
		pacman -S xorg-xinit xorg-twm xterm

		MAINCHECKLIST[9]=1

		get_any_key
	fi
}

display_drivers()
{
	print_submenu_heading "INSTALL DISPLAY DRIVERS"

	local _USERCONFIRM="n"

	echo -e "Install display drivers."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Installing nVidia video drivers"
		echo -e "If prompted to select provider(s), select default options"
		echo ""
		pacman -S nvidia lib32-virtualgl lib32-nvidia-utils

		MAINCHECKLIST[10]=1

		get_any_key
	fi
}

install_gnome()
{
	print_submenu_heading "INSTALL GNOME DESKTOP ENVIRONMENT"

	local _USERCONFIRM="n"

	get_user_variable GNOMEIGNORE "GNOME packages to ignore" "epiphany,gnome-books,gnome-boxes,gnome-calendar,gnome-clocks,gnome-contacts,gnome-dictionary,gnome-documents,gnome-maps,gnome-photos,gnome-software,orca"

	echo -e "Install the GNOME desktop environment."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Installing GNOME"
		echo -e "If prompted to select provider(s), select default options"
		echo ""

		if [[ "$GNOMEIGNORE" != "" ]]; then
			pacman -S gnome --ignore $GNOMEIGNORE
		else
			pacman -S gnome
		fi

		print_progress_text "Installing additional GNOME packages"
		pacman -S dconf-editor ghex gnome-nettool gnome-tweaks

		print_progress_text "Enabling GDM service"
		systemctl enable gdm.service

		print_progress_text "Enabling Network Manager service"
		systemctl enable NetworkManager.service

		MAINCHECKLIST[11]=1

		get_any_key
	fi
}

main_menu()
{
	clear

	echo -e "-------------------------------------------------------------------------------"
	echo -e "-- ${GREEN} ARCH LINUX ${RESET}::${GREEN} MAIN MENU${RESET}"
	echo -e "-------------------------------------------------------------------------------"

	print_menu_item A ${MAINCHECKLIST[0]} 'Make keyboard layout permanent'
	print_menu_item B ${MAINCHECKLIST[1]} 'Configure timezone'
	print_menu_item C ${MAINCHECKLIST[2]} 'Sync hardware clock'
	print_menu_item D ${MAINCHECKLIST[3]} 'Configure locale'
	print_menu_item E ${MAINCHECKLIST[4]} 'Configure hostname'
	print_menu_item F ${MAINCHECKLIST[5]} 'Enable multilib repository'
	print_menu_item G ${MAINCHECKLIST[6]} 'Configure root password'
	print_menu_item H ${MAINCHECKLIST[7]} 'Add new user with sudo privileges'
	print_menu_item I ${MAINCHECKLIST[8]} 'Install boot loader'
	print_menu_item J ${MAINCHECKLIST[9]} 'Install Xorg graphical environment'
	print_menu_item K ${MAINCHECKLIST[10]} 'Install display drivers'
	print_menu_item L ${MAINCHECKLIST[11]} 'Install GNOME desktop environment'

	echo ""
	echo -e "-------------------------------------------------------------------------------"
	echo ""
	read -s -e -n 1 -p " => Select option or (q)uit: " _MAINCHOICE
	echo ""

	case $_MAINCHOICE in
		[aA])
			set_kbpermanent
			;;
		[bB])
			set_timezone
			;;
		[cC])
			sync_hwclock
			;;
		[dD])
			set_locale
			;;
		[eE])
			set_hostname
			;;
		[fF])
			enable_multilib
			;;
		[gG])
			root_password
			;;
		[hH])
			add_sudouser
			;;
		[iI])
			install_bootloader
			;;
		[jJ])
			install_xorg
			;;
		[kK])
			display_drivers
			;;
		[lL])
			install_gnome
			;;
		[qQ])
			clear
			echo -e "Exit the chroot environment:"
			echo ""
			echo -e "   > ${GREEN}exit${RESET}"
			echo ""
			echo -e "Unmount partitions:"
			echo ""
			echo -e "   > ${GREEN}umount -R /mnt/boot${RESET}"
			echo -e "   > ${GREEN}umount -R /mnt/home${RESET}"
			echo -e "   > ${GREEN}umount -R /mnt${RESET}"
			echo ""
			echo -e "Restart to boot into GNOME:"
			echo ""
			echo -e "   > ${GREEN}reboot${RESET}"
			echo ""
			exit 0
			;;
	esac
}

while true
do
	main_menu
done
