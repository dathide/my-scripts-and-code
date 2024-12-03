#!/usr/bin/env bash

# To run the script:
# pacman -Sy git; git clone <url>; cd archstuff; ./<script>

arch_num="24" # Used in partition labeling
dev1="/dev/sdx"
dev1_boot="${dev1}n"
dev1_swap="${dev1}n"
dev1_root="${dev1}n"
btrfs_mops="noatime,discard=async,compress-force=zstd:4"

function handle_error() {
  local error_code=$?
  local error_line=${BASH_LINENO[0]}
  local error_command=$BASH_COMMAND
  echo "Error occurred on line $error_line: $error_command (exit code: $error_code)"
  exit 1
}

# Set the trap for any error (non-zero exit code)
trap handle_error ERR

# Maybe an if statement that checks if arch-chroot is active, so this part is skipped in arch-chroot?

# Ensure UEFI is 64-bit x64
if [[ $(cat /sys/firmware/efi/fw_platform_size) -eq 64 ]]; then echo "UEFI is 64-bit x64";
    else echo "UEFI is not 64-bit x64, checked in line $((LINENO - 1))"; exit 1
fi

ping -c 1 archlinux.org # Ensure internet connection

timedatectl # Ensure the system clock is synchronized

# Set partition types
sfdisk --part-type "$dev1" "${dev1_boot: -1}" EF # uefi
sfdisk --part-type "$dev1" "${dev1_swap: -1}" 82 # swap
sfdisk --part-type "$dev1" "${dev1_root: -1}" 83 # linux

# Format partitions
mkfs.fat -F 32 -n "ARCH${arch_num}B" "$dev1_boot"
mkswap "$dev1_swap"
mkfs.btrfs -L "arch${arch_num}r" "$dev1_root"

swapon "$dev1_swap" # Enable swap

# Make btrfs subvolumes
mount -o "$btrfs_mops" "$dev1_root" "/mnt"
subv1="subv_arch${arch_num}"
btrfs subvolume create "/mnt/${subv1}"
btrfs subvolume create "/mnt/${subv1}_snapshots"
btrfs subvolume create "/mnt/${subv1}_home"
btrfs subvolume create "/mnt/${subv1}_home_snapshots"
btrfs subvolume create "/mnt/${subv1}_var_cache_pacman_pkg"
umount "/mnt"

# Mount btrfs subvolumes
mount --mkdir -o "${btrfs_mops},subvol=${subv1}" "$dev1_root" "/mnt"
mount --mkdir -o "${btrfs_mops},subvol=${subv1}_snapshots" "$dev1_root" "/mnt/.snapshots"
mount --mkdir -o "${btrfs_mops},subvol=${subv1}_home" "$dev1_root" "/mnt/home"
mount --mkdir -o "${btrfs_mops},subvol=${subv1}_home_snapshots" "$dev1_root" "/mnt/home/.snapshots"
mount --mkdir -o "${btrfs_mops},subvol=${subv1}_var_cache_pacman_pkg" "$dev1_root" "/mnt/var/cache/pacman/pkg"

# Mount boot partition
mount --mkdir "$dev1_boot" "/mnt/boot"

# Symlink m2a/var-cache-pacman-pkg to live system's /var/cache/pacman/pkg
# which saves time downloading on repeat installs

# Change pacman.conf to enable parallel downloading

# Install packages
pacstrap -K /mnt base linux linux-firmware amd-ucode networkmanager nano git

# Generate the fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# Change root into the new system
arch-chroot /mnt

ls

# While in chroot

# Enable services
#systemctl enable NetworkManager.service
