#!/bin/bash

#PARTITION DISK BEFORE USING THIS SCRIPT
# list devices: 'lsblk' of 'fdisk -l'
# partition disk: 'cfdisk -z /dev/sda'

#--------------------------------------CONFIG--------------------------------------
#device for MBR, comment for UEFI (also set DEV_BOOT for UEFI)
DEV_MBR=/dev/sda

#select partitions to use, comment if not using
#DEV_BOOT=/dev/sda1
DEV_SWAP=/dev/sda1
DEV_ROOT=/dev/sda2
#DEV_HOME=/dev/sda3

#uncomment to skip formatting (need to format manually if skipped)
#SKIP_FORMAT=true

ROOT_PWD=root
USER=user
USER_PWD=user

KEYMAP=br-abnt2

#find your timezone in '/usr/share/zoneinfo/'
TIMEZONE="America/Sao_Paulo"

#use \n to add more locales
LOCALE_GEN="en_US.UTF-8 UTF-8\npt_BR.UTF-8 UTF-8"

LANG=en_US.UTF-8

HOSTNAME=arch
HOSTS="127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t${HOSTNAME}.localdomain ${HOSTNAME}"

PACKAGES="base base-devel git grub linux-lts linux-lts-headers linux-firmware nano networkmanager network-manager-applet os-prober sudo"

#comment to keep multilib disabled
ENABLE_MULTILIB=true

#EXTRA PACKAGES (installed with pacman on chroot)
#comment or modify as needed
EXTRA_PACKAGES="intel-ucode"
EXTRA_PACKAGES+=" bash-completion cifs-utils git grub-customizer gvfs-nfs gvfs-smb ntfs-3g pacman-contrib"
EXTRA_PACKAGES+=" blueman bluez-tools"
EXTRA_PACKAGES+=" alsa-firmware alsa-plugins alsa-utils pavucontrol pavucontrol-qt pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-equalizer pulseaudio-jack"
EXTRA_PACKAGES+=" noto-fonts ttf-bitstream-vera ttf-dejavu ttf-roboto ttf-ubuntu-font-family"
EXTRA_PACKAGES+=" arc-gtk-theme kvantum-qt5 kvantum-theme-adapta kvantum-theme-arc kvantum-theme-materia materia-gtk-theme papirus-icon-theme"
EXTRA_PACKAGES+=" lib32-nvidia-utils nvidia-lts nvidia-settings"
EXTRA_PACKAGES+=" lxqt sddm"
EXTRA_PACKAGES+=" neofetch htop numlockx"
EXTRA_PACKAGES+=" chromium firefox"
EXTRA_PACKAGES+=" nemo nemo-fileroller ffmpegthumbnailer qbittorrent steam teamspeak3 vlc xed"
EXTRA_PACKAGES+=" xfce4-settings xfce4-terminal xfwm4"

#Services to enable (space-separated eg: "NetworkManager sddm")
SERVICES="NetworkManager sddm"

#----------------------------------END CONFIG----------------------------------

if [ -z "$DEV_MBR" ]; then
    PACKAGES+=" efibootmgr"
fi

if [ -n "$DEV_SWAP" ]; then
    if [ -z "$SKIP_FORMAT" ]; then
        yes | mkswap -L swap "$DEV_SWAP"
    fi
    echo enabling swap on "$DEV_SWAP"    
    swapon "$DEV_SWAP"
fi

if [ -n "$DEV_ROOT" ]; then
    if [ -z "$SKIP_FORMAT" ]; then
        yes | mkfs.ext4 -L root "$DEV_ROOT"
    fi
    echo mounting "$DEV_ROOT" to /mnt    
    mount "$DEV_ROOT" /mnt
fi

if [ -z "$DEV_MBR" ]; then
    if [ -z "$SKIP_FORMAT" ]; then
        yes | mkfs.fat -F32 "$DEV_BOOT"
    fi
    echo mounting "$DEV_BOOT" to /mnt/boot/efi
    mkdir -p /mnt/boot/efi
    mount "$DEV_BOOT" /mnt/boot/efi
fi

if [ -n "$DEV_HOME" ]; then
    if [ -z "$SKIP_FORMAT" ]; then
        yes | mkfs.ext4 -L home "$DEV_HOME"
    fi
    echo mounting "$DEV_HOME" to /mnt/home
    mkdir -p /mnt/home    
    mount "$DEV_HOME" /mnt/home
fi

pacstrap /mnt $PACKAGES
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt hwclock --systohc --utc
arch-chroot /mnt timedatectl set-ntp true
arch-chroot /mnt ln -sf /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime

echo -e "$HOSTS" >> /mnt/etc/hosts
echo "$HOSTNAME" > /mnt/etc/hostname
echo "KEYMAP=$KEYMAP" >> /mnt/etc/vconsole.conf
echo -e "$LOCALE_GEN" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=$LANG" >> /mnt/etc/locale.conf

arch-chroot /mnt useradd -mG wheel $USER
echo "$USER:$USER_PWD" | chpasswd --root /mnt
echo "root:$ROOT_PWD" | chpasswd --root /mnt
echo "%wheel ALL=(ALL) ALL" > /mnt/etc/sudoers.d/wheel

if [ -n "$DEV_MBR" ]; then
    arch-chroot /mnt grub-install $DEV_MBR
else
    arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
fi
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

if [ -n "$ENABLE_MULTILIB" ]; then
    echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /mnt/etc/pacman.conf
fi

arch-chroot pacman -Syu --noconfirm 

if [ -n "$EXTRA_PACKAGES" ]; then
arch-chroot pacman -S --noconfirm $EXTRA_PACKAGES
fi
for item in ${SERVICES[*]}; do
    arch-chroot /mnt systemctl enable $item
done


