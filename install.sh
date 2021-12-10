#!/usr/bin/env bash
#         d8888          888                  d8888                 888      
#        d88888          888                 d88888                 888      
#       d88P888          888                d88P888                 888      
#      d88P 888 888  888 888888 .d88b.     d88P 888 888d888 .d8888b 88888b.  
#     d88P  888 888  888 888   d88""88b   d88P  888 888P"  d88P"    888 "88b 
#    d88P   888 888  888 888   888  888  d88P   888 888    888      888  888 
#   d8888888888 Y88b 888 Y88b. Y88..88P d8888888888 888    Y88b.    888  888 
#  d88P     888  "Y88888  "Y888 "Y88P" d88P     888 888     "Y8888P 888  888 

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "-------------------------------------------------"
echo "Setting up mirrors for optimal download          "
echo "-------------------------------------------------"

# grab the users country iso
iso=$(curl -4 ifconfig.co/country-iso)
timedatectl set-ntp true

# enable parallel downloads and color output with pacman
sed -i 's/^#Para/Para/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf
pacman -S --noconfirm reflector rsync
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

# Clear the screen
clear

echo -e "       d8888          888                  d8888                 888      "
echo -e "      d88888          888                 d88888                 888      "
echo -e "     d88P888          888                d88P888                 888      "
echo -e "    d88P 888 888  888 888888 .d88b.     d88P 888 888d888 .d8888b 88888b.  "
echo -e "   d88P  888 888  888 888   d88\"\"88b   d88P  888 888P\"  d88P\"    888 \"88b "
echo -e "  d88P   888 888  888 888   888  888  d88P   888 888    888      888  888 "
echo -e " d8888888888 Y88b 888 Y88b. Y88..88P d8888888888 888    Y88b.    888  888 "
echo -e "d88P     888  \"Y88888  \"Y888 \"Y88P\" d88P     888 888     \"Y8888P 888  888 "
echo -e ""
echo -e "-------------------------------------------------------------------------"
echo -e "-Setting up $iso mirrors for faster downloads"
echo -e "-------------------------------------------------------------------------"

reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
mkdir /mnt

echo -e "\nInstalling prereqs...\n$HR"
pacman -S --noconfirm gptfdisk

echo "-------------------------------------------------"
echo "-------select your disk to format----------------"
echo "-------------------------------------------------"
lsblk
echo "Please enter disk to work on: (example /dev/sda)"
read DISK
echo "THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK"
read -p "are you sure you want to continue (Y/N):" formatdisk

case $formatdisk in

y|Y|yes|Yes|YES)
echo "--------------------------------------"
echo -e "\nFormatting disk...\n$HR"
echo "--------------------------------------"

# disk prep
sgdisk -Z ${DISK} # zap all on disk
sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

sgdisk -n 1::+300M --typecode=1:ef00 --change-name=1:'EFIBOOT' ${DISK} # partition 1 (UEFI Boot Partition)
sgdisk -n 2::-0 --typecode=2:8300 --change-name=2:'ROOT' ${DISK} # partition 2 (Root), default start, remaining

# make filesystems
echo -e "\nCreating Filesystems...\n$HR"
if [[ ${DISK} =~ "nvme" ]]; then
mkfs.vfat -F32 -n "EFIBOOT" "${DISK}p1"
mkfs.ext4 "${DISK}p2"
mount "${DISK}p2" /mnt
else
mkfs.vfat -F32 -n "EFIBOOT" "${DISK}1"
mkfs.ext4 "${DISK}2"
mount "${DISK}2" /mnt
fi
;;
*)
;;
esac

if ! grep -qs '/mnt' /proc/mounts; then
    echo "Drive is not mounted and can not continue"
    echo "Rebooting in 3 Seconds ..." && sleep 1
    echo "Rebooting in 2 Seconds ..." && sleep 1
    echo "Rebooting in 1 Second ..." && sleep 1
    reboot now
fi

echo "--------------------------------------"
echo "-- Arch Install on Main Drive       --"
echo "--------------------------------------"

pacstrap /mnt base base-devel linux linux-firmware --noconfirm --needed
genfstab -U /mnt >> /mnt/etc/fstab

cp -R ${SCRIPT_DIR} /mnt/root/AutoArch
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

arch-chroot /mnt /root/AutoArch/setup.sh

# Unmount install and reboot into system
umount -R /mnt

echo "Rebooting in 3 Seconds ..." && sleep 1
echo "Rebooting in 2 Seconds ..." && sleep 1
echo "Rebooting in 1 Second ..." && sleep 1
reboot now