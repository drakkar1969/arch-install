#!/bin/bash

#===========================================================================================================
# GLOBAL VARIABLES
#===========================================================================================================
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
	echo -e "${RED}WARNING:${RESET} $1"
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

	if [[ "${yn_choice,,}" == "y" ]]; then
		ret_val=0
	fi

	return $ret_val
}

get_user_variable()
{
	local var_name=$1
	local user_input

	read -e -p "Enter $2: " -i "$3" user_input
	echo ""

	declare -g "$var_name"=$user_input
}

#===========================================================================================================
# INSTALLATION FUNCTIONS
#===========================================================================================================
set_kbpermanent()
{
	print_submenu_heading "MAKE KEYBOARD LAYOUT PERMANENT"

	get_user_variable KB_CODE "keyboard layout" "it"

	echo -e "Make keyboard layout ${GREEN}${KB_CODE}${RESET} permanent."

	if get_user_confirm; then
		print_progress_text "Setting keyboard layout"
		echo KEYMAP=$KB_CODE > /etc/vconsole.conf

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

set_timezone()
{
	print_submenu_heading "CONFIGURE TIMEZONE"

	get_user_variable TIME_ZONE "timezone" "Europe/Sarajevo"

	echo -e "Set the timezone to ${GREEN}${TIME_ZONE}${RESET}."

	if get_user_confirm; then
		print_progress_text "Creating symlink for timezone"
		ln -sf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

sync_hwclock()
{
	print_submenu_heading "SYNC HARDWARE CLOCK"

	echo -e "Sync hardware clock."

	if get_user_confirm; then
		print_progress_text "Setting hardware clock to UTC"
		hwclock --systohc --utc

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

set_locale()
{
	print_submenu_heading "CONFIGURE LOCALE"

	get_user_variable LOCALE_US "language locale" "en_US"
	get_user_variable LOCALE_IE "format locale" "en_IE"

	echo -e "Set the language to ${GREEN}${LOCALE_US}${RESET} and the format locale to ${GREEN}${LOCALE_IE}${RESET}."

	if get_user_confirm; then
		print_progress_text "Setting language and format locales"
		local locale_US_utf="$LOCALE_US.UTF-8"
		local locale_IE_utf="$LOCALE_IE.UTF-8"

		sed -i "/#$locale_US_utf/ s/^#//" /etc/locale.gen
		sed -i "/#$locale_IE_utf/ s/^#//" /etc/locale.gen

		locale-gen

		cat > /etc/locale.conf <<-LOCALECONF
			LANG=$locale_US_utf
			LC_MEASUREMENT=$locale_IE_utf
			LC_PAPER=$locale_IE_utf
			LC_TIME=$locale_IE_utf
		LOCALECONF

		print_file_contents "/etc/locale.conf"

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

set_hostname()
{
	print_submenu_heading "CONFIGURE HOSTNAME"

	get_user_variable PC_NAME "hostname" "ProBook450"

	echo -e "Set the hostname to ${GREEN}${PC_NAME}${RESET}."

	if get_user_confirm; then
		print_progress_text "Setting hostname"
		echo $PC_NAME > /etc/hostname

		cat > /etc/hosts <<-HOSTSFILE
			127.0.0.1       localhost
			::1             localhost
			127.0.1.1       ${PC_NAME}.localdomain      ${PC_NAME}
		HOSTSFILE

		print_file_contents "/etc/hostname"
		print_file_contents "/etc/hosts"

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

enable_multilib()
{
	print_submenu_heading "ENABLE MULTILIB REPOSITORY"

	echo -e "Enable the multilib repository in ${GREEN}/etc/pacman.conf${RESET}."

	if get_user_confirm; then
		print_progress_text "Enabling multilib repository"
		sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf

		print_file_contents "/etc/pacman.conf"

		print_progress_text "Refreshing package databases"
		pacman -Syy

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

	get_user_variable NEW_USER "user name" "drakkar"
	get_user_variable USER_DESC "user description" "draKKar"

	echo -e "Create new user ${GREEN}${NEW_USER}${RESET} with sudo privileges."

	if get_user_confirm; then
		print_progress_text "Creating new user"
		useradd -m -G wheel -c $USER_DESC -s /bin/bash $NEW_USER

		print_progress_text "Setting password for user"
		passwd $NEW_USER

		print_progress_text "Enabling sudo privileges for user"
		bash -c 'echo "%wheel ALL=(ALL) ALL" | (EDITOR="tee -a" visudo -f /etc/sudoers.d/99_wheel)'

		print_progress_text "Verifying user identity"
		id $NEW_USER

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
		grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub

		print_progress_text "Installing microcode package"
		pacman -S intel-ucode

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
		print_progress_text "Installing Xorg with X widgets for testing"
		echo -e "If prompted to select provider(s), select default options"
		echo ""
 		pacman -S xorg-server xorg-xinit xorg-twm xterm

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

display_drivers()
{
	print_submenu_heading "INSTALL DISPLAY DRIVERS"

	echo -e "Install Mesa OpenGL, Intel VA-API (hardware accel) and Nouveau display drivers."

	if get_user_confirm; then
		print_progress_text "Installing display drivers"
		pacman -S --needed --asdeps mesa
		pacman -S intel-media-driver xf86-video-nouveau

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
		pacman -S --asdeps pipewire pipewire-media-session pipewire-pulse pipewire-alsa gst-plugin-pipewire

		POSTCHECKLIST[$1]=1

		get_any_key
	fi
}

install_gnome()
{
	print_submenu_heading "INSTALL GNOME DESKTOP ENVIRONMENT"

	get_user_variable GNOME_IGNORE "GNOME packages to ignore" "epiphany,gnome-books,gnome-boxes,gnome-calendar,gnome-clocks,gnome-contacts,gnome-documents,gnome-maps,gnome-photos,gnome-software,orca,totem"

	echo -e "Install the GNOME desktop environment."

	if get_user_confirm; then
		print_progress_text "Installing GNOME"
		echo -e "If prompted to select provider(s), select default options"
		echo ""

		if [[ "$GNOME_IGNORE" != "" ]]; then
			pacman -S gnome --ignore $GNOME_IGNORE
		else
			pacman -S gnome
		fi

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
				"Sync Hardware Clock|sync_hwclock"
				"Configure Locale|set_locale"
				"Configure Hostname|set_hostname"
				"Enable Multilib Repository|enable_multilib"
				"Configure Root Password|root_password"
				"Add New User with Sudo Privileges|add_sudouser"
				"Install Boot Loader|install_bootloader"
				"Install Xorg Graphical Environment|install_xorg"
				"Install Display Drivers|display_drivers"
				"Install PipeWire|install_pipewire"
				"Install GNOME Desktop Environment|install_gnome"
				"Install Multimedia Codecs|install_codecs")
	POSTCHECKLIST=()

	# Initialize status array with '0'
	local i

	for i in ${!POSTITEMS[@]}; do
		POSTCHECKLIST+=("0")
	done

	# Main menu loop
	while true; do
		clear

		# Print header
		echo -e "-------------------------------------------------------------------------------"
		echo -e "-- ${GREEN} ARCH LINUX ${RESET}::${GREEN} POST INSTALL MENU${RESET}"
		echo -e "-------------------------------------------------------------------------------"

		# Print menu items
		for i in ${!POSTITEMS[@]}; do
			# Get character from ascii code (0->A,etc.)
			local item_index=$(printf "\\$(printf '%03o' "$(($i+65))")")

			local item_text=$(echo "${POSTITEMS[$i]}" | cut -f1 -d'|')

			print_menu_item $item_index ${POSTCHECKLIST[$i]} "$item_text"
		done

		# Print footer
		echo ""
		echo -e "-------------------------------------------------------------------------------"
		echo ""
		echo -e -n " => Select option or (q)uit: "

		# Get menu selection
		local post_index=-1

		until (( $post_index >= 0 && $post_index < ${#POSTITEMS[@]} ))
		do
			local post_choice

			read -r -s -n 1 post_choice

			# Exit main menu
			if [[ "${post_choice,,}" == "q" ]]; then
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
			fi

			# Get selection index
			if [[ "$post_choice" == [a-zA-Z] ]]; then
				# Get ascii code from character (A->65, etc.)
				post_index=$(LC_CTYPE=C printf '%d' "'${post_choice^^}")
				post_index=$(($post_index-65))
			fi
		done

		# Execute function
		local item_func=$(echo "${POSTITEMS[$post_index]}" | cut -f2 -d'|')

		eval ${item_func} $post_index
	done
}

post_menu
