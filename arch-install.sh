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
	local blk_part_info=$(lsblk --output NAME,SIZE,FSTYPE --paths --raw | grep -i $1)
	local blk_part_id=$(echo $blk_part_info | awk '{print $1}')
	local blk_part_size=$(echo $blk_part_info | awk '{print $2}')
	local blk_part_fs=$(echo $blk_part_info | awk '{print $3}')

	echo -e "${GREEN}$blk_part_id${RESET} [type: ${GREEN}$blk_part_fs${RESET}; size: ${GREEN}$blk_part_size${RESET}]"
}

#===========================================================================================================
# INSTALLATION FUNCTIONS
#===========================================================================================================
set_keyboard()
{
	print_submenu_heading "SET KEYBOARD LAYOUT"

	local user_confirm="n"
	local kb_code

	get_user_variable kb_code "keyboard layout" "it"

	echo -e "Set keyboard layout to ${GREEN}${kb_code}${RESET}."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Setting keyboard layout"
		loadkeys $kb_code

		MAINCHECKLIST[$1]=1

		get_any_key
	fi
}

check_uefimode()
{
	print_submenu_heading "CHECK UEFI MODE"

	print_progress_text "Listing EFI variables"
	ls /sys/firmware/efi/efivars

	MAINCHECKLIST[$1]=1

	get_any_key
}

enable_wifi()
{
	print_submenu_heading "ENABLE WIFI CONNECTION"

	local user_confirm="n"
	local adapter_id
	local wifi_ssid

	iwctl device list
	get_user_variable adapter_id "wireless adapter name" "wlp3s0"

	print_progress_text "Scanning for wifi networks ..."

	iwctl station $adapter_id scan
	iwctl station $adapter_id get-networks
	get_user_variable wifi_ssid "wireless network name" ""

	echo -e "Connect to wifi network ${GREEN}${wifi_ssid}${RESET} on adapter ${GREEN}${adapter_id}${RESET}."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Connecting to wifi network"
		station $adapter_id connect $wifi_ssid

		print_progress_text "Checking network connection"
		ping -c 3 www.google.com

		MAINCHECKLIST[$1]=1

		get_any_key
	fi
}

system_clock()
{
	print_submenu_heading "UPDATE SYSTEM CLOCK"

	local user_confirm="n"

	echo -e "Enable clock synchronization over network."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Enabling clock synchronization over network"
		timedatectl set-ntp true

		print_progress_text "Checking time and date status"
		timedatectl

		MAINCHECKLIST[$1]=1

		get_any_key
	fi
}

sub_format_boot()
{
	print_submenu_heading "FORMAT BOOT (ESP) PARTITION (FAT32)"

	local user_confirm="n"

	print_partition_structure

	local fmt_esp_id

	get_user_variable fmt_esp_id "boot (ESP) partition ID" "/dev/nvme0n1p1"

	echo -e "Partition $(get_partition_info $fmt_esp_id) will be formated with file system ${GREEN}FAT32${RESET}."

	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Formatting boot partition"
		mkfs.fat -F32 $fmt_esp_id

		FMTCHECKLIST[$1]=1

		get_any_key
	fi
}

sub_format_root()
{
	print_submenu_heading "FORMAT ROOT PARTITION"

	local user_confirm="n"

	print_partition_structure

	local fmt_root_id

	get_user_variable fmt_root_id "root partition ID" "/dev/nvme0n1p2"

	echo -e "Partition $(get_partition_info $fmt_root_id) will be formated with file system ${GREEN}EXT4${RESET}."

	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Formatting root partition"
		mkfs.ext4 $fmt_root_id

		FMTCHECKLIST[$1]=1

		get_any_key
	fi
}

sub_format_home()
{
	print_submenu_heading "FORMAT HOME PARTITION"

	local user_confirm="n"

	print_partition_structure

	local fmt_home_id

	get_user_variable fmt_home_id "home partition ID" "/dev/nvme0n1p4"

	echo -e "Partition $(get_partition_info $fmt_home_id) will be formated with file system ${GREEN}EXT4${RESET}."

	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Formatting home partition"
		mkfs.ext4 $fmt_home_id

		FMTCHECKLIST[$1]=1

		get_any_key
	fi
}

sub_make_swap()
{
	print_submenu_heading "MAKE SWAP PARTITION"

	local user_confirm="n"

	print_partition_structure

	local fmt_swap_id

	get_user_variable fmt_swap_id "SWAP partition ID" "/dev/nvme0n1p3"

	echo -e "Partition $(get_partition_info $fmt_swap_id) will be activated as ${GREEN}SWAP${RESET} partition."

	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Activating SWAP partition"
		mkswap $fmt_swap_id
		swapon $fmt_swap_id

		FMTCHECKLIST[$1]=1

		get_any_key
	fi
}

