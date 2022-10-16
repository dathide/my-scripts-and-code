#!/bin/bash
cd scripts
echo "ParallelDownloads = 5" >> /etc/pacman.conf
loadkeys en
timedatectl status
read -p "Did you set the type of $1 to EFI System?" -n 1 -r
read -p "Format $1 as boot and $2 as fsroot? " -n 1 -r
echo #New line
if [[ $REPLY =~ ^[Yy]$ ]] && [ -d "/sys/firmware/efi/efivars" ]; then
    mkfs.fat -F 32 $1
    fatlabel $1 "BOOT2"
    mkfs.btrfs -f -L "ARCH2" $2
    mount $2 /mnt
    mount --mkdir /dev/$1 /mnt/boot
    pacstrap -K /mnt base linux linux-firmware nano networkmanager amd-ucode btrfs-progs dosfstools exfatprogs f2fs-tools e2fsprogs jfsutils nilfs-utils ntfs-3g reiserfsprogs udftools xfsprogs vi kitty firefox man-db man-pages texinfo zsh xorg nvidia nvidia-utils nvidia-settings plasma plasma-wayland-session egl-wayland sddm sddm-kcm
    genfstab -U /mnt >> /mnt/etc/fstab
    P2="install-arch-phase2-2022-10.sh"
    cp $P2 /mnt/root/$P2
    arch-chroot /mnt /bin/bash /root/$P2 $1 $2
fi
