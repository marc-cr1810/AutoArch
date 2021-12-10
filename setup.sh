#!/usr/bin/env bash
#         d8888          888                  d8888                 888      
#        d88888          888                 d88888                 888      
#       d88P888          888                d88P888                 888      
#      d88P 888 888  888 888888 .d88b.     d88P 888 888d888 .d8888b 88888b.  
#     d88P  888 888  888 888   d88""88b   d88P  888 888P"  d88P"    888 "88b 
#    d88P   888 888  888 888   888  888  d88P   888 888    888      888  888 
#   d8888888888 Y88b 888 Y88b. Y88..88P d8888888888 888    Y88b.    888  888 
#  d88P     888  "Y88888  "Y888 "Y88P" d88P     888 888     "Y8888P 888  888 

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
echo "--------------------------------------------------------"
echo "          Setup Language to US and set locale           "
echo "--------------------------------------------------------"

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

read -p "Time zone region:" tz_region
read -p "Time zone city:" tz_city

timedatectl --no-ask-password set-timezone ${tz_region}/${tz_city}
timedatectl --no-ask-password set-ntp 1
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"

# Set keymaps
localectl --no-ask-password set-keymap us

echo "--------------------------------------------------------"
echo "     Configure Pacman with Multilib and Chaotic AUR     "
echo "--------------------------------------------------------"

# Add sudo rights
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# Add parallel downloading and color output with pacman
sed -i 's/^#Para/Para/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf

# Enable multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm

# Setup Chaotic AUR
pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key FBA220DFC880C036
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
echo '[chaotic-aur]' >> "/etc/pacman.conf"
echo 'Include = /etc/pacman.d/chaotic-mirrorlist' >> "/etc/pacman.conf"
pacman -Sy --noconfirm

echo "--------------------------------------------------------"
echo "          Installing base system and packages           "
echo "--------------------------------------------------------"

PKGS=(
    'xorg'
    'xorg-xinit'
    'picom'
    'alacritty'
    'pipewire'
    'brave'
    'sudo'
    'lunarvim-git'
    'wget'
    'bspwm'
    'sxhkd'
    'fish'
    'bashtop'
    'rofi'
    'dunst'
    'polybar'
    'python'
    'python-pywal'
    'discord'
    'spotify'
    'celluloid'
    'networkmanager'
    'networkmanager-demu'
    'ranger'
    'neofetch'
    'thunar'
    'starship'
    'git'
)

for PKG in "${PKGS[@]}"; do
    echo "INSTALLING: ${PKG}"
    sudo pacman -S "$PKG" --noconfirm --needed
done

# Determine processor type and install microcode
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

echo -e "\nDone!\n"

echo "--------------------------------------------------------"
echo "              Setup machine name and user               "
echo "--------------------------------------------------------"
if [ $(whoami) = "root"  ];
then
    echo -e "Set root password:"
    passwd

    read -p "Please enter username: " username
    useradd -m -G wheel -s /bin/bash $username 
	passwd $username

	read -p "Please name your machine: " nameofmachine
	echo $nameofmachine > /etc/hostname
fi

echo "--------------------------------------------------------"
echo "                    Installing Grub                     "
echo "--------------------------------------------------------"

mkdir /boot/EFI
mount -L EFIBOOT /boot/EFI

pacman -S --noconfirm grub
# For UEFI
pacman -S --noconfirm efibootmgr dosfstools os-prober mtools

grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
grub-mkconfig -o /boot/grub/grub.cfg


echo "--------------------------------------------------------"
echo "                   Post-install setup                   "
echo "--------------------------------------------------------"

echo "Enabling Network Manager"
systemctl enable NetworkManager

# Finally exit
exit