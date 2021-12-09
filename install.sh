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

# enable parallel downloads with pacman
sed -i 's/^#Para/Para/' /etc/pacman.conf
pacman -S --noconfirm reflector rsync grub
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

mkdir /mnt/boot
mkdir /mnt/boot/efi
mount -L EFIBOOT /mnt/boot/

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

arch-chroot /mnt

echo "-------------------------------------------------"
echo "       Setup Language to US and set locale       "
echo "-------------------------------------------------"

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

read -p "Time zone region:" tz_region
read -p "Time zone city:" tz_city

timedatectl --no-ask-password set-timezone ${tz_region}/${tz_city}
timedatectl --no-ask-password set-ntp 1
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"

# Set keymaps
localectl --no-ask-password set-keymap us

# Add sudo no password rights
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

# Add parallel downloading
sed -i 's/^#Para/Para/' /etc/pacman.conf

# Enable multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm

# Setup Chaotic AUR
pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key FBA220DFC880C036
pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
echo '[chaotic-aur]' >> "/etc/pacman.conf"
echo 'Include = /etc/pacman.d/chaotic-mirrorlist' >> "/etc/pacman.conf"

echo -e "\nInstalling Base System\n"

PKGS=(
    'xorg'
    'xorg-xinit'
    'picom'
    'alacritty'
    'pipewire'
    'brave'
    'sudo'
    'nvim'
    'wget'
)

for PKG in "${PKGS[@]}"; do
    echo "INSTALLING: ${PKG}"
    sudo pacman -S "$PKG" --noconfirm --needed
done

#
# determine processor type and install microcode
# 
proc_type=$(lscpu | awk '/Vendor ID:/ {print $3}')
case "$proc_type" in
	GenuineIntel)
		print "Installing Intel microcode"
		pacman -S --noconfirm intel-ucode
		proc_ucode=intel-ucode.img
		;;
	AuthenticAMD)
		print "Installing AMD microcode"
		pacman -S --noconfirm amd-ucode
		proc_ucode=amd-ucode.img
		;;
esac

# Graphics Drivers find and install
if lspci | grep -E "NVIDIA|GeForce"; then
    pacman -S nvidia --noconfirm --needed
	nvidia-xconfig
elif lspci | grep -E "Radeon"; then
    pacman -S xf86-video-amdgpu --noconfirm --needed
elif lspci | grep -E "Integrated Graphics Controller"; then
    pacman -S libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils --needed --noconfirm
fi