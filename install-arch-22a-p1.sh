#!/bin/bash
sed -i '0,/^#ParallelDownloads/{s/^#ParallelDownloads.*/ParallelDownloads = 3/}' /etc/pacman.conf
cd scripts
loadkeys en
timedatectl status
read -p "Did you set the type of $1 to EFI System?" -n 1 -r
echo #New line
read -p "Format $1 (boot) and $2? " -n 1 -r
echo #New line
if [[ $REPLY =~ ^[Yy]$ ]] && [ -d "/sys/firmware/efi/efivars" ]; then
    mkfs.fat -F 32 $1
    fatlabel $1 "BOOT7"
    OS_NAME="arch7"
    mkfs.btrfs -f -L $OS_NAME $2
    mount --mkdir $2 /root/btrfs
    btrfs subvolume create /root/btrfs/subvol_${OS_NAME}_fsroot
    umount /root/btrfs
    mount -m -o "subvol=subvol_${OS_NAME}_fsroot,rw,noatime,compress-force=zstd:3,noautodefrag" $2 /mnt
    mount -m -o "subvol=subvol_var_cache_pacman_pkg,rw,noatime,noautodefrag" UUID=487b8741-9f8d-45bc-9f4e-0436d7f25e10 /mnt/var/cache/pacman/pkg
    mount -m $1 /mnt/boot
    pacstrap -K /mnt base linux linux-firmware sudo nano networkmanager amd-ucode btrfs-progs dosfstools exfatprogs f2fs-tools e2fsprogs jfsutils nilfs-utils ntfs-3g reiserfsprogs udftools xfsprogs vi kitty firefox man-db man-pages texinfo zsh xorg xorg-xwayland nvidia nvidia-utils nvidia-settings plasma plasma-wayland-session egl-wayland sddm sddm-kcm pipewire wireplumber pipewire-pulse ark dolphin dolphin-plugins dragon elisa ffmpegthumbs filelight gwenview kate kcalc kdegraphics-thumbnailers kdenlive kdesdk-kio kdesdk-thumbnailers kfind khelpcenter konsole ksystemlog okular spectacle
    genfstab -U /mnt >> /mnt/etc/fstab
    P2="install-arch-22a-p2.sh"
    cp $P2 /mnt/root/$P2
    arch-chroot /mnt /bin/bash /root/$P2 $1 $2 $OS_NAME
    #umount -R /mnt
fi
