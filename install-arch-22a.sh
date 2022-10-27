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

# This function will run after arch-chrooting into the new system
func_chroot () {
    sed -i '0,/^#ParallelDownloads/{s/^#ParallelDownloads.*/ParallelDownloads = 3/}' /etc/pacman.conf
    pacman -S --needed base-devel git btrfs-progs dosfstools exfatprogs f2fs-tools e2fsprogs jfsutils nilfs-utils ntfs-3g reiserfsprogs udftools xfsprogs kitty firefox man-db man-pages texinfo xorg-xwayland nvidia nvidia-utils nvidia-settings plasma plasma-wayland-session egl-wayland pipewire wireplumber pipewire-pulse ark dolphin dolphin-plugins dragon elisa ffmpegthumbs filelight gwenview kate kcalc kdegraphics-thumbnailers kdenlive kdesdk-kio kdesdk-thumbnailers kfind khelpcenter konsole ksystemlog okular spectacle htop btop nvtop chromium lynx
    ln -sf /usr/share/zoneinfo/America/Phoenix /etc/localtime
    hwclock --systohc
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf
    echo "KEYMAP=us" >> /etc/vconsole.conf
    echo "arch" >> /etc/hostname
    systemctl enable NetworkManager
    passwd
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
    # Prevent /var/log/journal from getting large
    sed -i '0,/^#SystemMaxUse=/{s/^#SystemMaxUse=.*/SystemMaxUse=200M/}' /etc/systemd/journald.conf
    # Configure sudo
    sudo echo "sudo initialization for /etc/sudoers creation"
    sed -i '0,/^# %wheel ALL=(ALL:ALL) ALL/{s/^# %wheel ALL=(ALL:ALL) ALL.*/%wheel ALL=(ALL:ALL) ALL/}' /etc/sudoers
    # Install paru-bin
    P1="/home/$UNAME/.cache/paru/clone/paru-bin" ; sudo -u $UNAME git clone https://aur.archlinux.org/paru-bin.git "$P1"
    cd "$P1" ; sudo -u $UNAME makepkg -si ; cd /root
    sudo -u $UNAME paru -S nvidia-vaapi-driver-git spotify
    # Set system-wide environment variables https://github.com/elFarto/nvidia-vaapi-driver
    arr_envvars=("LIBVA_DRIVER_NAME=nvidia" "MOZ_DISABLE_RDD_SANDBOX=1" "EGL_PLATFORM=wayland" "MOZ_X11_EGL=1" "MOZ_ENABLE_WAYLAND=1")
    printf "%s\n" "${arr_envvars[@]}" >> /etc/environment
    # System-wide firefox config https://support.mozilla.org/en-US/kb/customizing-firefox-using-autoconfig
    echo 'pref("general.config.filename", "firefox.cfg");' >> /usr/lib/firefox/defaults/pref/autoconfig.js
    echo 'pref("general.config.obscure_value", 0);' >> /usr/lib/firefox/defaults/pref/autoconfig.js
    # Change firefox settings to https://github.com/elFarto/nvidia-vaapi-driver
    arr_cfg=('//'
    'lockPref("media.ffmpeg.vaapi.enabled", true);'
    'lockPref("media.rdd-ffmpeg.enabled", true);'
    'lockPref("media.av1.enabled", true);'
    'lockPref("gfx.x11-egl.force-enabled", true);'
    'lockPref("gfx.webrender.all", true);')
    printf "%s\n" "${arr_cfg[@]}" > /usr/lib/firefox/firefox.cfg
    # Download Firefox addons
    P1="/usr/lib/firefox/distribution/extensions" ; mkdir -p "$P1" ; cd "$P1"
    arr_links=("$(lynx -dump -listonly https://addons.mozilla.org/en-US/firefox/addon/bitwarden-password-manager/ | grep '.xpi' | awk '{print $2}')"
    "$(lynx -dump -listonly https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/ | grep '.xpi' | awk '{print $2}')")
    exit # Leave arch-chroot
}
export -f func_chroot


sed -i '0,/^#ParallelDownloads/{s/^#ParallelDownloads.*/ParallelDownloads = 3/}' /etc/pacman.conf
loadkeys en
timedatectl status
# Line only exists if first partition is flagged as bootable
EFI1=$( fdisk -lu | grep "EFI System" | grep "$1" )
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
    pacstrap -K /mnt base linux linux-firmware amd-ucode sudo nano zsh networkmanager
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
