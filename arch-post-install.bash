#!/bin/bash

#===========================================================================================================
# GLOBAL VARIABLES
#===========================================================================================================
YELLOW='\033[1;33m'
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

	[[ $status -eq 0 ]] && checkmark="  "

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
	echo -e "${YELLOW}WARNING:${RESET} $1"
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

get_user_confirm()
{
	local ret_val=1
	local yn_choice="n"

	echo ""
	read -s -e -n 1 -p "Are you sure you want to continue [y/N]: " yn_choice

	[[ "${yn_choice,,}" == "y" ]] && ret_val=0

	return $ret_val
}

#===========================================================================================================
# INSTALLATION FUNCTIONS
#===========================================================================================================
set_kbpermanent()
{
	print_submenu_heading "MAKE KEYBOARD LAYOUT PERMANENT"

	local kb_code

	read -e -p "Enter keyboard layout: " -i "it" kb_code
	echo ""

	echo -e "Make keyboard layout ${GREEN}${kb_code}${RESET} permanent."

	if get_user_confirm; then
		print_progress_text "Setting keyboard layout"
		echo KEYMAP=$kb_code > /etc/vconsole.conf

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

set_timezone()
{
	print_submenu_heading "CONFIGURE TIMEZONE"

	local time_zone

	read -e -p "Enter timezone: " -i "Europe/Rome" time_zone
	echo ""

	echo -e "Set the timezone to ${GREEN}${time_zone}${RESET}."

	if get_user_confirm; then
		print_progress_text "Creating symlink for timezone"
		ln -sf /usr/share/zoneinfo/$time_zone /etc/localtime

		print_progress_text "Setting hardware clock to UTC"
		hwclock --systohc --utc

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

set_locale()
{
	print_submenu_heading "CONFIGURE LOCALE"

	local locale_US
	local locale_IE

	read -e -p "Enter language locale: " -i "en_US" locale_US
	echo ""
	read -e -p "Enter format locale: " -i "en_IE" locale_IE
	echo ""

	echo -e "Set the language to ${GREEN}${locale_US}${RESET} and the format locale to ${GREEN}${locale_IE}${RESET}."

	if get_user_confirm; then
		print_progress_text "Setting language and format locales"
		locale_US="$locale_US.UTF-8"
		locale_IE="$locale_IE.UTF-8"

		sed -i "/#$locale_US/ s/^#//" /etc/locale.gen
		sed -i "/#$locale_IE/ s/^#//" /etc/locale.gen

		locale-gen

		cat > /etc/locale.conf <<-LOCALECONF
			LANG=$locale_US
			LC_MEASUREMENT=$locale_IE
			LC_PAPER=$locale_IE
			LC_TIME=$locale_IE
		LOCALECONF

		print_file_contents "/etc/locale.conf"

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

set_hostname()
{
	print_submenu_heading "CONFIGURE HOSTNAME"

	local pc_name

	read -e -p "Enter hostname: " -i "SamsungBook2" pc_name
	echo ""

	echo -e "Set the hostname to ${GREEN}${pc_name}${RESET}."

	if get_user_confirm; then
		print_progress_text "Setting hostname"
		echo $pc_name > /etc/hostname

		cat > /etc/hosts <<-HOSTSFILE
			127.0.0.1       localhost
			::1             localhost
			127.0.1.1       ${pc_name}.localdomain      ${pc_name}
		HOSTSFILE

		print_file_contents "/etc/hostname"
		print_file_contents "/etc/hosts"

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

config_pacman()
{
	print_submenu_heading "CONFIGURE PACMAN"

	echo -e "Enable color output and parallel downloads in ${GREEN}/etc/pacman.conf${RESET}."

	if get_user_confirm; then
		print_progress_text "Configuring pacman"
		sed -i -f - /etc/pacman.conf <<-PACMAN_CONF
			s/#Color/Color/
			s/#ParallelDownloads/ParallelDownloads/
		PACMAN_CONF

		print_file_contents "/etc/pacman.conf"

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

root_password()
{
	print_submenu_heading "CONFIGURE ROOT PASSWORD"

	echo -e "Set the password for the root user."

	if get_user_confirm; then
		passwd

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

add_sudouser()
{
	print_submenu_heading "ADD NEW USER WITH SUDO PRIVILEGES"

	local new_user
	local user_desc

	read -e -p "Enter user name: " -i "drakkar" new_user
	echo ""
	read -e -p "Enter user description: " -i "draKKar" user_desc
	echo ""

	echo -e "Create new user ${GREEN}${new_user}${RESET} with sudo privileges."

	if get_user_confirm; then
		print_progress_text "Creating new user"
		useradd -m -G wheel -c $user_desc -s /bin/bash $new_user

		print_progress_text "Setting password for user"
		passwd $new_user

		print_progress_text "Enabling sudo privileges for user"
		bash -c 'echo "%wheel ALL=(ALL) ALL" | (EDITOR="tee -a" visudo -f /etc/sudoers.d/99_wheel)'

		print_progress_text "Verifying user identity"
		id $new_user

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

install_bootloader()
{
	print_submenu_heading "INSTALL BOOT LOADER"

	echo -e "Install the GRUB bootloader."

	if get_user_confirm; then
		print_progress_text "Installing GRUB bootloader"
		pacman -S grub efibootmgr os-prober
		grub-install --target=x86_64-efi --efi-directory=/boot --removable

		print_progress_text "Installing microcode package"
		pacman -S intel-ucode

		print_progress_text "Enabling OS Prober"
		sed -i '/^#GRUB_DISABLE_OS_PROBER/ c GRUB_DISABLE_OS_PROBER=false' /etc/default/grub

		print_progress_text "Fixing Suspend Issue"
		local kernel_params=$(cat /etc/default/grub | grep 'GRUB_CMDLINE_LINUX_DEFAULT=' | cut -f2 -d'"')

		local suspend_param="button.lid_init_state=open"

		if [[ $kernel_params != *"$suspend_param"* ]]; then kernel_params+=" $suspend_param"; fi

		cp -n /etc/default/grub{,.orig}

		sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/ c GRUB_CMDLINE_LINUX_DEFAULT=\"$kernel_params\"" /etc/default/grub

		print_progress_text "Generating GRUB config file"
		grub-mkconfig -o /boot/grub/grub.cfg

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

install_xorg()
{
	print_submenu_heading "INSTALL XORG GRAPHICAL ENVIRONMENT"

	echo -e "Install Xorg graphical environment."

	if get_user_confirm; then
		print_progress_text "Installing Xorg"
		echo -e "If prompted to select provider(s), select default options"
		echo ""
 		pacman -S --asdeps xorg-server

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

display_drivers()
{
	print_submenu_heading "INSTALL DISPLAY DRIVERS"

	echo -e "Install Mesa OpenGL and Intel VA-API (hardware accel) drivers."

	if get_user_confirm; then
		print_progress_text "Installing Intel display drivers"
		pacman -S --needed --asdeps mesa
		pacman -S intel-media-driver libva-utils

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

install_pipewire()
{
	print_submenu_heading "INSTALL PIPEWIRE"

	echo -e "Install the PipeWire multimedia framework."

	if get_user_confirm; then
		print_progress_text "Installing PipeWire"
		pacman -S --asdeps pipewire pipewire-pulse pipewire-alsa wireplumber gst-plugin-pipewire rtkit

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

install_gnome()
{
	print_submenu_heading "INSTALL GNOME DESKTOP ENVIRONMENT"

	local gnome_ignore

	read -e -p "Enter GNOME packages to ignore: " -i "cheese,epiphany,gnome-calendar,gnome-characters,gnome-clocks,gnome-contacts,gnome-logs,gnome-maps,gnome-music,gnome-photos,gnome-software,gnome-tour,orca,rygel,totem" gnome_ignore
	echo ""

	echo -e "Install the GNOME desktop environment."

	if get_user_confirm; then
		print_progress_text "Installing Network Manager"
		pacman -S networkmanager

		print_progress_text "Installing GNOME"

		# Get array of packages to ignore from string
		local ignore_pkgs=()
		IFS=',' read -r -a ignore_pkgs <<< "$gnome_ignore"

		# Get array with full list of GNOME packages
		local gnome_pkgs=()
		IFS=$'\n' read -d "" -r -a gnome_pkgs < <(pacman -Sgq gnome)

		# Remove packages to ignore from array
		for pkg in "${ignore_pkgs[@]}"; do
			gnome_pkgs=(${gnome_pkgs[@]//$pkg})
		done
		unset pkg

		# Install remaining GNOME packages
		echo -e "If prompted to select provider(s), select default options"
		echo ""

		pacman -S "${gnome_pkgs[@]}"

		# Install optional GNOME control center dependencies
		print_progress_text "Installing Optional Power Profiles"
		pacman -S --asdeps power-profiles-daemon

		print_progress_text "Installing Optional Firmware Support"
		pacman -S --asdeps fwupd

		print_progress_text "Installing Optional Print Configuration"
		pacman -S --asdeps system-config-printer

		# Install GNOME extras
		print_progress_text "Installing GNOME Extras"
		pacman -S gnome-tweaks file-roller dconf-editor

		print_progress_text "Enabling GDM service"
		systemctl enable gdm.service

		print_progress_text "Enabling Network Manager service"
		systemctl enable NetworkManager.service

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

install_codecs()
{
	print_submenu_heading "INSTALL MULTIMEDIA CODECS"

	echo -e "Install multimedia codecs."

	if get_user_confirm; then
		print_progress_text "Installing codecs"
		pacman -S --needed libmad gstreamer gst-libav gst-plugins-base gst-plugins-bad gst-plugins-good gst-plugins-ugly gstreamer-vaapi

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

post_menu()
{
	POSTITEMS=("Make Keyboard Layout Permanent|set_kbpermanent"
				"Configure Timezone|set_timezone"
				"Configure Locale|set_locale"
				"Configure Hostname|set_hostname"
				"Configure pacman|config_pacman"
				"Configure Root Password|root_password"
				"Add New User with Sudo Privileges|add_sudouser"
				"Install Boot Loader|install_bootloader"
				"Install Xorg Graphical Environment|install_xorg"
				"Install Display Drivers|display_drivers"
				"Install PipeWire|install_pipewire"
				"Install GNOME Desktop Environment|install_gnome"
				"Install Multimedia Codecs|install_codecs")
	POSTCHECKLIST=("${POSTITEMS[@]/*/0}")

	# Post install menu loop
	while true; do
		clear

		# Print header
		echo -e "-------------------------------------------------------------------------------"
		echo -e "-- ${GREEN} ARCH LINUX ${RESET}::${GREEN} INSTALL MENU ${RESET}>>${GREEN} POST INSTALL${RESET}"
		echo -e "-------------------------------------------------------------------------------"

		# Print menu items
		for i in ${!POSTITEMS[@]}; do
			# Get character from ascii code (0->A,etc.)
			local item_index=$(printf "\\$(printf '%03o' "$(($i+65))")")

			local item_text=$(echo "${POSTITEMS[$i]}" | cut -f1 -d'|')

			print_menu_item $item_index ${POSTCHECKLIST[$i]} "$item_text"
		done
		unset i

		# Print footer
		echo ""
		echo -e "-------------------------------------------------------------------------------"
		echo ""
		echo -e -n " => Select option or (r)eturn to main menu: "

		# Get menu selection
		local post_index=-1

		until (( $post_index >= 0 && $post_index < ${#POSTITEMS[@]} ))
		do
			local post_choice

			read -r -s -n 1 post_choice

			# Return to main menu
			if [[ "${post_choice,,}" == "r" ]]; then
				clear
				exit 0
			fi

			# Capture and exclude arrow keys
			if [[ "$post_choice" == "$(printf '\u1b')" ]]; then
				read -r -s -n 2 temp
				unset temp
			fi

			# Get selection index
			if [[ "${post_choice^^}" =~ ^[[:upper:]]+$ ]]; then
				# Get ascii code from character (A->65, etc.)
				post_index=$(printf '%d' "'${post_choice^^}")
				post_index=$(($post_index-65))
			fi
		done

		# Execute function
		local item_func=$(echo "${POSTITEMS[$post_index]}" | cut -f2 -d'|')

		${item_func} $post_index
	done
}

post_menu
