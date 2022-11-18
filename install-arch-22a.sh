#!/bin/bash
# After booting into Arch Linux iso using Ventoy, run these commands:
# pacman -Sy git
# git clone http://github.com/dathide/archstuff
# /bin/bash archstuff/<this script> /dev/nvme0n1p# /dev/nvme0n1p#

export UNAME="sapien"
export OS_NAME="arch2"
export OS_SUBVOL="subvol_${OS_NAME}_fsroot"
# This UUID and subvol should exist prior to running this script
export SSD_UUID="487b8741-9f8d-45bc-9f4e-0436d7f25e10"
export SUBV_PACMAN="subvol_var_cache_pacman_pkg"
export PACSTRP='base linux linux-firmware amd-ucode sudo nano zsh networkmanager git'
export PKG_FS='btrfs-progs dosfstools exfatprogs f2fs-tools e2fsprogs jfsutils nilfs-utils ntfs-3g reiserfsprogs udftools xfsprogs'
# From https://github.com/lutris/docs/blob/master/InstallingDrivers.md https://www.gloriouseggroll.tv/how-to-get-out-of-wine-dependency-hell/
export PKG_NVIDIA='nvidia nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader wine-staging winetricks giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader cups samba dosbox'

export PKG_MAN='base-devel kitty firefox man-db man-pages texinfo xorg-xwayland plasma plasma-wayland-session egl-wayland pipewire wireplumber pipewire-pulse ark dolphin dolphin-plugins dragon elisa ffmpegthumbs filelight gwenview kate kcalc kdegraphics-thumbnailers kdenlive kdesdk-kio kdesdk-thumbnailers kfind khelpcenter konsole ksystemlog okular spectacle htop btop nvtop chromium lynx yt-dlp jre17-openjdk flatpak openvpn networkmanager-openvpn libreoffice-fresh lutris tealdeer obs-studio wqy-zenhei unrar kdeconnect sshfs docker docker-compose rustup qt6-wayland'

export AUR='nvidia-vaapi-driver-git spotify prismlauncher-bin qbittorrent-enhanced-qt5 ttf-ms-fonts protonup-qt-bin nvidia-container-toolkit nerd-fonts-complete glfw-wayland-minecraft'

export FLATPAK='smplayer'

# This function will run after arch-chrooting into the new system
func_chroot () {
    hwclock --systohc
    echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
    echo 'ja_JP.UTF-8 UTF-8' >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf
    echo "KEYMAP=us" >> /etc/vconsole.conf
    echo "arch" >> /etc/hostname
    passwd
    sed -i '/^#ParallelDownloads/!b;cParallelDownloads = 3' /etc/pacman.conf
    sed -i '/^#Color/!b;cColor' /etc/pacman.conf # Replace line that starts with #Color with Color
    sed -i '/^#\[multilib\]/!b;c\[multilib\]' /etc/pacman.conf
    # Find line that starts with [multilib], replace next line with Include ...
    sed -i '/^\[multilib\]/!b;n;cInclude = /etc/pacman.d/mirrorlist' /etc/pacman.conf
    ln -sf /usr/share/zoneinfo/America/Phoenix /etc/localtime
    bootctl --path=/boot install
    arr_entry1=(
    "title     Arch Linux 22a"
    "linux     /vmlinuz-linux"
    "initrd    /amd-ucode.img"
    "initrd    /initramfs-linux.img"
    "options   root=\"LABEL=$OS_NAME\" rootfstype=btrfs rootflags=subvol=subvol_${OS_NAME}_fsroot rw nvidia_drm.modeset=1")
    printf "%s\n" "${arr_entry1[@]}" > /boot/loader/entries/arch.conf
    arr_entry2=(
    "title     Arch Linux 22a Fallback"
    "linux     /vmlinuz-linux"
    "initrd    /amd-ucode.img"
    "initrd    /initramfs-linux-fallback.img"
    "options   root=\"LABEL=$OS_NAME\" rootfstype=btrfs rootflags=subvol=subvol_${OS_NAME}_fsroot rw nvidia_drm.modeset=1")
    printf "%s\n" "${arr_entry2[@]}" > /boot/loader/entries/arch-fallback.conf
    arr_loader=("default arch" "timeout 4" "console-mode auto" "editor no")
    printf "%s\n" "${arr_loader[@]}" > /boot/loader/loader.conf
    bootctl --path=/boot update
    useradd -m -G "wheel" -s /bin/zsh $UNAME
    sudo -u $UNAME mkdir -p /home/$UNAME/ssd1
    passwd $UNAME
    # Configure sudo
    sudo -u $UNAME echo "sudo initialization for /etc/sudoers creation"
    sed -i '0,/^# %wheel ALL=(ALL:ALL) ALL/{s/^# %wheel ALL=(ALL:ALL) ALL.*/%wheel ALL=(ALL:ALL) ALL/}' /etc/sudoers
    # Install paru-bin
    P1="/home/$UNAME/.cache/paru/clone/paru-bin" ; sudo -u $UNAME git clone https://aur.archlinux.org/paru-bin.git "$P1"
    cd "$P1" ; sudo -u $UNAME makepkg -si ; cd /root
    # Install packages
    sudo -u $UNAME paru -S --needed "$PKG_FS $PKG_NVIDIA $PKG_MAN $AUR"
    systemctl enable NetworkManager
    systemctl enable docker
    # Prevent /var/log/journal from getting large
    sed -i '0,/^#SystemMaxUse=/{s/^#SystemMaxUse=.*/SystemMaxUse=200M/}' /etc/systemd/journald.conf
    # Set system-wide environment variables https://github.com/elFarto/nvidia-vaapi-driver
    arr_envvars=("LIBVA_DRIVER_NAME=nvidia" "MOZ_DISABLE_RDD_SANDBOX=1" "EGL_PLATFORM=wayland" "MOZ_X11_EGL=1" "MOZ_ENABLE_WAYLAND=1" 'MAKEFLAGS="-j12"' 'EDITOR=nano')
    printf "%s\n" "${arr_envvars[@]}" >> /etc/environment
    source /etc/environment
    #flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak --user install "$FLATPAK"
    # System-wide firefox config https://support.mozilla.org/en-US/kb/customizing-firefox-using-autoconfig
    echo 'pref("general.config.filename", "firefox.cfg");' >> /usr/lib/firefox/defaults/pref/autoconfig.js
    echo 'pref("general.config.obscure_value", 0);' >> /usr/lib/firefox/defaults/pref/autoconfig.js
    # Change firefox settings to https://github.com/elFarto/nvidia-vaapi-driver
    arr_cfg=('//'
    'lockPref("media.ffmpeg.vaapi.enabled", true);'
    'lockPref("media.rdd-ffmpeg.enabled", true);'
    'lockPref("media.av1.enabled", true);'
    'lockPref("gfx.x11-egl.force-enabled", true);'
    'lockPref("gfx.webrender.all", true);'
    'lockPref("widget.use-xdg-desktop-portal.file-picker", 1);'
    'lockPref("widget.use-xdg-desktop-portal.mime-handler", 1);')
    printf "%s\n" "${arr_cfg[@]}" > /usr/lib/firefox/firefox.cfg
    ### Install Firefox addons https://support.mozilla.org/en-US/kb/deploying-firefox-with-extensions
    P1="/usr/lib/firefox/distribution/extensions" ; mkdir -p "$P1" ; cd "$P1"
    # Bitwarden, uBlock Origin, Add custom search engine, BetterTTV, CanvasBlocker, Decentraleyes, Don't track me Google, HTTPS Everywhere, Image Search Options, Instagram Photo Plus, Return YouTube Dislike, Singlefile, SponsorBlock, Twitch Adblock, TWP - Translate Web Pages
    # Grab direct download links from Mozilla webpages
    arr_links=("$(lynx -dump -listonly https://addons.mozilla.org/en-US/firefox/addon/bitwarden-password-manager/ | grep '.xpi' | awk '{print $2}')"
    "$(lynx -dump -listonly https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/ | grep '.xpi' | awk '{print $2}')")
    echo 'Enabled=false' >> /home/$UNAME/.config/kwalletrc # Disable kwallet and its annoying popups
    tldr -u # Update tealdeer cache
    # Configure the kitty terminal
    kitty=('font_family Iosevka Term' 'font_size 13.0')
    printf "%s\n" "${kitty[@]}" >> "/home/$UNAME/.config/kitty/kitty.conf"
    rustup toolchain install stable
    exit # Leave arch-chroot
}
export -f func_chroot


