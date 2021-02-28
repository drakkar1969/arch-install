#!/usr/bin/env bash

#===========================================================================================================
# GLOBAL VARIABLES
#===========================================================================================================
MAINCHECKLIST=(0 0 0 0 0 0 0 0)
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
set_keyboard()
{
	print_submenu_heading "SET KEYBOARD LAYOUT"

	local _USERCONFIRM="n"

	get_user_variable KBCODE "keyboard layout" "it"

	echo -e "Set keyboard layout to ${GREEN}${KBCODE}${RESET}."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Setting keyboard layout"
		loadkeys $KBCODE

		MAINCHECKLIST[0]=1

		get_any_key
	fi
}

check_uefimode()
{
	print_submenu_heading "CHECK UEFI MODE"

	print_progress_text "Listing EFI variables"
	ls /sys/firmware/efi/efivars

	MAINCHECKLIST[1]=1

	get_any_key
}

enable_wifi()
{
	print_submenu_heading "ENABLE WIFI CONNECTION"

	local _USERCONFIRM="n"

	iwctl device list
	get_user_variable ADAPTERID "wireless adapter name" "wlp3s0"

	print_progress_text "Scanning for wifi networks ..."

	iwctl station $ADAPTERID scan
	iwctl station $ADAPTERID get-networks
	get_user_variable WIFISSID "wireless network name" ""

	echo -e "Connect to wifi network ${GREEN}${WIFISSID}${RESET} on adapter ${GREEN}${ADAPTERID}${RESET}."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Connecting to wifi network"
		station $ADAPTERID connect $WIFISSID

		print_progress_text "Checking network connection"
		ping -c 3 www.google.com

		MAINCHECKLIST[2]=1

		get_any_key
	fi
}

system_clock()
{
	print_submenu_heading "UPDATE SYSTEM CLOCK"

	local _USERCONFIRM="y"

	echo -e "Enable clock synchronization over network."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Enabling clock synchronization over network"
		timedatectl set-ntp true

		print_progress_text "Checking time and date status"
		timedatectl

		MAINCHECKLIST[3]=1

		get_any_key
	fi
}

sub_format_boot()
{
	print_submenu_heading "FORMAT BOOT (ESP) PARTITION (FAT32)"

	local _USERCONFIRM="n"

	print_partition_structure

	get_user_variable FMTESPID "boot (ESP) partition ID" "/dev/nvme0n1p1"

	echo -e "Partition $(get_partition_info $FMTESPID) will be formated with file system ${GREEN}FAT32${RESET}."

	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Formatting boot partition"
		mkfs.fat -F32 $FMTESPID

		FMTCHECKLIST[0]=1

		get_any_key
	fi
}

sub_format_root()
{
	print_submenu_heading "FORMAT ROOT PARTITION"

	local _USERCONFIRM="n"

	print_partition_structure

	get_user_variable FMTROOTID "root partition ID" "/dev/nvme0n1p2"

	echo -e "Partition $(get_partition_info $FMTROOTID) will be formated with file system ${GREEN}EXT4${RESET}."

	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Formatting root partition"
		mkfs.ext4 $FMTROOTID

		FMTCHECKLIST[1]=1

		get_any_key
	fi
}

sub_format_home()
{
	print_submenu_heading "FORMAT HOME PARTITION"

	local _USERCONFIRM="n"

	print_partition_structure

	get_user_variable FMTHOMEID "home partition ID" "/dev/nvme0n1p4"

	echo -e "Partition $(get_partition_info $FMTHOMEID) will be formated with file system ${GREEN}EXT4${RESET}."

	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Formatting home partition"
		mkfs.ext4 $FMTHOMEID

		FMTCHECKLIST[2]=1

		get_any_key
	fi
}

sub_make_swap()
{
	print_submenu_heading "MAKE SWAP PARTITION"

	local _USERCONFIRM="n"

	print_partition_structure

	get_user_variable FMTSWAPID "SWAP partition ID" "/dev/nvme0n1p3"

	echo -e "Partition $(get_partition_info $FMTSWAPID) will be activated as ${GREEN}SWAP${RESET} partition."

	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Activating SWAP partition"
		mkswap $FMTSWAPID
		swapon $FMTSWAPID

		FMTCHECKLIST[3]=1

		get_any_key
	fi
}

