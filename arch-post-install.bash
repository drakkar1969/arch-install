#!/bin/bash

#=======================================================================================
# GLOBAL VARIABLES
#=======================================================================================
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RESET='\033[0m'
BOLD='\033[1;37m'

#=======================================================================================
# HELPER FUNCTIONS
#=======================================================================================
echo_line()
{
	echo "---------------------------------------------------------------------------"
}

echo_header()
{
	echo_line
	echo -e "--  ${GREEN}ARCH LINUX POST-INSTALLATION${RESET}"
	echo_line
	echo
}

echo_keymap_start()
{
	echo
	echo_line

	if [[ $1 == true ]]; then
		echo -e "--  ${YELLOW}X${RESET} Execute    ${YELLOW}M${RESET} Main Menu"
	else
		echo -e "--  ${YELLOW}X${RESET} Execute    ${YELLOW}S${RESET} Skip    ${YELLOW}M${RESET} Main Menu"
	fi

	echo_line
	echo
}

echo_keymap_end()
{
	echo
	echo_line

	if [[ $1 == true ]]; then
		echo -e "--  ${YELLOW}R${RESET} Repeat    ${YELLOW}M${RESET} Main Menu"
	else
		echo -e "--  ${YELLOW}R${RESET} Repeat    ${YELLOW}N${RESET} Next    ${YELLOW}M${RESET} Main Menu"
	fi

	echo_line
}

echo_progress_heading()
{
	echo
	echo_line
	echo -e "-- ${GREEN}$1${RESET}"
	echo_line
	echo
}

echo_file_contents()
{
	cat "$1"
}

get_user_confirm()
{
	local ret_val=1
	local yn_choice="n"

	echo -e "${BOLD}"
	read -s -e -n 1 -p "Are you sure you want to continue [y/N]: " yn_choice
	echo -e -n "${RESET}"

	[[ "${yn_choice,,}" == "y" ]] && ret_val=0

	return $ret_val
}

#=======================================================================================
# INSTALLATION FUNCTIONS
#=======================================================================================
set_consolepermanent()
{
	local kb_code
	local console_font

	read -e -p "Enter keyboard layout: " -i "it" kb_code
	echo

	read -e -p "Enter console font: " -i "ter-128b" console_font
	echo

	echo -e "Make keyboard layout ${GREEN}${kb_code}${RESET} permanent."
	echo -e "Make console font ${GREEN}${console_font}${RESET} permanent."

	if get_user_confirm; then
		echo_progress_heading "Saving console settings"

		cat > /etc/vconsole.conf <<-VCONSOLE_CONF
			KEYMAP=$kb_code
			FONT=$console_font
		VCONSOLE_CONF
	fi
}

set_timezone()
{
	local time_zone

	read -e -p "Enter timezone: " -i "Europe/Rome" time_zone
	echo

	echo -e "Set the timezone to ${GREEN}${time_zone}${RESET}."

	if get_user_confirm; then
		echo_progress_heading "Creating symlink for timezone"
		ln -sf /usr/share/zoneinfo/$time_zone /etc/localtime

		echo_progress_heading "Setting hardware clock to UTC"
		hwclock --systohc --utc
	fi
}

set_locale()
{
	local locale_US
	local locale_IE

	read -e -p "Enter language locale: " -i "en_US" locale_US
	echo
	read -e -p "Enter format locale: " -i "en_IE" locale_IE
	echo

	echo -e "Set the language to ${GREEN}${locale_US}${RESET} and the format locale to ${GREEN}${locale_IE}${RESET}."

	if get_user_confirm; then
		echo_progress_heading "Setting language and format locales"
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

		echo_progress_heading "Verifying file: /etc/locale.conf"
		echo_file_contents "/etc/locale.conf"
	fi
}

set_hostname()
{
	local pc_name

	read -e -p "Enter hostname: " -i "LG-GRAM" pc_name
	echo

	echo -e "Set the hostname to ${GREEN}${pc_name}${RESET}."

	if get_user_confirm; then
		echo_progress_heading "Setting hostname"
		echo $pc_name > /etc/hostname

		echo_progress_heading "Verifying file: /etc/hostname"
		echo_file_contents "/etc/hostname"
	fi
}

