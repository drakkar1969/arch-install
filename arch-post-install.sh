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
	local index=$1
	local status=$2
	local itemname=$3

	local checkmark="${GREEN}OK${RESET}"

	if [[ $status -eq 0 ]]; then
		checkmark="  "
	fi

	echo -e "\n $index. [ $checkmark ] $itemname"
}

print_submenu_heading()
{
	clear

	echo -e ":: ${GREEN}$1${RESET}\n"
}

print_progress_text()
{
	echo ""
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
	local output=$1
	local yn_choice="n"

	read -s -e -n 1 -p "Are you sure you want to continue [y/N]: " yn_choice

	eval $output="'$yn_choice'"
}

get_user_variable()
{
	local output=$1

	read -e -p "Enter $2: " -i "$3" user_input
	echo ""

	eval $output="'$user_input'"
}

#===========================================================================================================
# INSTALLATION FUNCTIONS
#===========================================================================================================
set_kbpermanent()
{
	print_submenu_heading "MAKE KEYBOARD LAYOUT PERMANENT"

	local user_confirm="n"

	local kb_code

	get_user_variable kb_code "keyboard layout" "it"

	echo -e "Make keyboard layout ${GREEN}${kb_code}${RESET} permanent."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Setting keyboard layout"
		echo KEYMAP=$kb_code > /etc/vconsole.conf

		MAINCHECKLIST[0]=1

		get_any_key
	fi
}

set_timezone()
{
	print_submenu_heading "CONFIGURE TIMEZONE"

	local user_confirm="n"
	local timezone

	get_user_variable timezone "timezone" "Europe/Sarajevo"

	echo -e "Set the timezone to ${GREEN}${timezone}${RESET}."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Creating symlink for timezone $timezone"
		ln -sf /usr/share/zoneinfo/$timezone /etc/localtime

		MAINCHECKLIST[1]=1

		get_any_key
	fi
}

sync_hwclock()
{
	print_submenu_heading "SYNC HARDWARE CLOCK"

	local user_confirm="n"

	echo -e "Sync hardware clock."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Setting hardware clock to UTC"
		hwclock --systohc --utc

		MAINCHECKLIST[2]=1

		get_any_key
	fi
}

set_locale()
{
	print_submenu_heading "CONFIGURE LOCALE"

	local user_confirm="n"

	local locale_US
	local locale_DK

	get_user_variable locale_US "language locale" "en_US"
	get_user_variable locale_DK "format locale" "en_DK"

	echo -e "Set the language to ${GREEN}${locale_US}${RESET} and the format locale to ${GREEN}${locale_DK}${RESET}."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Setting language to $locale_US and formats to $locale_DK"
		locale_US_UTF="$locale_US.UTF-8"
		locale_DK_UTF="$locale_DK.UTF-8"

		sed -i "/#$locale_US_UTF/ s/^#//" /etc/locale.gen
		sed -i "/#$locale_DK_UTF/ s/^#//" /etc/locale.gen

		locale-gen

		cat > /etc/locale.conf <<-LOCALECONF
			LANG=$locale_US_UTF
			LC_MEASUREMENT=$locale_DK_UTF
			LC_MONETARY=$locale_US_UTF
			LC_NUMERIC=$locale_US_UTF
			LC_PAPER=$locale_DK_UTF
			LC_TIME=$locale_DK_UTF
		LOCALECONF

		export LANG=$locale_US_UTF
		export LC_MEASUREMENT=$locale_DK_UTF
		export LC_MONETARY=$locale_US_UTF
		export LC_NUMERIC=$locale_US_UTF
		export LC_PAPER=$locale_DK_UTF
		export LC_TIME=$locale_DK_UTF

		print_file_contents "/etc/locale.conf"

		MAINCHECKLIST[3]=1

		get_any_key
	fi
}

set_hostname()
{
	print_submenu_heading "CONFIGURE HOSTNAME"

	local user_confirm="n"
	local pc_name

	get_user_variable pc_name "hostname" "ProBook450"

	echo -e "Set the hostname to ${GREEN}${pc_name}${RESET}."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Setting hostname to $pc_name"
		echo $pc_name > /etc/hostname

		cat > /etc/hosts <<-HOSTSFILE
			127.0.0.1       localhost
			::1             localhost
			127.0.1.1       ${pc_name}.localdomain      ${pc_name}
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

	local user_confirm="n"

	echo -e "Enable the multilib repository in ${GREEN}/etc/pacman.conf${RESET}."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
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

	local user_confirm="n"

	echo -e "Set the password for the root user."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		passwd

		MAINCHECKLIST[6]=1

		get_any_key
	fi
}

