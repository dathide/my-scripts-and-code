#!/bin/bash
sed -i '0,/^#ParallelDownloads/{s/^#ParallelDownloads.*/ParallelDownloads = 3/}' /etc/pacman.conf
cd scripts
loadkeys en
timedatectl status
read -p "Did you set the type of $1 to EFI System?" -n 1 -r
read -p "Format $1 as boot and $2 as fsroot? " -n 1 -r
echo #New line
if [[ $REPLY =~ ^[Yy]$ ]] && [ -d "/sys/firmware/efi/efivars" ]; then
    mkfs.fat -F 32 $1
    fatlabel $1 "BOOT2"
    mkfs.btrfs -f -L "ARCH2" $2
    mount --mkdir $2 /root/btrfs
    btrfs subvolume create /root/btrfs/subvol_os1_fsroot
    btrfs subvolume create /root/btrfs/subvol_os1_var_cache_pacman_pkg
    umount /root/btrfs
    mount -m -o "subvol=subvol_os1_fsroot,rw,noatime,compress-force=zstd:3,noautodefrag" $2 /mnt
    mount -m -o "subvol=subvol_os1_var_cache_pacman_pkg,rw,noatime,noautodefrag" $2 /mnt/var/cache/pacman/pkg
    mount -m $1 /mnt/boot
    pacstrap -K /mnt base linux linux-firmware nano networkmanager amd-ucode btrfs-progs dosfstools exfatprogs f2fs-tools e2fsprogs jfsutils nilfs-utils ntfs-3g reiserfsprogs udftools xfsprogs vi kitty firefox man-db man-pages texinfo zsh xorg xorg-xwayland nvidia nvidia-utils nvidia-settings plasma plasma-wayland-session egl-wayland sddm sddm-kcm pipewire wireplumber pipewire-pulse
    genfstab -U /mnt >> /mnt/etc/fstab
    P2="install-arch-22a-p2.sh"
    cp $P2 /mnt/root/$P2
    arch-chroot /mnt /bin/bash /root/$P2 $1 $2
    umount -R /mnt
fi
