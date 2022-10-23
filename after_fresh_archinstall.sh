#!/bin/bash
cd /home/$USER
# Configure sudo
sudo EDITOR=/bin/nano visudo -f /etc/sudoers.d/00_sapien
# Add these lines
Defaults editor=/bin/nano
Defaults timestamp_timeout=30
# Probe for hardware to find good kernel modules to load for sensors
# Just keep pressing enter to use the defaults
sudo sensors-detect
# Add user to all groups from https://wiki.archlinux.org/title/users_and_groups#User_groups
grps=("$USER" "wheel" "adm" "ftp" "games" "http" "log" "rfkill" "sys" "systemd-journal" "uucp" "power" "network" "vboxusers")
for grp in ${grps[@]}; do gpasswd -a $USER $grp; done
# Might break system permissions, causing a lot of problems
#echo 'polkit.addRule(function(action, subject) {
#  if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 && subject.isInGroup("network")) {
#    return polkit.Result.YES;
#  }
#});' | sudo tee -a /etc/polkit-1/rules.d/50-org.freedesktop.NetworkManager.rules
# Update mirrorlist based on speed
sudo reflector --verbose --latest 5 --country 'United States' --protocol https --sort rate --save /etc/pacman.d/mirrorlist
# Enable parallel downloads and color
# Backup pacman config
sudo cp /etc/pacman.conf /etc/pacman.conf.backup
# Make sure there is at least one line that starts with ParallelDownloads
# NEED TO ADD HANDLING IF THERE ISN'T A LINE STARTING WITH X
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
# Make sudoedit use nano
export EDITOR=nano
echo "export EDITOR=nano" >> /home/$USER/.bashrc
# Needed for paru installation
sudo pacman -S --needed git rustup
rustup toolchain install stable
git clone https://aur.archlinux.org/paru-bin.git
cd paru-bin
makepkg -si
cd ..
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
# Set up gpg key for tor-browser (AUR)
gpg --auto-key-locate nodefault,wkd --locate-keys torbrowser@torproject.org
pkgs1=(
    "obs-studio" # streaming & screen recording
    "libjxl" # JPEG-XL support
    "gimp" # Image editor
    "openvpn" # Connect to VPNs
    "networkmanager-openvpn" # For plasma GUI VPN support
    "smplayer" # Media player
    "steam" # Video game service
    "colord-kde" # Monitor color profiles in Plasma System Settings after restart
    "kitty" # GPU-accelerated terminal
    "kate" # Text editor
    "ntfs-3g" # Manage ntfs partitions
    "nomacs" # Image Viewer
    "gwenview" # Image Viewer
    "qt5-imageformats" # Support for image formats TIFF, MNG, TGA, WBMP
    "kdesdk-thumbnailers" # Plugins for Dolphin's thumbnailing system
    "shotcut" # Video editor
    "wqy-zenhei" # Asian fonts
    "lutris" # Run Windows games and programs
    "filelight" # Show what files/folders use most space
    "spectacle" # Screenshot tool
    "unrar" # Unpack .zip files
    "kfind" # Search for files
    "scons" # For building Godot
    "helvum" # Recording only game audio
    "jdk17-openjdk" # For running Minecraft
    "avidemux-qt" # Video editor
    "libreoffice" # Document editor
    "ffmpegthumbs" # Video thumbnails in Dolphin
    "reflector" # Can sort Arch mirrors by speed
    "vlc" # Video player
    "lmms" # Audio editor
    "kdialog" # KDE dialog boxes
    "rsync" # Mirror directories
    "flatpak" # Way to install applications
    "xdg-desktop-portal-gtk" # Flatpak desktop integration
    "strawberry" # Music player
    "gstreamer-vaapi" # OBS Studio screen recording with AMD GPUs
    "gvfs" # Bottles optional dependency
    "vkd3d" # Bottles optional dependency
    "lib32-vkd3d" # Bottles optional dependency
    "gamemode" # Bottles optional dependency
    "gparted" # Manage disk partitions
    "btop" # Show System utilization in terminal
    "man-db" # Viewing software manuals in the console
    "bottom" # Monitor system stats in terminal, btm -b
    "grade" # Build Minecraft fabric mods
    "gnome-clocks" # Clock with world times, alarms, a stopwatch, and a timer
    "tealdeer" # Easily check how to use a command through tldr <command>
    "nvidia" # Support for NVIDIA GPUs
    "glances" # System monitor, including temperature
    "hddtemp" # Used by glances for HDD temperatures
    "matplotlib" # Used by glances to make graphs
    "python-pip" # Used to easily install Python packages
    "blender" # Create 3D models
    "docker" # Reproducible build environments
    "docker-compose" # Reproducible build environments
    "pacman-contrib" # Used for cleaning the package cache
    "nvtop" # Like htop but for NVIDIA GPUs
    "krita" # Digital painting, image editor
    "qpwgraph" # GUI to configure audio streams like Helvum. Capture only game audio.
)
# From: https://www.gloriouseggroll.tv/how-to-get-out-of-wine-dependency-hell/
pkgs2="wine-staging winetricks giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader cups samba dosbox"
# From: https://github.com/lutris/docs/blob/master/InstallingDrivers.md
pkgs3="lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader"
# From: https://docs.anaconda.com/anaconda/install/linux/
pkgs_anaconda="libxau libxi libxss libxtst libxcursor libxcomposite libxdamage libxfixes libxrandr libxrender mesa-libgl  alsa-lib libglvnd"
# Install with all optional dependencies
pkgs4=(
    "yt-dlp (Download YouTube videos and music, also works for other websites)"
    "okular (PDF, ODT, and ODP viewer)"
)
aur_pkgs=(
    "qbittorrent-enhanced (torrenting client)"
    "spotify (music player)"
    "bottles (Run Windows games and programs)"
    "gdlauncher-bin (Minecraft launcher with modpack support)"
    "tor-browser (Truly anonymous web browser)"
    "apple-fonts (Apple's fonts like SF Pro)"
    "otf-ibm-plex (Good fonts like IBM Plex Sans)"
    "nbtexplorer (Edit Minecraft files)"
    "obs-gstreamer (OBS Studio screen recording with AMD GPUs)"
    "obs-vkcapture-git (OBS Studio screen recording with AMD GPUs)"
    "obs-streamfx (More encoding options in OBS Studio)"
    "protonup-qt (Easily manage Proton GE installations)"
    "android-sdk-platform-tools (Used to install ReVanced)"
    "zulu-17-bin (Build of OpenJDK used to install ReVanced)"
    "kimageformats-git (Support for image formats JXL and more)"
    "corectrl (Control and monitor AMD GPUs)"
    "imagemagick-full (Create, edit, compose, and convert images, including jxl)"
    "heroic-games-launcher-bin (Play games from the Epic Games Store on Linux)"
    "ttf-ms-fonts (Fonts including Times New Roman)"
    "miniconda3 (Create python environments)"
    "nvidia-container-toolkit (Use NVIDIA GPUs with Docker)"
    "nvidia-vaapi-driver-git (Web browser hardware acceleration)"
    "ventoy-bin" # Make a bootable usb device with multiple .iso files on it
    "proton-ge-custom-bin" # Custom version of proton to use with Steam
    "librewolf-bin" # Custom version of Firefox
    "pollymc-bin" # Minecraft launcher with support for offline modpacks
)
# Old packages
# python-pytorch-cuda (Version didn't support RTX3090) (For running AI models with python -m venv --system-site-packages <name>)
custom_pkgs=(
    "svt-av1 (1.2.1)(AV1 video encoding)"
    "lensfun (2022.08.28)(Used by ffmpeg-full to identify cameras)"
    "libklvanc (2022.04.15)(Used by ffmpeg-full)"
    "uavs3d (2022.08.27)(Used by ffmpeg-full)"
    "ffmpeg-full (5.1.1-1)(Media encoding and decoding)"
)
for I in ${opt_pkgs[@]}; do
    # Make a string of the optional packages here
