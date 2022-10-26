#!/bin/bash
# After booting into Arch Linux iso using Ventoy, run these commands:
# pacman -Sy git
# git clone http://github.com/dathide/archstuff scripts
# /bin/bash scripts/install-arch-22a-p1.sh /dev/nvme0n1p# /dev/nvme0n1p#
UNAME="sapien"
OS_NAME="arch7"
OS_SUBVOL="subvol_${OS_NAME}_fsroot"
# This subvolume will be used to store pacman's package cache
SSD_UUID="487b8741-9f8d-45bc-9f4e-0436d7f25e10"
SUBV_PACMAN="subvol_var_cache_pacman_pkg"
SUBV_PARU="subvol_home_user_.cache_paru_clone"

in_chroot () {
    sed -i '0,/^#ParallelDownloads/{s/^#ParallelDownloads.*/ParallelDownloads = 3/}' /etc/pacman.conf
    ln -sf /usr/share/zoneinfo/America/Phoenix /etc/localtime
    hwclock --systohc
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf
    echo "KEYMAP=us" >> /etc/vconsole.conf
    echo "arch" >> /etc/hostname
    systemctl enable NetworkManager
    passwd
    bootctl --path=/boot install
    echo "title     Arch Linux 22a
    linux    /vmlinuz-linux
    initrd   /amd-ucode.img
    initrd   /initramfs-linux.img
    options root=\"LABEL=$OS_NAME\" rootfstype=btrfs rootflags=subvol=subvol_${OS_NAME}_fsroot rw nvidia_drm.modeset=1" > /boot/loader/entries/arch.conf
    echo "title     Arch Linux 22a Fallback
    linux    /vmlinuz-linux
    initrd   /amd-ucode.img
    initrd   /initramfs-linux-fallback.img
    options root=\"LABEL=$OS_NAME\" rootfstype=btrfs rootflags=subvol=subvol_${OS_NAME}_fsroot rw nvidia_drm.modeset=1" > /boot/loader/entries/arch-fallback.conf
    echo "default arch
    timeout 4
    console-mode max
    editor no" > /boot/loader/loader.conf
    bootctl --path=/boot update
    useradd -m -G "wheel" -s /bin/zsh $UNAME
    passwd $UNAME
    # Prevent /var/log/journal from getting large
    sed -i '0,/^#SystemMaxUse=/{s/^#SystemMaxUse=.*/SystemMaxUse=200M/}' /etc/systemd/journald.conf
    # Configure sudo
    sudo echo "sudo initialization for /etc/sudoers creation"
    sed -i '0,/^# %wheel ALL=(ALL:ALL) ALL/{s/^# %wheel ALL=(ALL:ALL) ALL.*/%wheel ALL=(ALL:ALL) ALL/}' /etc/sudoers
    # Install paru-bin

    exit
}

sed -i '0,/^#ParallelDownloads/{s/^#ParallelDownloads.*/ParallelDownloads = 3/}' /etc/pacman.conf
cd scripts
loadkeys en
timedatectl status
# Line only exists if first partition is flagged as bootable
EFI1=$( fdisk -lu | grep -i "EFI System" | grep -i "$1" )
# Confirm with user so they can double check what partitions they are formatting
read -p "Format $1 (boot) and $2? " -n 1 -r
echo #New line
# Proceed only if reply is y or Y, system is in EFI mode, and first partition is flagged as bootable
if [[ $REPLY =~ ^[Yy]$ ]] && [ -d "/sys/firmware/efi/efivars" ] && [ ${#EFI1} -ge 1 ]; then
    mkfs.fat -F 32 $1
    fatlabel $1 "BOOT7"
    mkfs.btrfs -f -L $OS_NAME $2
    mount -m $2 /root/btrfs
    btrfs subvolume create "/root/btrfs/$OS_SUBVOL"
    umount /root/btrfs
    mount -m -o "subvol=$OS_SUBVOL,rw,noatime,compress-force=zstd:3,noautodefrag" $2 /mnt
    mount -m -o "subvol=$SUBV_PACMAN,rw,noatime,noautodefrag" "UUID=$SSD_UUID" /mnt/var/cache/pacman/pkg
    mount -m $1 /mnt/boot
    pacstrap -K /mnt base linux linux-firmware sudo nano networkmanager amd-ucode btrfs-progs dosfstools exfatprogs f2fs-tools e2fsprogs jfsutils nilfs-utils ntfs-3g reiserfsprogs udftools xfsprogs vi kitty firefox man-db man-pages texinfo zsh xorg-xwayland nvidia nvidia-utils nvidia-settings plasma plasma-wayland-session egl-wayland pipewire wireplumber pipewire-pulse ark dolphin dolphin-plugins dragon elisa ffmpegthumbs filelight gwenview kate kcalc kdegraphics-thumbnailers kdenlive kdesdk-kio kdesdk-thumbnailers kfind khelpcenter konsole ksystemlog okular spectacle
    genfstab -U /mnt >> /mnt/etc/fstab
    arch-chroot /mnt in_chroot
fi
# From https://wiki.archlinux.org/title/KDE#From_the_console
# To start a wayland session: startplasma-wayland
