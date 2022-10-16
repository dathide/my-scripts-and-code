#!/bin/bash
cd scripts
# Comment out any lines that start with ParallelDownloads
sudo sed -i 's/^ParallelDownloads/#ParallelDownloads/' /etc/pacman.conf
# Replace first line that starts with #ParallelDownloads with ParallelDownloads = 5
# Within 0 to first line starting with X, replace line starting with X with Y
sudo sed -i '0,/^#ParallelDownloads/{s/^#ParallelDownloads.*/ParallelDownloads = 5/}' /etc/pacman.conf
loadkeys en
timedatectl status
read -p "Did you set the type of $1 to EFI System?" -n 1 -r
read -p "Format $1 as boot and $2 as fsroot? " -n 1 -r
echo #New line
if [[ $REPLY =~ ^[Yy]$ ]] && [ -d "/sys/firmware/efi/efivars" ]; then
    mkfs.fat -F 32 $1
    mkfs.btrfs $2
    mount $2 /mnt
    mount --mkdir /dev/$1 /mnt/boot
    pacstrap -K /mnt base linux linux-firmware
    genfstab -U /mnt >> /mnt/etc/fstab
    P2="install-arch-phase2-2022-10.sh"
    cp $P2 /mnt/root/$P2
    arch-chroot /mnt /bin/bash /root/$P2 $1 $2
fi