config_pacman()
{
	echo -e "Enable color output and parallel downloads in ${GREEN}/etc/pacman.conf${RESET}."
	echo -e "Enable parallel compilation and disable debug packages in ${GREEN}/etc/makepkg.conf${RESET}."

	if get_user_confirm; then
		echo_progress_heading "Configuring pacman"
		sed -i -f - /etc/pacman.conf <<-PACMAN_CONF
			s/#Color/Color/
			s/#ParallelDownloads/ParallelDownloads/
		PACMAN_CONF

		echo_progress_heading "Configuring makepkg"
		sed -i -f - /etc/makepkg.conf <<-MAKEPKG_CONF
			/^#MAKEFLAGS=/ c MAKEFLAGS="-j$(nproc)"
			/^OPTIONS=/ s/ debug/ !debug/
		MAKEPKG_CONF
	fi
}

root_password()
{
	echo "Set the password for the root user."

	if get_user_confirm; then
		echo_progress_heading "Setting password for root user"
		passwd
	fi
}

add_sudouser()
{
	local new_user
	local user_desc

	read -e -p "Enter user name: " -i "drakkar" new_user
	echo
	read -e -p "Enter user description: " -i "draKKar" user_desc
	echo

	echo -e "Create new user ${GREEN}${new_user}${RESET} with sudo privileges."

	if get_user_confirm; then
		echo_progress_heading "Creating new user"
		useradd -m -G wheel -c $user_desc -s /bin/bash $new_user

		echo_progress_heading "Setting password for user"
		passwd $new_user

		echo_progress_heading "Enabling sudo privileges for user"
		bash -c 'echo "%wheel ALL=(ALL) ALL" | (EDITOR="tee -a" visudo -f /etc/sudoers.d/99_wheel)'

		echo_progress_heading "Verifying user identity"
		id $new_user
	fi
}

install_bootloader()
{
	echo "Install the GRUB bootloader."

	if get_user_confirm; then
		# Install GRUB
		echo_progress_heading "Installing GRUB bootloader"
		pacman -S grub efibootmgr
		pacman -S --asdeps dosfstools
		grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB

		# Install OS prober
		echo_progress_heading "Installing OS prober"

		pacman -S --asdeps os-prober

		sed -i '/^#GRUB_DISABLE_OS_PROBER/ c GRUB_DISABLE_OS_PROBER=false' /etc/default/grub

		# Disable watchdogs
		echo_progress_heading "Disabling Watchdogs"
		local kernel_params=$(cat /etc/default/grub | grep 'GRUB_CMDLINE_LINUX_DEFAULT=' | cut -f2 -d'"')

		local watchdog_param="modprobe.blacklist=iTCO_wdt"

		if [[ $kernel_params != *"$watchdog_param"* ]]; then kernel_params+=" $watchdog_param"; fi

		sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/ c GRUB_CMDLINE_LINUX_DEFAULT=\"$kernel_params\"" /etc/default/grub

		# Add LG recovery GRUB entry
		echo_progress_heading "Adding LG recovery GRUB entry"
		if ! grep -i -q "recovery" /etc/grub.d/40_custom; then
			cat >> /etc/grub.d/40_custom <<-RECOVERY_GRUB
				menuentry 'LG Recovery' --class recovery {
				    search --fs-uuid --no-floppy --set=root B862-AEA4
				    chainloader (${root})/EFI/LG/Boot/bootmgfw.efi
				}
			RECOVERY_GRUB
		fi

		# Add shutdown/restart GRUB entries
		echo_progress_heading "Adding shutdown and restart GRUB entries"
		if ! grep -i -q "shutdown" /etc/grub.d/40_custom; then
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
		fi

		# Generate GRUB config file
		echo_progress_heading "Generating GRUB config file"
		grub-mkconfig -o /boot/grub/grub.cfg
	fi
}

display_drivers()
{
	echo "Install Mesa OpenGL, Intel VA-API (hardware accel) and Vulkan drivers."

	if get_user_confirm; then
		echo_progress_heading "Installing Intel display driver"
		pacman -S --needed --asdeps mesa

		echo_progress_heading "Installing Intel hardware acceleration driver"
		pacman -S intel-media-driver libva-utils
	fi
}

install_pipewire()
{
	echo "Install the PipeWire multimedia framework."

	if get_user_confirm; then
		echo_progress_heading "Installing PipeWire"
		pacman -S --asdeps pipewire pipewire-pulse pipewire-jack wireplumber gst-plugin-pipewire
	fi
}

