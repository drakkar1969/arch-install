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
	echo -e "${GREEN}==>${RESET} $1"
	echo ""
}

print_warning()
{
	echo -e "${RED}Warning:${RESET} $1"
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
	echo ""

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
enable_wifi()
{
	print_submenu_heading "ENABLE WIFI CONNECTION"

	local user_confirm="n"

	local wifi_ssid
	local wifi_passwd

	get_user_variable wifi_ssid "wireless network name" ""
	get_user_variable wifi_passwd "wireless password" ""

	echo -e "Connect to wifi network ${GREEN}${wifi_ssid}${RESET}."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" = "y" ]]; then
		print_progress_text "Connecting to wifi network"
		nmcli device wifi connect "$wifi_ssid" password "$wifi_passwd"

		print_progress_text "Checking network connection"
		ping -c 3 www.google.com

		MAINCHECKLIST[0]=1

		get_any_key
	fi

}

install_xorg()
{
	print_submenu_heading "INSTALL XORG GRAPHICAL ENVIRONMENT"

	local user_confirm="n"

	echo -e "Install Xorg graphical environment."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" = "y" ]]; then
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

	local user_confirm="n"

	echo -e "Install display drivers."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" = "y" ]]; then
		print_progress_text "Installing nVidia video drivers"
		echo -e "If prompted to select provider(s), select default options"
		echo ""
		sudo pacman -S nvidia lib32-virtualgl lib32-nvidia-utils

		print_progress_text "Installing Intel VA-API (hardware acccel) drivers"
		sudo pacman -S intel-media-driver

		MAINCHECKLIST[2]=1

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

	if [[ "$user_confirm" = "y" ]]; then
		print_progress_text "Installing GNOME"
		echo -e "If prompted to select provider(s), select default options"
		echo ""

		if [[ "$gnome_ignore" != "" ]]; then
			sudo pacman -S gnome --ignore $gnome_ignore
		else
			sudo pacman -S gnome
		fi

		print_progress_text "Enabling GDM service"
		sudo systemctl enable gdm.service

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
	read -s -e -n 1 -p " => Select option or (q)uit: " main_choice
	echo ""

	case $main_choice in
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