done
paru -S --needed "$NORM $EGG1 $EGG2 $WOPT $AUR"
paru -S --asdeps --needed "$OPT_PKGS_STR"
source /etc/profile.d/jre.sh
# Enable swap for better performance https://chrisdown.name/2018/01/02/in-defence-of-swap.html
sudo btrfs subvolume create /swap_subvol
sudo chattr +C /swap_subvol
sudo dd if=/dev/zero of=/swap_subvol/swapfile bs=1M count=512 status=progress
sudo chmod 0600 /swap_subvol/swapfile
sudo mkswap -U clear /swap_subvol/swapfile
sudo swapon /swap_subvol/swapfile
echo "/swap_subvol/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab
# Low tendency to use swap as emergency ram
sudo sysctl -w vm.swappiness=1
echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.d/99-swappiness.conf
# Improve file browsing performance https://rudd-o.com/linux-and-free-software/tales-from-responsivenessland-why-linux-feels-slow-and-how-to-fix-that
sudo sysctl -w vm.vfs_cache_pressure=50
echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.d/99-vfs_cache_pressure.conf
DIR1="drives"
mkdir ~/$DIR1
mdirs=("mnt_ssd1" "mnt_ssd2" "mnt_hdd")
for i in ${mdirs[@]}; do
    mkdir ~/$DIR1/$i