format_partitions()
{
	local _FORMATLOOPINPUT=""

	while [[ "$_FORMATLOOPINPUT" != "b" ]]
	do
		clear

		echo -e "-------------------------------------------------------------------------------"
		echo -e "-- ${GREEN} FORMAT PARTIONS :: SUB MENU${RESET}"
		echo -e "-------------------------------------------------------------------------------"

		print_menu_item 1 ${FMTCHECKLIST[0]} "Format boot (ESP) partition (FAT32)"
		print_menu_item 2 ${FMTCHECKLIST[1]} "Format root partition (EXT4)"
		print_menu_item 3 ${FMTCHECKLIST[2]} "Format home partition (EXT4)"
		print_menu_item 4 ${FMTCHECKLIST[3]} "Make SWAP partition"

		echo ""
		echo -e "-------------------------------------------------------------------------------"
		echo ""
		read -s -e -n 1 -p " Select option or (b)ack: " _FORMATLOOPINPUT
		echo ""

		case $_FORMATLOOPINPUT in
			1)
				sub_format_boot
				;;
			2)
				sub_format_root
				;;
			3)
				sub_format_home
				;;
			4)
				sub_make_swap
				;;
		esac
	done

	((FMTARRAYSUM = ${FMTCHECKLIST[@]/%/+}0))

	if [[ $FMTARRAYSUM -eq ${#FMTCHECKLIST[@]} ]]; then
		MAINCHECKLIST[4]=1
	fi
}

mount_partitions()
{
	print_submenu_heading "MOUNT PARTITIONS"

	local _USERCONFIRM="n"

	print_partition_structure

	get_user_variable MNTBOOTID "ESP boot partition ID (blank to skip)" "/dev/nvme0n1p1"
	get_user_variable MNTROOTID "root partition ID (blank to skip)" "/dev/nvme0n1p2"
	get_user_variable MNTHOMEID "home partition ID (blank to skip)" "/dev/nvme0n1p4"

	echo -e "The following partitions will be mounted:"
	echo ""
	if [[ "$MNTBOOTID" != "" ]]; then
		echo -e "   + ESP (boot) partition $(get_partition_info $MNTBOOTID) will be mounted to ${GREEN}/mnt/boot${RESET}"
	fi
	if [[ "$MNTROOTID" != "" ]]; then
		echo -e "   + Root partition $(get_partition_info $MNTROOTID) will be mounted to ${GREEN}/mnt${RESET}"
	fi
	if [[ "$MNTHOMEID" != "" ]]; then
		echo -e "   + Home partition $(get_partition_info $MNTHOMEID) will be mounted to ${GREEN}/mnt/home${RESET}"
	fi
	echo ""

	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Mounting partitions"
		if [[ "$MNTROOTID" != "" ]]; then
			mount $MNTROOTID /mnt
		fi

		if [[ "$MNTHOMEID" != "" ]]; then
			mkdir /mnt/home
			mount $MNTHOMEID /mnt/home
		fi

		if [[ "$MNTBOOTID" != "" ]]; then
			mkdir /mnt/boot
			mount $MNTBOOTID /mnt/boot
		fi

		print_progress_text "Verifying partition structure"
		print_partition_structure

		MAINCHECKLIST[5]=1

		get_any_key
	fi
}

install_base()
{
	print_submenu_heading "INSTALL BASE PACKAGES"

	local _USERCONFIRM="n"

	echo -e "Install base packages."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Installing base packages"
		pacstrap /mnt base base-devel linux linux-firmware

		MAINCHECKLIST[6]=1

		get_any_key
	fi
}

generate_fstab()
{
	print_submenu_heading "GENERATE FSTAB FILE"

	local _USERCONFIRM="n"

	echo -e "Generate new fstab file."
	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Generating fstab file"
		genfstab -U /mnt >> /mnt/etc/fstab

		print_file_contents "/mnt/etc/fstab"
		print_warning "In case of errors, do not run the command a second time, edit the fstab file manually"

		MAINCHECKLIST[7]=1

		get_any_key
	fi
}

main_menu()
{
	clear

	echo -e "-------------------------------------------------------------------------------"
	echo -e "-- ${GREEN} ARCH LINUX ${RESET}::${GREEN} MAIN MENU${RESET}"
	echo -e "-------------------------------------------------------------------------------"

	print_menu_item A ${MAINCHECKLIST[0]} 'Set keyboard layout'
	print_menu_item B ${MAINCHECKLIST[1]} 'Check UEFI mode'
	print_menu_item C ${MAINCHECKLIST[2]} 'Enable wifi connection'
	print_menu_item D ${MAINCHECKLIST[3]} 'Update system clock'
	print_menu_item E ${MAINCHECKLIST[4]} 'Format partitions'
	print_menu_item F ${MAINCHECKLIST[5]} 'Mount partitions'
	print_menu_item G ${MAINCHECKLIST[6]} 'Install base packages'
	print_menu_item H ${MAINCHECKLIST[7]} 'Generate fstab file'

	echo ""
	echo -e "-------------------------------------------------------------------------------"
	echo ""
	read -s -e -n 1 -p " => Select option or (q)uit: " _MAINCHOICE
	echo ""

	case $_MAINCHOICE in
		[aA])
			set_keyboard
			;;
		[bB])
			check_uefimode
			;;
		[cC])
			enable_wifi
			;;
		[dD])
			system_clock
			;;
		[eE])
			format_partitions
			;;
		[fF])
			mount_partitions
			;;
		[gG])
			install_base
			;;
		[hH])
			generate_fstab
			;;
		[qQ])
			clear
			echo -e "To complete the installation, change root into the new system:"
			echo ""
			echo -e "   > ${GREEN}arch-chroot /mnt /bin/bash${RESET}"
			echo ""
			echo -e "Download and execute the script ${GREEN}arch-post-install.sh${RESET}."
			echo ""
			exit 0
			;;
	esac
}

while true
do
	main_menu
done