install_gnome()
{
	local gnome_ignore

	read -e -p "Enter GNOME packages to ignore: " -i "decibels,epiphany,gnome-calendar,gnome-characters,gnome-clocks,gnome-connections,gnome-contacts,gnome-logs,gnome-maps,gnome-music,gnome-software,gnome-tour,orca" gnome_ignore
	echo

	echo "Install the GNOME desktop environment."

	if get_user_confirm; then
		echo_progress_heading "Installing Network Manager"
		pacman -S networkmanager

		echo_progress_heading "Installing GNOME"

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
		echo "If prompted to select provider(s), select default options"
		echo

		pacman -S "${gnome_pkgs[@]}"

		# Install optional power profiles daemon
		echo_progress_heading "Installing Optional Power Profiles Daemon"
		pacman -S power-profiles-daemon

		echo_progress_heading "Enabling GDM service"
		systemctl enable gdm.service

		echo_progress_heading "Enabling Network Manager service"
		systemctl enable NetworkManager.service
	fi
}

enable_bluetooth()
{
	echo "Install and enable Bluetooth."

	if get_user_confirm; then
		echo_progress_heading "Installing Bluetooth packages"
		pacman -S --needed bluez bluez-utils

		echo_progress_heading "Enabling power status reporting"
		mkdir -p /etc/systemd/system/bluetooth.service.d

		cat > /etc/systemd/system/bluetooth.service.d/10-experimental.conf <<-BLUETOOTH_POWER
			[Service]
			ExecStart=
			ExecStart=/usr/lib/bluetooth/bluetoothd -E
		BLUETOOTH_POWER

		echo_progress_heading "Enabling Bluetooth service"
		systemctl enable bluetooth.service
	fi
}

install_codecs()
{
	echo "Install multimedia codecs."

	if get_user_confirm; then
		echo_progress_heading "Installing codecs"
		pacman -S --needed libmad gstreamer gst-libav gst-plugins-base gst-plugins-bad gst-plugins-good gst-plugins-ugly gst-plugin-va
	fi
}

#=======================================================================================
# MAIN FUNCTION
#=======================================================================================
main()
{
	MENU_ITEMS=("Make Console Settings Permanent|set_consolepermanent"
				"Configure Timezone|set_timezone"
				"Configure Locale|set_locale"
				"Configure Hostname|set_hostname"
				"Configure pacman|config_pacman"
				"Configure Root Password|root_password"
				"Add New User with Sudo Privileges|add_sudouser"
				"Install Boot Loader|install_bootloader"
				"Install Display Drivers|display_drivers"
				"Install PipeWire|install_pipewire"
				"Install GNOME Desktop Environment|install_gnome"
				"Enable Bluetooth|enable_bluetooth"
				"Install Multimedia Codecs|install_codecs")

	local menu_index=1
	local quit=0

	while (( $quit == 0 )); do
		clear
		echo_header

		local item_name=$(echo ${MENU_ITEMS[$menu_index-1]} | cut -f1 -d'|')

		echo -e "  ${BOLD}STEP ${menu_index} / ${#MENU_ITEMS[@]}: ${item_name}${RESET}"

		if (( $menu_index <= $((${#MENU_ITEMS[@]}-1)) )); then
			echo_keymap_start false
		else
			echo_keymap_start true
		fi

		while true; do
			local start_choice

			read -r -s -n 1 start_choice

			# Return to main menu
			if [[ "${start_choice,,}" == "m" ]]; then
				quit=1
				break
			fi

			# Skip and go to next step
			if [[ "${start_choice,,}" == "s" ]]; then
				if (( $menu_index <= $((${#MENU_ITEMS[@]}-1)) )); then
					menu_index=$(($menu_index+1))
					break
				fi
			fi

			# Execute current step
			if [[ "${start_choice,,}" == "x" ]]; then
				local item_func=$(echo ${MENU_ITEMS[$menu_index-1]} | cut -f2 -d'|')

				${item_func}

				if (( $menu_index <= $((${#MENU_ITEMS[@]}-1)) )); then
					echo_keymap_end false
				else
					echo_keymap_end true
				fi

				while true; do
					local end_choice

					read -r -s -n 1 end_choice

					# Return to main menu
					if [[ "${end_choice,,}" == "m" ]]; then
						quit=1
						break
					fi

					# Repeat step
					if [[ "${end_choice,,}" == "r" ]]; then
						break
					fi

					# Go to next step
					if [[ "${end_choice,,}" == "n" ]]; then
						if (( $menu_index <= $((${#MENU_ITEMS[@]}-1)) )); then
							menu_index=$(($menu_index+1))
							break
						fi
					fi
				done

				break
			fi
		done
	done
}

main