format_partitions()
{
	# Format menu loop
	while true; do
		clear

		# Print header
		echo -e "-------------------------------------------------------------------------------"
		echo -e "-- ${GREEN} FORMAT PARTIONS ${RESET}::${GREEN} SUB MENU${RESET}"
		echo -e "-------------------------------------------------------------------------------"

		# Print sub-menu items
		for i in ${!FMTITEMS[@]}; do
			local sub_text=$(echo "${FMTITEMS[$i]}" | cut -f1 -d'|')

			print_menu_item $(($i+1)) ${FMTCHECKLIST[$i]} "$sub_text"
		done

		# Print footer
		echo ""
		echo -e "-------------------------------------------------------------------------------"
		echo ""
		echo -e -n " => Select option or (b)ack: "

		# Get sub-menu selection
		local fmt_index=-1

		until (( $fmt_index >= 0 && $fmt_index < ${#FMTITEMS[@]} ))
		do
			local fmt_choice

			read -r -s -n 1 fmt_choice

			# Exit sub-menu
			if [[ "${fmt_choice,,}" == "b" ]]; then
				return
			fi

			# Get selection index
			if [[ "$fmt_choice" == [0-9] ]]; then
				fmt_index=$(($fmt_choice-1))
			fi
		done

		# Execute function
		local sub_func=$(echo "${FMTITEMS[$fmt_index]}" | cut -f2 -d'|')

		eval ${sub_func} $fmt_index

		# Check sub-menu status
		local fmt_array_sum=$((${FMTCHECKLIST[@]/%/+}0))

		if [[ $fmt_array_sum -eq ${#FMTCHECKLIST[@]} ]]; then
			MAINCHECKLIST[$1]=1
		fi
	done
}

mount_partitions()
{
	print_submenu_heading "MOUNT PARTITIONS"

	local user_confirm="n"

	print_partition_structure

	local mnt_boot_id
	local mnt_root_id
	local mnt_home_id

	get_user_variable mnt_boot_id "ESP boot partition ID (blank to skip)" "/dev/nvme0n1p1"
	get_user_variable mnt_root_id "root partition ID (blank to skip)" "/dev/nvme0n1p2"
	get_user_variable mnt_home_id "home partition ID (blank to skip)" "/dev/nvme0n1p4"

	echo -e "The following partitions will be mounted:"
	echo ""
	if [[ "$mnt_boot_id" != "" ]]; then
		echo -e "   + ESP (boot) partition $(get_partition_info $mnt_boot_id) will be mounted to ${GREEN}/mnt/boot${RESET}"
	fi
	if [[ "$mnt_root_id" != "" ]]; then
		echo -e "   + Root partition $(get_partition_info $mnt_root_id) will be mounted to ${GREEN}/mnt${RESET}"
	fi
	if [[ "$mnt_home_id" != "" ]]; then
		echo -e "   + Home partition $(get_partition_info $mnt_home_id) will be mounted to ${GREEN}/mnt/home${RESET}"
	fi
	echo ""

	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Mounting partitions"
		if [[ "$mnt_root_id" != "" ]]; then
			mount $mnt_root_id /mnt
		fi

		if [[ "$mnt_home_id" != "" ]]; then
			mkdir /mnt/home
			mount $mnt_home_id /mnt/home
		fi

		if [[ "$mnt_boot_id" != "" ]]; then
			mkdir /mnt/boot
			mount $mnt_boot_id /mnt/boot
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

	local user_confirm="n"

	echo -e "Install base packages."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Installing base packages"
		pacstrap /mnt base base-devel linux linux-firmware

		MAINCHECKLIST[$1]=1

		get_any_key
	fi
}

generate_fstab()
{
	print_submenu_heading "GENERATE FSTAB FILE"

	local user_confirm="n"

	echo -e "Generate new fstab file."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Generating fstab file"
		genfstab -U /mnt >> /mnt/etc/fstab

		print_file_contents "/mnt/etc/fstab"
		print_warning "In case of errors, do not run the command a second time, edit the fstab file manually"

		MAINCHECKLIST[$1]=1

		get_any_key
	fi
}

download_postinstall()
{
	print_submenu_heading "DOWNLOAD POST INSTALL SCRIPT"

	local user_confirm="n"

	echo -e "Download post install script ${GREEN}arch-post-install.sh${RESET}."
	get_yn_confirmation user_confirm

	if [[ "$user_confirm" == "y" ]]; then
		print_progress_text "Downloading post-install script"
		curl -LJO https://raw.githubusercontent.com/drakkar1969/arch-install/master/arch-post-install.sh
		cp arch-post-install.sh /mnt

		MAINCHECKLIST[$1]=1

		get_any_key
	fi
}

main_menu()
{
	MAINITEMS=("Set keyboard layout|set_keyboard"
						 "Check UEFI mode|check_uefimode"
						 "Enable wifi connection|enable_wifi"
						 "Update system clock|system_clock"
						 "Format partitions|format_partitions"
						 "Mount partitions|mount_partitions"
						 "Install base packages|install_base"
						 "Generate fstab file|generate_fstab"
						 "Download post install script|download_postinstall")
	MAINCHECKLIST=()

	FMTITEMS=("Format boot (ESP) partition (FAT32)|sub_format_boot"
						"Format root partition (EXT4)|sub_format_root"
						"Format home partition (EXT4)|sub_format_home"
						"Make SWAP partition|sub_make_swap")
	FMTCHECKLIST=()

	# Initialize checklist arrays with '0'
	local i

	for i in ${!MAINITEMS[@]}; do
		MAINCHECKLIST+=("0")
	done

	for i in ${!FMTITEMS[@]}; do
		FMTCHECKLIST+=("0")
	done

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
				echo -e "To complete the installation, change root into the new system:"
				echo ""
				echo -e "   ${GREEN}arch-chroot /mnt /bin/bash${RESET}"
				echo ""
				echo -e "Execute the script ${GREEN}arch-post-install.sh${RESET}."
				echo ""
				exit 0
			fi

			# Get selection index
			if [[ "$main_choice" == [a-zA-Z] ]]; then
				# Get ascii code from character (A->65, etc.)
				main_index=$(LC_CTYPE=C printf '%d' "'${main_choice^^}")
				main_index=$(($main_index-65))
			fi
		done

		# Execute function
		local item_func=$(echo "${MAINITEMS[$main_index]}" | cut -f2 -d'|')

		eval ${item_func} $main_index
	done
}

main_menu
