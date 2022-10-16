#!/bin/bash
# Comment out any lines that start with ParallelDownloads
sudo sed -i 's/^ParallelDownloads/#ParallelDownloads/' /etc/pacman.conf
# Replace first line that starts with #ParallelDownloads with ParallelDownloads = 5
# Within 0 to first line starting with X, replace line starting with X with Y
sudo sed -i '0,/^#ParallelDownloads/{s/^#ParallelDownloads.*/ParallelDownloads = 5/}' /etc/pacman.conf
pacman -S --needed base-devel
ln -sf /usr/share/zoneinfo/America/Phoenix /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "KEYMAP=en" >> /etc/vconsole.conf
echo "arch" >> /etc/hostname
systemctl enable NetworkManager.service
systemctl enable sddm.service
passwd
bootctl --path=/boot install
echo "title   Arch Linux Oct 2022" > /boot/loader/entries/arch.conf
echo "linux   /vmlinuz-linux" >> /boot/loader/entries/arch.conf
echo "initrd  /amd-ucode.img" >> /boot/loader/entries/arch.conf
echo "initrd  /initramfs-linux.img" >> /boot/loader/entries/arch.conf
echo "options root=PARTUUID=$(blkid -o value -s UUID $1) rw" >> /boot/loader/entries/arch.conf
echo "default arch" > /boot/loader/loader.conf
echo "timeout 4" >> /boot/loader/loader.conf
echo "console-mode max" >> /boot/loader/loader.conf
echo "editor no" >> /boot/loader/loader.conf
bootctl --path=/boot update
UNAME="sapien"
useradd -m -G "wheel,adm,ftp,games,http,log,rfkill,sys,systemd-journal,uucp,power,network,vboxusers" -s /bin/zsh $UNAME
passwd $UNAME
