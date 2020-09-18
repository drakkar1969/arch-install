#!/bin/bash

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

	read -s -e -n 1 -p "Are you sure you want to continue [y/n]: " _YNCHOICE
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
	print_progress_text "Listing EFI variables"
	ls /sys/firmware/efi/efivars

	MAINCHECKLIST[1]=1

	get_any_key
}

enable_wifi()
{
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
	local _USERCONFIRM="n"

	print_submenu_heading "FORMAT BOOT (ESP) PARTITION (FAT32)"

	print_partition_structure

	get_user_variable FMTESPID "boot (ESP) partition ID" "/dev/nvme0n1p1"

	local _PARTITIONINFO=$(get_partition_info $FMTESPID)

	echo -e "Partition $_PARTITIONINFO will be formated with file system ${GREEN}FAT32${RESET}."

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
	local _USERCONFIRM="n"

	print_submenu_heading "FORMAT ROOT PARTITION"

	print_partition_structure

	get_user_variable FMTROOTID "root partition ID" "/dev/nvme0n1p2"

	local _PARTITIONINFO=$(get_partition_info $FMTROOTID)

	echo -e "Partition $_PARTITIONINFO will be formated with file system ${GREEN}EXT4${RESET}."

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
	local _USERCONFIRM="n"

	print_submenu_heading "FORMAT HOME PARTITION"

	print_partition_structure

	get_user_variable FMTHOMEID "home partition ID" "/dev/nvme0n1p4"

	local _PARTITIONINFO=$(get_partition_info $FMTHOMEID)

	echo -e "Partition $_PARTITIONINFO will be formated with file system ${GREEN}EXT4${RESET}."

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
	local _USERCONFIRM="n"

	print_submenu_heading "MAKE SWAP PARTITION"

	print_partition_structure

	get_user_variable FMTSWAPID "SWAP partition ID" "/dev/nvme0n1p3"

	local _PARTITIONINFO=$(get_partition_info $FMTSWAPID)

	echo -e "Partition $_PARTITIONINFO will be activated as ${GREEN}SWAP${RESET} partition."

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
	local _USERCONFIRM="n"

	print_partition_structure

	get_user_variable MNTROOTID "root partition ID" "/dev/nvme0n1p2"
	get_user_variable MNTHOMEID "home partition ID" "/dev/nvme0n1p4"
	get_user_variable MNTBOOTID "ESP boot partition ID" "/dev/nvme0n1p1"

	echo -e "The following partitions will be mounted:"
	echo ""
	echo -e "+ Root partition $(get_partition_info $MNTROOTID) will be mounted to ${GREEN}/mnt${RESET}"
	echo -e "+ Home partition $(get_partition_info $MNTHOMEID) will be mounted to ${GREEN}/mnt/home${RESET}"
	echo -e "+ ESP (boot) partition $(get_partition_info $MNTBOOTID) will be mounted to ${GREEN}/mnt/boot${RESET}"
	echo ""

	get_yn_confirmation _USERCONFIRM

	if [[ "$_USERCONFIRM" = "y" ]]; then
		print_progress_text "Mounting partitions"
		mount $MNTROOTID /mnt

		mkdir /mnt/home
		mount $MNTHOMEID /mnt/home

		mkdir /mnt/boot
		smount $MNTBOOTID /mnt/boot

		print_progress_text "Verifying partition structure"
		print_partition_structure

		MAINCHECKLIST[5]=1

		get_any_key
	fi
}

install_base()
{
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
			print_submenu_heading "SET KEYBOARD LAYOUT"
			set_keyboard
			;;
		[bB])
			print_submenu_heading "CHECK UEFI MODE"
			check_uefimode
			;;
		[cC])
			print_submenu_heading "ENABLE WIFI CONNECTION"
			enable_wifi
			;;
		[dD])
			print_submenu_heading "UPDATE SYSTEM CLOCK"
			system_clock
			;;
		[eE])
			format_partitions
			;;
		[fF])
			print_submenu_heading "MOUNT PARTITIONS"
			mount_partitions
			;;
		[gG])
			print_submenu_heading "INSTALL BASE PACKAGES"
			install_base
			;;
		[hH])
			print_submenu_heading "GENERATE FSTAB FILE"
			generate_fstab
			;;
		[qQ])
			clear
			echo -e "To complete the installation, change root into the new system:"
			echo ""
			echo -e "   > ${GREEN}arch-chroot /mnt /bin/bash${RESET}"
			echo ""
			echo -e "Then download and execute the script ${GREEN}arch-post-install.sh${RESET}."
			echo ""
			exit 0
			;;
	esac
}

while true
do
	main_menu
done