sed -i '/^#ParallelDownloads/!b;cParallelDownloads = 3' /etc/pacman.conf
sed -i '/^#Color/!b;cColor' /etc/pacman.conf
loadkeys en
timedatectl status
# Line only exists if first partition is flagged as bootable
EFI1=$(fdisk -lu | grep "EFI System" | grep "$1")
# Confirm with user so they can double check what partitions they are formatting
read -p "Format $1 (boot) and $2? " -n 1 -r
echo #New line
# Proceed only if reply is y or Y, system is in EFI mode, and first partition is flagged as bootable
if [[ $REPLY =~ ^[Yy]$ ]] && [ -d "/sys/firmware/efi/efivars" ] && [ ${#EFI1} -ge 1 ]; then
    mkfs.fat -F 32 $1
    fatlabel $1 "BOOT7"
    mkfs.btrfs -f -L $OS_NAME $2
    mount -m $2 /root/btrfs
    btrfs subvolume create "/root/btrfs/$OS_SUBVOL"
    umount /root/btrfs
    mount -m -o "subvol=$OS_SUBVOL,rw,noatime,compress-force=zstd:3,noautodefrag" $2 /mnt
    mount -m -o "subvol=$SUBV_PACMAN,rw,noatime,noautodefrag" "UUID=$SSD_UUID" /mnt/var/cache/pacman/pkg
    mount -m $1 /mnt/boot
    pacstrap -K /mnt "$PACSTRP"
    arr_fstab=("# fsroot LABEL=$OS_NAME $2"
    "UUID=$(blkid -o value -s UUID $2)   /   btrfs   rw,noatime,compress-force=zstd:3,subvol=$OS_SUBVOL   0 0"
    "# boot partition $1"
    "UUID=$(blkid -o value -s UUID $1)  /boot  vfat  rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro   0 2"
    "# pacman cache"
    "UUID=$SSD_UUID   /var/cache/pacman/pkg   btrfs   rw,noatime,subvol=$SUBV_PACMAN   0 0"
    "# ssd1 main subvolume"
    "UUID=$SSD_UUID   /home/$UNAME/ssd1   btrfs   rw,noatime,compress-force=zstd:3,subvol=SubVol_SSD1   0 0")
    printf "%s\n" "${arr_fstab[@]}" >> /mnt/etc/fstab
    arch-chroot /mnt /bin/bash -c "func_chroot"
fi
# From https://wiki.archlinux.org/title/KDE#From_the_console
# To start a wayland session: startplasma-wayland
