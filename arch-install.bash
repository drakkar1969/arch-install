#!/bin/bash

#===========================================================================================================
# GLOBAL VARIABLES
#===========================================================================================================
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RESET='\033[0m'

ESP_PART_ID="/dev/nvme0n1p1"
ROOT_PART_ID="/dev/nvme0n1p5"
HOME_PART_ID="/dev/nvme0n1p7"
SWAP_PART_ID="/dev/nvme0n1p6"

declare -A PART_IDS=([ESP]="" [root]="" [home]="" [swap]="")

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

get_global_variable()
{
	local var_name=$1
	local user_input

	read -e -p "Enter $2: " -i "$3" user_input
	echo ""

	declare -g "$var_name"=$user_input
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

get_partition_size()
{
	local blk_part_id=$1

	local blk_part_size=$(lsblk --output SIZE --paths --raw --noheadings $blk_part_id)

	echo -e "${GREEN}$blk_part_id${RESET} [size: ${GREEN}$blk_part_size${RESET}]"
}

get_partition_info()
{
	local blk_part_id=$1

	local blk_part_size=$(lsblk --output SIZE --paths --raw --noheadings $blk_part_id)
	local blk_part_fs=$(lsblk --output FSTYPE --paths --raw --noheadings $blk_part_id)

	[[ -z $blk_part_fs ]] && blk_part_fs="unknown"

	echo -e "${GREEN}$blk_part_id${RESET} [type: ${GREEN}$blk_part_fs${RESET}; size: ${GREEN}$blk_part_size${RESET}]"
}

print_partitions()
{
	part_names="$1"

	for i in "${!part_names[@]}"; do
		local part_type=$(lsblk --output PARTLABEL --noheadings ${part_names[$i]})
		local part_size=$(lsblk --output SIZE --raw --noheadings ${part_names[$i]})

		printf "   [%d] %s [type: %b; size: %b]\n" $(($i+1)) "${part_names[$i]}" "${GREEN}$part_type${RESET}" "${GREEN}$part_size${RESET}"
	done
	unset i
}

get_partition_type()
{
	local part_id=$1

	local part_size=$(lsblk --output SIZE --paths --raw --noheadings $part_id)
	local part_type=$(lsblk --output PARTLABEL --paths --noheadings $part_id)

	[[ -z $part_type ]] && part_type="unknown"

	echo -e "${GREEN}$part_id${RESET} [type: ${GREEN}$part_type${RESET}; size: ${GREEN}$part_size${RESET}]"
}

#===========================================================================================================
# INSTALLATION FUNCTIONS
#===========================================================================================================
check_uefimode()
{
	print_submenu_heading "CHECK UEFI MODE"

	print_progress_text "Listing EFI variables"
	ls /sys/firmware/efi/efivars

	MAINCHECKLIST[$1]=1

	get_any_key
}

system_clock()
{
	print_submenu_heading "UPDATE SYSTEM CLOCK"

	echo -e "Enable clock synchronization over network."

	if get_user_confirm; then
		print_progress_text "Enabling clock synchronization over network"
		timedatectl set-ntp true

		print_progress_text "Checking time and date status"
		timedatectl

		MAINCHECKLIST[$1]=1

		get_any_key
	fi
}

format_partitions()
{
	print_submenu_heading "FORMAT PARTITIONS"

	local part_names=()

	readarray -t part_names < <(lsblk -lnp -o NAME,TYPE | grep -i "part")

	part_names=(${part_names[@]/ part/})

	print_partitions ${part_names[@]}

	for id in {ESP,root,swap,home}; do
		echo -e -n "\n   => Select ${GREEN}$id${RESET} partition or (n)one to skip: "

		# Get menu selection
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

			if [[ "$opt" =~ ^[[:digit:]]+$ ]]; then
				part_index=$(($opt-1))
			fi
		done

		if (( $part_index != -1 )); then
			PART_IDS[$id]="${part_names[$part_index]}"
		fi
	done

	echo -e "\n\nThe following partitions will be formatted:"
	echo ""
	[[ -n ${PART_IDS[ESP]} ]] && echo -e "   + ${GREEN}ESP${RESET} partition $(get_partition_type ${PART_IDS[ESP]}) will be formated with file system ${GREEN}FAT32${RESET}."

	[[ -n ${PART_IDS[root]} ]] && echo -e "   + ${GREEN}Root${RESET} partition $(get_partition_type ${PART_IDS[root]}) will formated with file system ${GREEN}EXT4${RESET}."

	[[ -n ${PART_IDS[home]} ]] && echo -e "   + ${GREEN}Home${RESET} partition $(get_partition_type ${PART_IDS[home]}) will be formated with file system ${GREEN}EXT4${RESET}."

	[[ -n ${PART_IDS[swap]} ]] && echo -e "   + ${GREEN}Swap${RESET} partition $(get_partition_type ${PART_IDS[swap]}) will be activated as ${GREEN}SWAP${RESET} partition."

	echo ""

	print_warning "Format the ESP (boot) partition only if Windows is not already installed"

	echo ""

	print_warning "Format the Home partition only if it is empty"

	echo ""

	print_warning "This will erase all data on partitions, make sure you have backed up data before proceeding"

	if get_user_confirm; then
		if [[ -n ${PART_IDS[ESP]} ]]; then
			print_progress_text "Formating ESP (boot) partition"
			mkfs.fat -F32 -n "ESP" ${PART_IDS[ESP]}
		fi

		if [[ -n ${PART_IDS[root]} ]]; then
			print_progress_text "Formating root partition"
			mkfs.ext4 -L "Root" ${PART_IDS[root]}
		fi

		if [[ -n ${PART_IDS[home]} ]]; then
			print_progress_text "Formating home partition"
			mkfs.ext4 -L "Home" ${PART_IDS[home]}
		fi

		if [[ -n ${PART_IDS[swap]} ]]; then
			print_progress_text "Activating swap partition"
			mkswap ${PART_IDS[swap]}
			swapon ${PART_IDS[swap]}
		fi

		MAINCHECKLIST[$1]=1

		get_any_key
	fi
}

mount_partitions()
{
	print_submenu_heading "MOUNT PARTITIONS"

	print_partition_structure

	get_global_variable ESP_PART_ID "ESP boot partition ID (blank to skip)" "$ESP_PART_ID"
	get_global_variable ROOT_PART_ID "root partition ID (blank to skip)" "$ROOT_PART_ID"
	get_global_variable HOME_PART_ID "home partition ID (blank to skip)" "$HOME_PART_ID"

	echo -e "The following partitions will be mounted:"
	echo ""
	[[ -n $ESP_PART_ID ]] && echo -e "   + ESP (boot) partition $(get_partition_info $ESP_PART_ID) will be mounted to ${GREEN}/mnt/boot${RESET}"

	[[ -n $ROOT_PART_ID ]] && echo -e "   + Root partition $(get_partition_info $ROOT_PART_ID) will be mounted to ${GREEN}/mnt${RESET}"

	[[ -n $HOME_PART_ID ]] && echo -e "   + Home partition $(get_partition_info $HOME_PART_ID) will be mounted to ${GREEN}/mnt/home${RESET}"

	if get_user_confirm; then
		print_progress_text "Mounting partitions"
		[[ -n $ROOT_PART_ID ]] && mount $ROOT_PART_ID /mnt

		if [[ -n $ESP_PART_ID ]]; then
			mkdir -p /mnt/boot
			mount $ESP_PART_ID /mnt/boot
		fi

		if [[ -n $HOME_PART_ID ]]; then
			mkdir -p /mnt/home
			mount $HOME_PART_ID /mnt/home
		fi

		print_progress_text "Verifying partition structure"
		print_partition_structure

		MAINCHECKLIST[$1]=1

		get_any_key
	fi
}

install_base()
{
	print_submenu_heading "INSTALL BASE PACKAGES"

	echo -e "Install base packages."

	if get_user_confirm; then
		print_progress_text "Updating Arch Linux keyring"
		pacman -Syy
		pacman -S archlinux-keyring

		print_progress_text "Installing base packages"
		pacstrap -K /mnt base base-devel linux linux-firmware sof-firmware nano man-db man-pages

		MAINCHECKLIST[$1]=1

		get_any_key
	fi
}

generate_fstab()
{
	print_submenu_heading "GENERATE FSTAB FILE"

	echo -e "Generate new fstab file."

	if get_user_confirm; then
		print_progress_text "Generating fstab file"
		genfstab -U /mnt >> /mnt/etc/fstab

		print_file_contents "/mnt/etc/fstab"
		print_warning "In case of errors, do not run the command a second time, edit the fstab file manually"

		MAINCHECKLIST[$1]=1

		get_any_key
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

	MAINCHECKLIST[$1]=1
}

unmount_partitions()
{
	print_submenu_heading "UNMOUNT PARTITIONS"

	local mount_points=$(mount)
	local root_mnt=$(echo "$mount_points" | grep -i "/mnt ")
	local boot_mnt=$(echo "$mount_points" | grep -i "/mnt/boot ")
	local home_mnt=$(echo "$mount_points" | grep -i "/mnt/home ")

	echo -e "The following partitions will be unmounted:"
	echo ""
	[[ -n $root_mnt ]] && echo -e "   + ${GREEN}$(echo $root_mnt | cut -d' ' -f1)${RESET} on ${GREEN}$(echo $root_mnt | cut -d' ' -f3)${RESET}"

	[[ -n $boot_mnt ]] && echo -e "   + ${GREEN}$(echo $boot_mnt | cut -d' ' -f1)${RESET} on ${GREEN}$(echo $boot_mnt | cut -d' ' -f3)${RESET}"

	[[ -n $home_mnt ]] && echo -e "   + ${GREEN}$(echo $home_mnt | cut -d' ' -f1)${RESET} on ${GREEN}$(echo $home_mnt | cut -d' ' -f3)${RESET}"

	echo ""

	print_warning "Proceed only if all installation steps have been completed"

	if get_user_confirm; then
		print_progress_text "Unmounting partitions"

		[[ -n $root_mnt ]] && umount -R /mnt

		MAINCHECKLIST[$1]=1

		get_any_key
	fi
}

main_menu()
{
	MAINITEMS=("Check UEFI Mode|check_uefimode"
				"Update System Clock|system_clock"
				"Format Partitions|format_partitions"
				"Mount Partitions|mount_partitions"
				"Install Base Packages|install_base"
				"Generate Fstab File|generate_fstab"
				"Run Post Install Script >>|run_postinstall"
				"Unmount Partitions|unmount_partitions")
	MAINCHECKLIST=("${MAINITEMS[@]/*/0}")

	# Main menu loop
	while true; do
		clear

		# Print header
		echo -e "-------------------------------------------------------------------------------"
		echo -e "-- ${GREEN} ARCH LINUX ${RESET}::${GREEN} INSTALL MENU${RESET}"
		echo -e "-------------------------------------------------------------------------------"

		# Print menu items
		for i in ${!MAINITEMS[@]}; do
			# Get character from ascii code (0->A,etc.)
			local item_index=$(printf "\\$(printf '%03o' "$(($i+65))")")

			local item_text=$(echo "${MAINITEMS[$i]}" | cut -f1 -d'|')

			print_menu_item $item_index ${MAINCHECKLIST[$i]} "$item_text"
		done
		unset i

		# Print footer
		echo ""
		echo -e "-------------------------------------------------------------------------------"
		echo ""
		echo -e -n " => Select option or (q)uit: "

		# Get menu selection
		local main_index=-1

		until (( $main_index >= 0 && $main_index < ${#MAINITEMS[@]} ))
		do
			local main_choice

			read -r -s -n 1 main_choice

			# Exit main menu
			if [[ "${main_choice,,}" == "q" ]]; then
				clear
				echo -e "Restart to boot into GNOME:"
				echo ""
				echo -e "   ${GREEN}reboot${RESET}"
				echo ""
				exit 0
			fi

			# Get selection index
			if [[ "$main_choice" =~ ^[a-zA-Z]+$ ]]; then
				# Get ascii code from character (A->65, etc.)
				main_index=$(LC_CTYPE=C printf '%d' "'${main_choice^^}")
				main_index=$(($main_index-65))
			fi
		done

		# Execute function
		local item_func=$(echo "${MAINITEMS[$main_index]}" | cut -f2 -d'|')

		${item_func} $main_index
	done
}

main_menu
