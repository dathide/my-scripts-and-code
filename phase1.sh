#!/bin/bash
cd archstuff
sed -i 's/#Color/Color/' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
loadkeys us
if [[ ! -d "/sys/firmware/efi/efivars" ]] ; then
    echo 'efivars directory is not there, aborting.'
    exit
fi
timedatectl set-ntp true
cryptsetup open /dev/disk/by-label/ARCHBTRFS1 crypt1
mkfs.btrfs -f /dev/mapper/crypt1
mount /dev/mapper/crypt1 /mnt
btrfs subvolume create /mnt/r1
btrfs subvolume create /mnt/r1home
btrfs subvolume create /mnt/r1var
btrfs subvolume create /mnt/r1snapshots
umount /mnt
mount -o noatime,compress-force=zstd:3,subvol=r1 /dev/mapper/crypt1 /mnt
mount --mkdir -o noatime,compress-force=zstd:3,subvol=r1home /dev/mapper/crypt1 /mnt/home
mount --mkdir -o noatime,compress-force=zstd:3,subvol=r1var /dev/mapper/crypt1 /mnt/var
mount --mkdir -o noatime,compress-force=zstd:3,subvol=r1snapshots /dev/mapper/crypt1 /mnt/snapshots
mount --mkdir /dev/disk/by-label/ARCHBOOT1 /mnt/boot
pacstrap /mnt base linux linux-firmware btrfs-progs dosfstools exfatprogs f2fs-tools e2fsprogs jfsutils nilfs-utils ntfs-3g reiserfsprogs udftools xfsprogs nano vim neovim man-db man-pages texinfo amd-ucode efifs grub efibootmgr cryptsetup plasma-desktop sddm zsh sudo firefox kitty
genfstab -U /mnt >> /mnt/etc/fstab
cp phase2.sh /mnt/home
arch-chroot /mnt
# then need to /bin/bash /home/phase2.sh
