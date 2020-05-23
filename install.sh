#!/bin/bash

#PARTITION DISK BEFORE USING THIS SCRIPT
# list devices: lsblk
# partition disk: cfdisk -z <device>

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

#use \n to add more locales
LOCALE_GEN="en_US.UTF-8 UTF-8\npt_BR.UTF-8 UTF-8"

LANG=en_US.UTF-8

HOSTNAME=arch
HOSTS="127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t${HOSTNAME}.localdomain ${HOSTNAME}"

PACKAGES="base linux nano grub networkmanager sudo"

#Services to enable (space-separated eg: "NetworkManager lightdm")
SERVICES="NetworkManager"

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

sleep 2

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
for item in ${SERVICES[*]}
do
    arch-chroot /mnt systemctl enable $item
done

