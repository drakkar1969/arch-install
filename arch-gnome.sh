#!/bin/bash

#===========================================================================================================
# GLOBAL VARIABLES
#===========================================================================================================
MAINCHECKLIST=(0 0 0 0)
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

	read -s -e -n 1 -p "Are you sure you want to continue [y/N]: " _YNCHOICE
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
enable_wifi()
{
	print_submenu_heading "ENABLE WIFI CONNECTION"

	local _USERCONFIRM="n"

	get_user_variable WIFISSID "wireless network name" ""
	get_user_variable WIFIPASSWD "wireless password" ""

	echo -e "Connect to wifi network ${GREEN}${WIFISSID}${RESET}."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Connecting to wifi network"
		nmcli device wifi connect "$WIFISSID" password "$WIFIPASSWD"

		print_progress_text "Checking network connection"
		ping -c 3 www.google.com

		MAINCHECKLIST[0]=1

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
 		sudo pacman -S xorg-server

		print_progress_text "Installing X widgets for testing"
		sudo pacman -S xorg-xinit xorg-twm xterm

		MAINCHECKLIST[1]=1

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
		sudo pacman -S nvidia lib32-virtualgl lib32-nvidia-utils

		MAINCHECKLIST[2]=1

		get_any_key
	fi
}

install_gnome()
{
	print_submenu_heading "INSTALL GNOME DESKTOP ENVIRONMENT"

	local _USERCONFIRM="n"

	get_user_variable GNOMEIGNORE "GNOME packages to ignore" "epiphany,gnome-books,gnome-boxes,gnome-calendar,gnome-clocks,gnome-contacts,gnome-dictionary,gnome-documents,gnome-maps,gnome-photos,gnome-software,orca"

	get_user_variable GNOMEADDITIONAL "additional GNOME packages to install" "dconf-editor,ghex,gnome-tweaks"
	GNOMEADDITIONAL=${GNOMEADDITIONAL//,/ }

	echo -e "Install the GNOME desktop environment."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Installing GNOME"
		echo -e "If prompted to select provider(s), select default options"
		echo ""

		if [[ "$GNOMEIGNORE" != "" ]]; then
			sudo pacman -S gnome --ignore $GNOMEIGNORE
		else
			sudo pacman -S gnome
		fi

		if [[ "$GNOMEADDITIONAL" != "" ]]; then
			print_progress_text "Installing additional GNOME packages"
			sudo pacman -S $GNOMEADDITIONAL
		fi

		print_progress_text "Enabling GDM service"
		systemctl enable gdm.service

		MAINCHECKLIST[3]=1

		get_any_key
	fi
}

main_menu()
{
	clear

	echo -e "-------------------------------------------------------------------------------"
	echo -e "-- ${GREEN} ARCH LINUX ${RESET}::${GREEN} MAIN MENU${RESET}"
	echo -e "-------------------------------------------------------------------------------"

	print_menu_item A ${MAINCHECKLIST[0]} 'Enable wifi connection'
	print_menu_item B ${MAINCHECKLIST[1]} 'Install Xorg graphical environment'
	print_menu_item C ${MAINCHECKLIST[2]} 'Install display drivers'
	print_menu_item D ${MAINCHECKLIST[3]} 'Install GNOME desktop environment'

	echo ""
	echo -e "-------------------------------------------------------------------------------"
	echo ""
	read -s -e -n 1 -p " => Select option or (q)uit: " _MAINCHOICE
	echo ""

	case $_MAINCHOICE in
		[aA])
			enable_wifi
			;;
		[bB])
			install_xorg
			;;
		[cC])
			display_drivers
			;;
		[dD])
			install_gnome
			;;
		[qQ])
			clear
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
