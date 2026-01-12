#!/bin/bash

#=======================================================================================
# GLOBAL VARIABLES
#=======================================================================================
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RESET='\033[0m'
BOLD='\033[1;37m'

declare -A PART_IDS=([ESP]="" [root]="" [home]="" [swap]="")

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
	echo -e "--  ${GREEN}ARCH LINUX INSTALLATION${RESET}"
	echo_line
	echo
}

echo_keymap_start()
{
	echo
	echo_line

	if [[ $1 == true ]]; then
		echo -e "--  ${YELLOW}X${RESET} Execute    ${YELLOW}Q${RESET} Quit"
	else
		echo -e "--  ${YELLOW}X${RESET} Execute    ${YELLOW}S${RESET} Skip    ${YELLOW}Q${RESET} Quit"
	fi

	echo_line
}

echo_keymap_end()
{
	echo
	echo_line

	if [[ $1 == true ]]; then
		echo -e "--  ${YELLOW}R${RESET} Repeat    ${YELLOW}Q${RESET} Quit"
	else
		echo -e "--  ${YELLOW}R${RESET} Repeat    ${YELLOW}N${RESET} Next    ${YELLOW}Q${RESET} Quit"
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

echo_warning()
{
	echo -e "${YELLOW}WARNING:${RESET} $1"
}

echo_file_contents()
{
	cat "$1"
}

echo_partition_menu()
{
	part_names="$1"

	echo

	for i in "${!part_names[@]}"; do
		local part_index=$(printf "\\$(printf '%03o' "$(($i+97))")")
		local part_type=$(lsblk --output PARTLABEL --noheadings ${part_names[$i]})
		local part_size=$(lsblk --output SIZE --raw --noheadings ${part_names[$i]})

		printf "  [%s] %s [type: %b; size: %b]\n" $part_index "${part_names[$i]}" "${GREEN}$part_type${RESET}" "${GREEN}$part_size${RESET}"
	done
	unset i
}

echo_partition_structure()
{
	lsblk --paths --output NAME,SIZE,PARTLABEL,FSTYPE,MOUNTPOINTS
}

get_partition_type()
{
	local part_id=$1

	local part_size=$(lsblk --output SIZE --paths --raw --noheadings $part_id)
	local part_type=$(lsblk --output PARTLABEL --paths --noheadings $part_id)

	[[ -z $part_type ]] && part_type="unknown"

	echo -e "${GREEN}$part_id${RESET} [type: ${GREEN}$part_type${RESET}; size: ${GREEN}$part_size${RESET}]"
}

get_partition_info()
{
	local part_id=$1

	local part_size=$(lsblk --output SIZE --paths --raw --noheadings $part_id)
	local part_fs=$(lsblk --output FSTYPE --paths --raw --noheadings $part_id)

	[[ -z $part_fs ]] && part_fs="unknown"

	echo -e "${GREEN}$part_id${RESET} [type: ${GREEN}$part_fs${RESET}; size: ${GREEN}$part_size${RESET}]"
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
check_uefimode()
{
	echo_progress_heading "Verifying UEFI boot mode"

	local uefi=$(cat /sys/firmware/efi/fw_platform_size)

	if [[ "$uefi" == "64" ]]; then
		echo "OK: UEFI Boot Mode (64-bit)"
	else
		echo "ERROR: Unsupported Boot Mode"
	fi
}

system_clock()
{
	echo
	echo "Enable clock synchronization over network."

	if get_user_confirm; then
		echo_progress_heading "Enabling clock synchronization over network"
		timedatectl set-ntp true

		echo_progress_heading "Checking time and date status"
		timedatectl
	fi
}

create_partitions()
{
	echo
	echo "Select disk to partition:"

	# Get disk names
	local disk_names=()

	readarray -t disk_names < <(lsblk --list --noheadings --paths --output NAME,TYPE | grep -i "disk")

	disk_names=(${disk_names[@]/ disk/})

	# Display disk menu
	echo

	for i in "${!disk_names[@]}"; do
		local disk_size=$(lsblk --output SIZE --raw --noheadings --nodeps ${disk_names[$i]})

		printf "  [%d] %s [size: %b]\n" $(($i+1)) "${disk_names[$i]}" "${GREEN}$disk_size${RESET}"
	done
	unset i

	echo
	echo -n "=> Enter selection: "

	# Get menu selection
	local disk_index=-1

	until (( $disk_index >= 0 && $disk_index < ${#disk_names[@]} ))
	do
		local opt

		read -r -s -n 1 opt

		if [[ "$opt" =~ ^[[:digit:]]+$ ]]; then
			disk_index=$(($opt-1))
		fi
	done

	echo -e "\n\nDisk ${GREEN}${disk_names[$disk_index]}${RESET} will be partitioned."

	echo

	echo_warning "This will erase all data on the disk, make sure you have backed up data before proceeding"

	if get_user_confirm; then
		echo_progress_heading "Partitioning disk"

		gdisk ${disk_names[$disk_index]}
	fi
}

format_partitions()
{
	echo
	echo "Available partitions:"

	# Get partition names
	local part_names=()

	readarray -t part_names < <(lsblk --list --noheadings --paths --output NAME,TYPE | grep -i "part")

	part_names=(${part_names[@]/ part/})

	# Display partition menu
	echo_partition_menu ${part_names[@]}

	# Get menu selection
	for id in {ESP,root,swap,home}; do
		echo -e -n "\n=> Select ${GREEN}$id${RESET} partition or (n)one to skip: "

		local part_index=-1

		until (( $part_index >= 0 && $part_index < ${#part_names[@]} ))
		do
			local opt

			read -r -s -n 1 opt

			# Exit disk menu
			if [[ "${opt,,}" == "n" ]]; then
				part_index=-1
				break
			fi

			# Capture and exclude arrow keys
			if [[ "$opt" == "$(printf '\u1b')" ]]; then
				read -r -s -n 2 temp
				unset temp
			fi

			if [[ "${opt,,}" =~ ^[[:lower:]]+$ ]]; then
				part_index=$(printf '%d' "'${opt,,}")
				part_index=$(($part_index-97))
			fi
		done

		if (( $part_index != -1 )); then
			PART_IDS[$id]="${part_names[$part_index]}"
		else
			PART_IDS[$id]=""
		fi
	done

	if [[ -n ${PART_IDS[ESP]} || -n ${PART_IDS[root]} || -n ${PART_IDS[swap]} || -n ${PART_IDS[home]} ]]; then
		echo -e "\n\nThe following partitions will be formatted:"
		echo
		[[ -n ${PART_IDS[ESP]} ]] && echo -e "  + ${GREEN}ESP${RESET} partition $(get_partition_type ${PART_IDS[ESP]}) will be formated with file system ${GREEN}FAT32${RESET}."

		[[ -n ${PART_IDS[root]} ]] && echo -e "  + ${GREEN}Root${RESET} partition $(get_partition_type ${PART_IDS[root]}) will formated with file system ${GREEN}EXT4${RESET}."

		[[ -n ${PART_IDS[swap]} ]] && echo -e "  + ${GREEN}Swap${RESET} partition $(get_partition_type ${PART_IDS[swap]}) will be activated as ${GREEN}SWAP${RESET} partition."

		[[ -n ${PART_IDS[home]} ]] && echo -e "  + ${GREEN}Home${RESET} partition $(get_partition_type ${PART_IDS[home]}) will be formated with file system ${GREEN}EXT4${RESET}."

		if [[ -n ${PART_IDS[ESP]} ]]; then
			echo

			echo_warning "Format the ESP partition only if Windows is not already installed"
		fi

		if [[ -n ${PART_IDS[home]} ]]; then
			echo

			echo_warning "Format the Home partition only if it is empty"
		fi

		echo

		echo_warning "This will erase all data on partitions, make sure you have backed up data before proceeding"

		if get_user_confirm; then
			if [[ -n ${PART_IDS[ESP]} ]]; then
				echo_progress_heading "Formating ESP partition"
				mkfs.fat -F32 -n "ESP" ${PART_IDS[ESP]}
			fi

			if [[ -n ${PART_IDS[root]} ]]; then
				echo_progress_heading "Formating root partition"
				mkfs.ext4 -L "Root" ${PART_IDS[root]}
			fi

			if [[ -n ${PART_IDS[home]} ]]; then
				echo_progress_heading "Formating home partition"
				mkfs.ext4 -L "Home" ${PART_IDS[home]}
			fi

			if [[ -n ${PART_IDS[swap]} ]]; then
				echo_progress_heading "Activating swap partition"
				mkswap ${PART_IDS[swap]}
				swapon ${PART_IDS[swap]}
			fi
		fi
	else
		echo -e "\n"

		echo_warning "No partitions selected for formatting"
	fi
}

mount_partitions()
{
	echo

	if [[ -z ${PART_IDS[ESP]} || -z ${PART_IDS[root]} || -z ${PART_IDS[home]} ]]; then
		echo "Available partitions:"

		# Get partition names
		local part_names=()

		readarray -t part_names < <(lsblk --list --noheadings --paths --output NAME,TYPE | grep -i "part")

		part_names=(${part_names[@]/ part/})

		# Display partition menu
		echo_partition_menu ${part_names[@]}

		# Get menu selection
		for id in {ESP,root,home}; do
			if [[ -z ${PART_IDS[$id]} ]]; then
				echo -e -n "\n => Select ${GREEN}$id${RESET} partition or (n)one to skip: "

				local part_index=-1

				until (( $part_index >= 0 && $part_index < ${#part_names[@]} ))
				do
					local opt

					read -r -s -n 1 opt

					# Exit disk menu
					if [[ "${opt,,}" == "n" ]]; then
						part_index=-1
						break
					fi

					# Capture and exclude arrow keys
					if [[ "$opt" == "$(printf '\u1b')" ]]; then
						read -r -s -n 2 temp
						unset temp
					fi

					if [[ "${opt,,}" =~ ^[[:lower:]]+$ ]]; then
						part_index=$(printf '%d' "'${opt,,}")
						part_index=$(($part_index-97))
					fi
				done

				if (( $part_index != -1 )); then
					PART_IDS[$id]="${part_names[$part_index]}"
				else
					PART_IDS[$id]=""
				fi
			fi
		done

		echo -e "\n"
	fi

	if [[ -n ${PART_IDS[ESP]} || -n ${PART_IDS[root]} || -n ${PART_IDS[home]} ]]; then
		echo "The following partitions will be mounted:"
		echo
		[[ -n ${PART_IDS[ESP]} ]] && echo -e "  + ${GREEN}ESP${RESET} partition $(get_partition_info ${PART_IDS[ESP]}) will be mounted to ${GREEN}/mnt/efi${RESET}"

		[[ -n ${PART_IDS[root]} ]] && echo -e "  + ${GREEN}Root${RESET} partition $(get_partition_info ${PART_IDS[root]}) will be mounted to ${GREEN}/mnt${RESET}"

		[[ -n ${PART_IDS[home]} ]] && echo -e "  + ${GREEN}Home${RESET} partition $(get_partition_info ${PART_IDS[home]}) will be mounted to ${GREEN}/mnt/home${RESET}"

		if get_user_confirm; then
			echo_progress_heading "Mounting partitions"
			[[ -n ${PART_IDS[root]} ]] && mount ${PART_IDS[root]} /mnt

			[[ -n ${PART_IDS[ESP]} ]] && mount --mkdir ${PART_IDS[ESP]} /mnt/efi

			[[ -n ${PART_IDS[home]} ]] && mount --mkdir ${PART_IDS[home]} /mnt/home

			echo_progress_heading "Verifying partition structure"
			echo_partition_structure
		fi
	else
		echo_warning "No partitions selected for mounting"
	fi
}

install_base()
{
	echo
	echo "Install base packages."

	if get_user_confirm; then
		echo_progress_heading "Updating Arch Linux keyring"
		pacman -Syy
		pacman -S archlinux-keyring

		echo_progress_heading "Installing base packages"
		pacstrap /mnt base base-devel linux linux-firmware sof-firmware intel-ucode nano man-db man-pages terminus-font
	fi
}

generate_fstab()
{
	echo
	echo "Generate new fstab file."

	if get_user_confirm; then
		echo_progress_heading "Generating fstab file"
		genfstab -U /mnt >> /mnt/etc/fstab

		echo_progress_heading "Verifying file: /mnt/etc/fstab"
		echo_file_contents "/mnt/etc/fstab"

		echo_warning "In case of errors, do not run the command a second time, edit the fstab file manually"
	fi
}

run_postinstall()
{
	# Download post install script if not present
	if [[ ! -f /mnt/arch-post-install.bash ]]; then
		curl -LJSs -o /mnt/arch-post-install.bash "https://raw.githubusercontent.com/drakkar1969/arch-install/master/arch-post-install.bash"
	fi

	# Chroot and run post install script
	arch-chroot /mnt /bin/bash arch-post-install.bash
}

unmount_partitions()
{
	echo

	local mount_points=$(mount)
	local root_mnt=$(echo "$mount_points" | grep -i "/mnt ")
	local efi_mnt=$(echo "$mount_points" | grep -i "/mnt/efi ")
	local home_mnt=$(echo "$mount_points" | grep -i "/mnt/home ")

	echo "The following partitions will be unmounted:"
	echo
	[[ -n $root_mnt ]] && echo -e "  + ${GREEN}$(echo $root_mnt | cut -d' ' -f1)${RESET} on ${GREEN}$(echo $root_mnt | cut -d' ' -f3)${RESET}"

	[[ -n $efi_mnt ]] && echo -e "  + ${GREEN}$(echo $efi_mnt | cut -d' ' -f1)${RESET} on ${GREEN}$(echo $efi_mnt | cut -d' ' -f3)${RESET}"

	[[ -n $home_mnt ]] && echo -e "  + ${GREEN}$(echo $home_mnt | cut -d' ' -f1)${RESET} on ${GREEN}$(echo $home_mnt | cut -d' ' -f3)${RESET}"

	echo

	echo_warning "Proceed only if all installation steps have been completed"

	if get_user_confirm; then
		echo_progress_heading "Unmounting partitions"

		[[ -n $root_mnt ]] && umount -R /mnt
	fi
}

#=======================================================================================
# MAIN FUNCTION
#=======================================================================================
main()
{
	MENU_ITEMS=("Check UEFI Mode|check_uefimode|"
				"Update System Clock|system_clock|"
				"Create Partitions|create_partitions|"
				"Format Partitions|format_partitions|"
				"Mount Partitions|mount_partitions|"
				"Install Base Packages|install_base|"
				"Generate Fstab File|generate_fstab|"
				"Run Post Install Script|run_postinstall|sub"
				"Unmount Partitions|unmount_partitions|")

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

			# Quit installation
			if [[ "${start_choice,,}" == "q" ]]; then
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

				local is_sub=$(echo ${MENU_ITEMS[$menu_index-1]} | cut -f3 -d'|')

				if [[ -n $is_sub ]]; then
					clear
					echo_header

					local item_name=$(echo ${MENU_ITEMS[$menu_index-1]} | cut -f1 -d'|')

					echo -e "  ${BOLD}STEP ${menu_index} / ${#MENU_ITEMS[@]}: ${item_name}${RESET}"

					if (( $menu_index <= $((${#MENU_ITEMS[@]}-1)) )); then
						echo_keymap_start false
					else
						echo_keymap_start true
					fi

					echo
					echo -e "  ${BOLD}Post installation script has finished${RESET}"
				fi

				if (( $menu_index <= $((${#MENU_ITEMS[@]}-1)) )); then
					echo_keymap_end false
				else
					echo_keymap_end true
				fi

				while true; do
					local end_choice

					read -r -s -n 1 end_choice

					# Quit installation
					if [[ "${end_choice,,}" == "q" ]]; then
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

	clear

	echo -e "${BOLD}Installation script has finished${RESET}"
	echo
	echo "Restart the system to boot into GNOME:"
	echo
	echo -e "${GREEN}  reboot${RESET}"
	echo
}

main
