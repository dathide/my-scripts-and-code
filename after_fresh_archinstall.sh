#!/bin/bash
cd /home/$USER
# Update mirrorlist based on speed
sudo reflector --verbose --latest 5 --country 'United States' --protocol https --sort rate --save /etc/pacman.d/mirrorlist
# Enable parallel downloads and color
# Backup pacman config
sudo cp /etc/pacman.conf /etc/pacman.conf.backup
# Make sure there is at least one line that starts with ParallelDownloads
#if
# Comment out any lines that start with ParallelDownloads
sudo sed -i 's/^ParallelDownloads/#ParallelDownloads/' /etc/pacman.conf
# Replace first line that starts with #ParallelDownloads with ParallelDownloads = 5
# Within 0 to first line starting with X, replace line starting with X with Y
sudo sed -i '0,/^#ParallelDownloads/{s/^#ParallelDownloads.*/ParallelDownloads = 5/}' /etc/pacman.conf
# Comment out any lines that start with Color
sudo sed -i 's/^Color/#Color/' /etc/pacman.conf
# Replace first line that starts with #Color with Color
# Within 0 to first line starting with X, replace line starting with X with Y
sudo sed -i '0,/^#Color/{s/^#Color.*/Color/}' /etc/pacman.conf
# Needed for paru installation
sudo pacman -S --needed git rustup
rustup toolchain install stable
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
cd ..
rm -r paru
# Speed up compiling with multithreading
# Backup makepkg config
sudo cp /etc/makepkg.conf /etc/makepkg.conf.backup
# Comment out any lines that start with MAKEFLAGS
sudo sed -i 's/^MAKEFLAGS/#MAKEFLAGS/' /etc/makepkg.conf
# Replace first line that starts with #MAKEFLAGS with MAKEFLAGS="-j8"
# Within 0 to first line starting with X, replace line starting with X with Y
sudo sed -i '0,/^#MAKEFLAGS/{s/^#MAKEFLAGS.*/MAKEFLAGS="-j8"/}' /etc/makepkg.conf
# Add directories to $PATH so installation doesn't have errors with cuda nvcc
export PATH="$PATH:/opt/cuda/bin:/opt/cuda/nsight_compute:/opt/cuda/nsight_systems/bin"
NORM="
obs-studio (streaming & screen recording)
libjxl (JPEG-XL support)
gimp (Image editor)
openvpn (Connect to VPNs)
networkmanager-openvpn (For plasma GUI VPN support)
smplayer (Media player)
steam (Video game service)
colord-kde (Allows monitor color profiles in Plasma System Settings after restart)
kitty (Terminal)
kate (Text editor)
ntfs-3g (Manage ntfs partitions)
nomacs (Image Viewer)
gwenview (Image Viewer)
qt5-imageformats (Support for additional image formats)
kimageformats (Support for additional image formats)
shotcut (Video editor)
wqy-zenhei (Asian fonts)
wine (Run Windows games and programs)
lutris (Run Windows games and programs)
filelight (Show what files/folders use most space)
spectacle (Screenshot tool)
"
# From: https://www.gloriouseggroll.tv/how-to-get-out-of-wine-dependency-hell/
EGG1="wine-staging winetricks giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader cups samba dosbox"
# From: https://github.com/lutris/docs/blob/master/InstallingDrivers.md
EGG2="lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader"
# Install with all optional dependencies
WOPT="
yt-dlp (Download YouTube videos and music, also works for other websites)
okular (PDF, ODT, and ODP viewer)
"
AUR="
qbittorrent-enhanced (torrenting client)
spotify (music player)
svt-av1-git (AV1 video encoding)
ffmpeg-full (Media encoding, reload environment variables to fix nvcc error)
bottles (Run Windows games and programs)
"
for I in ${opt_pkgs[@]}; do
    OPT_PKGS_STR+="$I "
done
paru -S --needed "$NORM $EGG1 $EGG2 $WOPT $AUR"
paru -S --asdeps --needed "$OPT_PKGS_STR"
# Disable clipboard history in "Configure System Tray" (Right click System Tray arrow)
# Disable recent file history in System Settings > Workspace Behavior > Activities > Privacy