add_sudouser()
{
	print_submenu_heading "ADD NEW USER WITH SUDO PRIVILEGES"

	local user_confirm="n"

	local new_user
	local user_desc

	get_user_variable new_user "user name" "drakkar"
	get_user_variable user_desc "user description" "draKKar"

	echo -e "Create new user ${GREEN}${new_user}${RESET} with sudo privileges."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Creating new user $new_user"
		useradd -m -G wheel -c $user_desc -s /bin/bash $new_user

		print_progress_text "Setting password for user $new_user"
		passwd $new_user

		print_progress_text "Enabling sudo privileges for user $new_user"
		bash -c 'echo "%wheel ALL=(ALL) ALL" | (EDITOR="tee -a" visudo)'

		print_progress_text "Verifying user $new_user identity"
		id $new_user

		MAINCHECKLIST[7]=1

		get_any_key
	fi
}

install_bootloader()
{
	print_submenu_heading "INSTALL BOOT LOADER"

	local user_confirm="n"

	echo -e "Install the grub bootloader."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Installing grub bootloader"
		pacman -S grub efibootmgr os-prober
		grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub

		print_progress_text "Installing microcode package"
		pacman -S intel-ucode

		print_progress_text "Generating grub.cfg file"
		grub-mkconfig -o /boot/grub/grub.cfg

		MAINCHECKLIST[8]=1

		get_any_key
	fi
}

install_xorg()
{
	print_submenu_heading "INSTALL XORG GRAPHICAL ENVIRONMENT"

	local user_confirm="n"

	echo -e "Install Xorg graphical environment."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
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

	local user_confirm="n"

	echo -e "Install Mesa OpenGL, Intel VA-API (hardware accel) and nVidia display drivers."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Installing display drivers"
		pacman -S mesa intel-media-driver nvidia

		MAINCHECKLIST[10]=1

		get_any_key
	fi
}

install_gnome()
{
	print_submenu_heading "INSTALL GNOME DESKTOP ENVIRONMENT"

	local user_confirm="n"

	get_user_variable gnome_ignore "GNOME packages to ignore" "epiphany,gnome-books,gnome-boxes,gnome-calendar,gnome-clocks,gnome-contacts,gnome-documents,gnome-maps,gnome-photos,gnome-software,orca"

	echo -e "Install the GNOME desktop environment."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Installing GNOME"
		echo -e "If prompted to select provider(s), select default options"
		echo ""

		if [[ "$gnome_ignore" != "" ]]; then
			pacman -S gnome --ignore $gnome_ignore
		else
			pacman -S gnome
		fi

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
	read -s -e -n 1 -p " => Select option or (q)uit: " main_choice
	echo ""

	case $main_choice in
		[aA])
			set_kbpermanent ;;
		[bB])
			set_timezone ;;
		[cC])
			sync_hwclock ;;
		[dD])
			set_locale ;;
		[eE])
			set_hostname ;;
		[fF])
			enable_multilib ;;
		[gG])
			root_password ;;
		[hH])
			add_sudouser ;;
		[iI])
			install_bootloader ;;
		[jJ])
			install_xorg ;;
		[kK])
			display_drivers ;;
		[lL])
			install_gnome ;;
		[qQ])
			clear
			echo -e "Exit the chroot environment:"
			echo ""
			echo -e "   ${GREEN}exit${RESET}"
			echo ""
			echo -e "Unmount partitions:"
			echo ""
			echo -e "   ${GREEN}umount -R /mnt/boot${RESET}"
			echo -e "   ${GREEN}umount -R /mnt/home${RESET}"
			echo -e "   ${GREEN}umount -R /mnt${RESET}"
			echo ""
			echo -e "Restart to boot into GNOME:"
			echo ""
			echo -e "   ${GREEN}reboot${RESET}"
			echo ""
			exit 0
			;;
	esac
}

while true
do
	main_menu
done
