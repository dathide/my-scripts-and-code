#!/bin/bash
cd archstuff
sleep 0.5
sed -i 's/#Color/Color/' /etc/pacman.conf
sleep 0.5
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
sleep 0.5
loadkeys us
sleep 0.5
if [[ ! -d "/sys/firmware/efi/efivars" ]] ; then
    echo 'efivars directory is not there, aborting.'
    exit
fi
sleep 0.5
timedatectl set-ntp true
sleep 0.5
cryptsetup open /dev/disk/by-label/ARCHBTRFS1 crypt1
sleep 0.5
mkfs.btrfs -f /dev/mapper/crypt1
sleep 0.5
mount /dev/mapper/crypt1 /mnt
sleep 0.5
btrfs subvolume create /mnt/r1
sleep 0.5
btrfs subvolume create /mnt/r1home
sleep 0.5
btrfs subvolume create /mnt/r1var
sleep 0.5
btrfs subvolume create /mnt/r1snapshots
sleep 0.5
umount /mnt
sleep 0.5
mount -o noatime,compress-force=zstd:3,subvol=r1 /dev/mapper/crypt1 /mnt
sleep 0.5
mount --mkdir -o noatime,compress-force=zstd:3,subvol=r1home /dev/mapper/crypt1 /mnt/home
sleep 0.5
mount --mkdir -o noatime,compress-force=zstd:3,subvol=r1var /dev/mapper/crypt1 /mnt/var
sleep 0.5
mount --mkdir -o noatime,compress-force=zstd:3,subvol=r1snapshots /dev/mapper/crypt1 /mnt/snapshots
sleep 0.5
mount --mkdir /dev/disk/by-label/ARCHBOOT1 /mnt/boot
sleep 0.5
pacstrap /mnt base linux linux-firmware btrfs-progs dosfstools exfatprogs f2fs-tools e2fsprogs jfsutils nilfs-utils ntfs-3g reiserfsprogs udftools xfsprogs nano vim neovim man-db man-pages texinfo amd-ucode efifs grub efibootmgr plasma sddm zsh sudo firefox kitty
sleep 0.5
genfstab -U /mnt >> /mnt/etc/fstab
sleep 0.5
cp phase2.sh /mnt/home
sleep 0.5
arch-chroot /mnt
sleep 0.5
# then need to /bin/bash /home/phase2.sh