done
MOPTS="rw,noatime,compress-force=zstd:3,noautodefrag"
echo "UUID=487b8741-9f8d-45bc-9f4e-0436d7f25e10  /home/$USER/$DIR1/${mdirs[0]}  btrfs  $MOPTS  0 0" | sudo tee -a /etc/fstab
echo "UUID=25db5590-afc2-47d2-905e-3fcb5ca1fbd6  /home/$USER/$DIR1/${mdirs[1]}  btrfs  $MOPTS  0 0" | sudo tee -a /etc/fstab
echo "UUID=4c68160b-69d5-40bd-9f2f-f77ab47d9cb8  /home/$USER/$DIR1/${mdirs[2]}  btrfs  $MOPTS  0 0" | sudo tee -a /etc/fstab
#sudo btrfs quota disable ~/$i
# Symlinks s=symlink T=no target directory
ln -sT "/home/$USER/drives/mnt_ssd1/SubVol_SSD1" "/home/$USER/ssd1"
ln -sT "/home/$USER/drives/mnt_ssd1/SubVol_AoF5_Worlds" "/home/$USER/AoF5_Worlds"
ln -sT "/home/$USER/drives/mnt_ssd1/SubVol_AoF5_Worlds_Snapshots" "/home/$USER/AoF5_Worlds_Snapshots"
ln -sT "/home/$USER/drives/mnt_ssd2/SubVol_SSD2" "/home/$USER/ssd2"
ln -sT "/home/$USER/drives/mnt_hdd/SubVol_Downloads" "/home/$USER/Downloads"
ln -sT "/home/$USER/drives/mnt_hdd/SubVol_HDD1" "/home/$USER/hdd"
# Automatically improve ssd performance weekly
sudo systemctl enable fstrim.timer
sudo systemctl enable --now docker.service
# https://gitlab.com/corectrl/corectrl/-/wikis/Setup
cp /usr/share/applications/org.corectrl.corectrl.desktop ~/.config/autostart/org.corectrl.corectrl.desktop
# Breaks system permissions, causing a lot of problems
#echo "polkit.addRule(function(action, subject) {
#    if ((action.id == "org.corectrl.helper.init" ||
 #        action.id == "org.corectrl.helperkiller.init") &&
 #       subject.local == true &&
#        subject.active == true &&
#       subject.isInGroup(\"${USER}\")) {
 #           return polkit.Result.YES;
 #   }
#});" | sudo tee -a /etc/polkit-1/rules.d/90-corectrl.rules
sudo sed -i '/^options / s/$/amdgpu.ppfeaturemask=0xffffffff /' /boot/loader/entries/*_linux.conf
# To enable GPU monitoring in glances
pip install py3nvml
# miniconda3 setup
echo "[ -f /opt/miniconda3/etc/profile.d/conda.sh ] && source /opt/miniconda3/etc/profile.d/conda.sh" >> ~/.bashrc
echo 'export PATH="/home/$USER/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
# Firefox hardware acceleration https://github.com/elFarto/nvidia-vaapi-driver
echo "MOZ_X11_EGL=1" | sudo tee -a /etc/environment
echo "LIBVA_DRIVER_NAME=nvidia" | sudo tee -a /etc/environment
echo "MOZ_DISABLE_RDD_SANDBOX=1" | sudo tee -a /etc/environment

# Set up login script through System Settings with the following commands:
#bootctl disable
#sudo nvidia-smi -pl 315 (Sets GPU power limit)
#sudo mount -t tmpfs -o size=12G ram ~/ram

# Disable clipboard history in "Configure System Tray" (Right click System Tray arrow)
# Disable recent file history in System Settings > Workspace Behavior > Activities > Privacy
# Enable video previews in Dolphin settings
### Firefox Settings
# Uncheck "Allow websites to use their own font settings"
### Firefox about:config https://github.com/elFarto/nvidia-vaapi-driver
# media.ffmpeg.vaapi.enabled = true
# media.rdd-ffmpeg.enabled = true
# gfx.x11-egl.force-enabled = true

oldpkgs=(
    "amf-amdgpu-pro (AMD GPU video encoding for ffmpeg & OBS Studio)"
)
