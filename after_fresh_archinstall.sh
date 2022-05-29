#!/bin/bash
cd /home/$USER
# Update mirrorlist based on speed
sudo reflector --verbose --latest 5 --country 'United States' --protocol https --sort rate --save /etc/pacman.d/mirrorlist
# Enable parallel downloads and color
# Backup pacman config
sudo cp /etc/pacman.conf /etc/pacman.conf.backup
# Comment out any lines that start with ParallelDownloads
sed -i 's/^ParallelDownloads/#ParallelDownloads/' /etc/pacman.conf
# Replace first line that starts with #ParallelDownloads with ParallelDownloads = 5
# Within 0 to first line starting with X, replace line starting with X with Y
sed -i '0,/^#ParallelDownloads/{s/^#ParallelDownloads.*/ParallelDownloads = 5/}' /etc/pacman.conf
# Comment out any lines that start with Color
sed -i 's/^Color/#Color/' /etc/pacman.conf
# Replace first line that starts with #Color with Color
# Within 0 to first line starting with X, replace line starting with X with Y
sed -i '0,/^#Color/{s/^#Color.*/Color/}' /etc/pacman.conf
# Needed for paru installation
sudo pacman -S --needed git rustup
rustup toolchain install stable
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
cd ..
rm -r paru
PACKAGES="
qbittorrent-enhanced (AUR)(torrenting client)
spotify (AUR)(music player)
obs-studio (streaming & screen recording)
libjxl (JPEG-XL support)
gimp (Image editor)
openvpn
networkmanager-openvpn (For plasma GUI VPN support)
smplayer (Media player)
steam (Video game service)
colord-kde (Allows monitor color profiles in Plasma System Settings after restart)
kitty (Terminal)
kate (Text editor)
ntfs-3g (Manage ntfs partitions)
"
paru -S "$PACKAGES"
