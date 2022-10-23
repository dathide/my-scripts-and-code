#!/bin/bash
sed -i '0,/^#ParallelDownloads/{s/^#ParallelDownloads.*/ParallelDownloads = 3/}' /etc/pacman.conf
ln -sf /usr/share/zoneinfo/America/Phoenix /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "KEYMAP=us" >> /etc/vconsole.conf
echo "arch" >> /etc/hostname
systemctl enable NetworkManager
systemctl enable sddm
passwd
bootctl --path=/boot install
echo "title     Arch Linux 22a
linux    /vmlinuz-linux
initrd   /amd-ucode.img
initrd   /initramfs-linux.img
options root=\"LABEL=arch6\" rootfstype=btrfs rootflags=subvol=subvol_os1_fsroot rw" > /boot/loader/entries/arch.conf
echo "title     Arch Linux 22a Fallback
linux    /vmlinuz-linux
initrd   /amd-ucode.img
initrd   /initramfs-linux-fallback.img
options root=\"LABEL=arch6\" rootfstype=btrfs rootflags=subvol=subvol_os1_fsroot rw" > /boot/loader/entries/arch-fallback.conf
echo "default arch
timeout 4
console-mode max
editor no" > /boot/loader/loader.conf
bootctl --path=/boot update
UNAME="sapien"
useradd -m -G "wheel" -s /bin/zsh $UNAME
passwd $UNAME
# Prevent /var/log/journal from getting large
sed -i '0,/^#SystemMaxUse=/{s/^#SystemMaxUse=.*/SystemMaxUse=200M/}' /etc/systemd/journald.conf
exit
