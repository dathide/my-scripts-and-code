#!/usr/bin/env bash
#
# Arch Linux Installation Script for Btrfs with Snapshots
#
# Author: Gemini
# Date: 2025-06-11
#
# DESCRIPTION:
# This script automates the installation of Arch Linux on a specific device.
# It is designed to be non-destructive to existing partitions, using only the
# last available block of free space on the target disk.
#
# FEATURES:
# - Targets a single device passed as an argument (e.g., /dev/nvme0n1).
# - Validates that sufficient free space (151 GiB) is available.
# - Creates a 1 GiB EFI System Partition (ESP) and a 150 GiB Btrfs root partition.
# - Sets up Btrfs with zstd compression and the following subvolumes:
#   - @         (for /)
#   - @home     (for /home)
#   - @log      (for /var/log)
#   - @pkg      (for /var/cache/pacman/pkg)
#   - @snapshots (for Btrfs snapshots)
#   - @swap     (for a swapfile)
# - Configures an 8GB swapfile using specific btrfs commands.
# - Installs and configures GRUB with grub-btrfs for bootable snapshots.
# - Sets up an ALPM hook to automatically create snapshots on system updates
#   (via pacman or yay) and prunes old snapshots, keeping the last 5.
# - Installs a minimal KDE Plasma (Wayland) desktop environment.
# - Installs essential packages: yay, pipewire, tuned, firefox, kitty, nano, dolphin.
# - Creates a user 'zen' with password '1234'.
# - Sets the root password to '1234'.
# - Sets the hostname to 'arch'.
# - Configures makepkg.conf to use 12 threads for compilation.
#
# USAGE:
# Ensure you have a working internet connection.
# Run this script as root:
#   ./install_arch.sh /dev/sdX
#   or
#   ./install_arch.sh /dev/nvme0n1
#
# WARNING:
# While this script is designed to be safe, you are responsible for your data.
# Always double-check the target device name. This script is provided as-is.

# --- Strict Mode & Initial Checks ---
set -eo pipefail # Exit on error, pipe failures

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

if [[ -z "$1" ]]; then
  echo "Usage: $0 /dev/device"
  echo "Example: $0 /dev/nvme0n1"
  exit 1
fi

DEVICE="$1"
if [[ ! -b "${DEVICE}" ]]; then
  echo "Error: Device ${DEVICE} is not a block device."
  exit 1
fi

# --- Configuration Variables ---
EFI_SIZE="1GiB"
ROOT_SIZE="150GiB"
TOTAL_REQUIRED_GIB=151 # 1 GiB for EFI + 150 GiB for root

ROOT_LABEL="ARCH_BTRFS"
HOSTNAME="arch"
USERNAME="zen"
PASSWORD="1234"
TIMEZONE="America/Phoenix" # Change if needed
LOCALE="en_US.UTF-8"
MAKEFLAGS_THREADS=12

# --- Helper Functions ---
info() {
  echo -e "\e[34m[INFO]\e[0m $1"
}

success() {
  echo -e "\e[32m[SUCCESS]\e[0m $1"
}

warn() {
  echo -e "\e[33m[WARNING]\e[0m $1"
}

error() {
  echo -e "\e[31m[ERROR]\e[0m $1" >&2
  exit 1
}

# --- 1. Pre-Installation Setup ---
info "Starting Arch Linux installation on ${DEVICE}"
info "Synchronizing system clock..."
timedatectl set-ntp true

# --- 2. Partitioning ---
info "Analyzing partitions on ${DEVICE}..."

# Get the last free space block information (Start and Size)
# We use MiB for parted calculations as it's more precise
FREE_SPACE_INFO=$(parted --script "${DEVICE}" print free | grep "Free Space" | tail -n 1)
if [[ -z "${FREE_SPACE_INFO}" ]]; then
    error "Could not find any free space on ${DEVICE}."
fi

FREE_SPACE_START_MIB=$(echo "${FREE_SPACE_INFO}" | awk '{print $1}' | sed 's/MiB//')
FREE_SPACE_SIZE_MIB=$(echo "${FREE_SPACE_INFO}" | awk '{print $3}' | sed 's/MiB//')
FREE_SPACE_SIZE_GIB=$(echo "scale=2; ${FREE_SPACE_SIZE_MIB} / 1024" | bc)

info "Last free space block found: ${FREE_SPACE_SIZE_GIB} GiB starting at ${FREE_SPACE_START_MIB}MiB."

# Check if there is enough space
if (( $(echo "${FREE_SPACE_SIZE_GIB} < ${TOTAL_REQUIRED_GIB}" | bc -l) )); then
    error "Not enough free space. Required: ${TOTAL_REQUIRED_GIB} GiB, Available: ${FREE_SPACE_SIZE_GIB} GiB."
fi

success "Sufficient free space confirmed."

# Calculate partition boundaries in MiB
EFI_START=${FREE_SPACE_START_MIB}
EFI_END=$(echo "${EFI_START} + 1024" | bc) # 1GiB = 1024MiB
ROOT_START=${EFI_END}
ROOT_END=$(echo "${ROOT_START} + (150 * 1024)" | bc) # 150GiB = 150 * 1024MiB

info "Creating partitions..."
info " -> EFI Partition:   ${EFI_START}MiB - ${EFI_END}MiB"
info " -> Root Partition:  ${ROOT_START}MiB - ${ROOT_END}MiB"

# Use parted to create the partitions non-interactively
parted --script --align optimal "${DEVICE}" -- \
  mkpart "ESP" fat32 "${EFI_START}MiB" "${ROOT_START}MiB" \
  set $(parted "${DEVICE}" print | tail -n 2 | head -n 1 | awk '{print $1}') esp on \
  mkpart "Linux-BTRFS" btrfs "${ROOT_START}MiB" "${ROOT_END}MiB"

# Give the kernel a moment to recognize the new partitions
sleep 3

# Find partition names
PARTPROBE_OUTPUT=$(partprobe -s "${DEVICE}")
EFI_PARTITION=$(lsblk -lno NAME,PARTLABEL | grep "ESP" | awk '{print "/dev/"$1}')
ROOT_PARTITION=$(lsblk -lno NAME,PARTLABEL | grep "Linux-BTRFS" | awk '{print "/dev/"$1}')

if [[ -z "${EFI_PARTITION}" || -z "${ROOT_PARTITION}" ]]; then
  error "Failed to identify new partitions. Partprobe output: ${PARTPROBE_OUTPUT}"
fi

success "Partitions created successfully:"
info " -> EFI:   ${EFI_PARTITION}"
info " -> Root:  ${ROOT_PARTITION}"

# --- 3. Formatting and Mounting Btrfs Subvolumes ---
info "Formatting partitions..."
mkfs.fat -F32 "${EFI_PARTITION}"
mkfs.btrfs -f -L "${ROOT_LABEL}" "${ROOT_PARTITION}"
success "Formatting complete."

info "Setting up Btrfs subvolumes..."
mount -t btrfs LABEL="${ROOT_LABEL}" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@swap

umount /mnt
success "Btrfs subvolumes created."

info "Mounting file systems..."
BTRFS_OPTS="rw,noatime,compress=zstd,ssd,space_cache=v2,discard=async"

mount -o subvol=@,${BTRFS_OPTS} LABEL="${ROOT_LABEL}" /mnt

# Create mount points for other subvolumes
mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,.snapshots,swap}

mount -o subvol=@home,${BTRFS_OPTS} LABEL="${ROOT_LABEL}" /mnt/home
mount -o subvol=@log,${BTRFS_OPTS} LABEL="${ROOT_LABEL}" /mnt/var/log
mount -o subvol=@pkg,${BTRFS_OPTS} LABEL="${ROOT_LABEL}" /mnt/var/cache/pacman/pkg
mount -o subvol=@snapshots,${BTRFS_OPTS} LABEL="${ROOT_LABEL}" /mnt/.snapshots
mount -o subvol=@swap,rw,noatime,nodatacow LABEL="${ROOT_LABEL}" /mnt/swap

# Mount EFI partition
mount "${EFI_PARTITION}" /mnt/boot
success "All file systems mounted."

# --- 4. Swap File Setup ---
info "Creating 8GB swap file..."
# Using the exact commands requested by the user
btrfs filesystem mkswapfile --size 8g --uuid clear /mnt/swap/swapfile
swapon /mnt/swap/swapfile
success "Swap file created and activated."

# --- 5. Base System Installation ---
info "Installing base system (this may take a while)..."
pacstrap -K /mnt base base-devel linux linux-firmware linux-headers \
                btrfs-progs grub efibootmgr networkmanager nano git \
                tuned pipewire pipewire-pulse pipewire-jack pipewire-alsa \
                wireplumber plasma-meta konsole dolphin firefox kitty \
                noto-fonts noto-fonts-cjk noto-fonts-emoji \
                nvidia nvidia-utils

success "Base system and packages installed."

# --- 6. System Configuration (fstab) ---
info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Add swapfile entry to fstab as requested
info "Adding swapfile entry to fstab..."
echo "/swap/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
success "fstab configured."

# --- 7. Snapshot System Setup ---
info "Configuring automated snapshot system..."

# a) Create the snapshot script
cat << 'EOF' > /mnt/usr/local/bin/grub-snapshot
#!/bin/bash
#
# Creates a BTRFS snapshot and prunes old ones.
# Triggered by an ALPM hook.

# Create a read-only snapshot
/usr/bin/btrfs subvolume snapshot -r / /.snapshots/snapshot-$(date +%Y%m%d-%H%M%S)

# Prune old snapshots, keeping the 5 most recent
pushd /.snapshots > /dev/null
ls -t | tail -n +6 | xargs -r btrfs subvolume delete
popd > /dev/null
EOF

chmod +x /mnt/usr/local/bin/grub-snapshot

# b) Create the ALPM hook to trigger snapshotting and update grub
# We use grub-btrfs, which automatically finds snapshots when grub-mkconfig is run.
# It must be installed inside the chroot.
cat << 'EOF' > /mnt/etc/pacman.d/hooks/99-grub-snapshot.hook
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Package
Target = *

[Action]
Description = Creating BTRFS snapshot and updating GRUB...
When = PostTransaction
Exec = /bin/bash -c "/usr/local/bin/grub-snapshot && grub-mkconfig -o /boot/grub/grub.cfg"
Depends = btrfs-progs
Depends = grub-btrfs
EOF

success "Snapshot hooks and scripts created."


# --- 8. Chroot and Final Configuration ---
info "Chrooting into new system to perform final setup..."
arch-chroot /mnt /bin/bash <<EOF

# --- Inside Chroot ---
set -eo pipefail

info() {
  echo -e "\e[34m[CHROOT-INFO]\e[0m \$1"
}

success() {
  echo -e "\e[32m[CHROOT-SUCCESS]\e[0m \$1"
}

info "Setting timezone to ${TIMEZONE}..."
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

info "Setting locale..."
echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

info "Setting hostname..."
echo "${HOSTNAME}" > /etc/hostname
cat <<EOT > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOT

info "Setting root password..."
echo "root:${PASSWORD}" | chpasswd
success "Root password set to '${PASSWORD}'"

info "Creating user '${USERNAME}'..."
useradd -m -G wheel -s /bin/bash ${USERNAME}
echo "${USERNAME}:${PASSWORD}" | chpasswd
success "User '${USERNAME}' created with password '${PASSWORD}'"

info "Granting sudo privileges to wheel group..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL$/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

info "Configuring makepkg for ${MAKEFLAGS_THREADS} threads..."
sed -i "s/^#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j${MAKEFLAGS_THREADS}\"/" /etc/makepkg.conf
sed -i 's/^COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z - -T0)/' /etc/makepkg.conf


info "Installing GRUB bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
success "GRUB installed."

info "Installing grub-btrfs for snapshot booting..."
# We need to build this from the AUR. Do this as the normal user.
# First, ensure yay dependencies are met. We already installed git and base-devel.
sudo -u ${USERNAME} bash -c "cd /home/${USERNAME} && git clone https://aur.archlinux.org/grub-btrfs.git && cd grub-btrfs && makepkg -si --noconfirm"
success "grub-btrfs installed."

info "Generating initial GRUB config..."
# Running this will now pick up the grub-btrfs entries.
grub-mkconfig -o /boot/grub/grub.cfg
success "GRUB config generated."

info "Installing yay AUR helper..."
sudo -u ${USERNAME} bash -c "cd /home/${USERNAME} && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm"
# Clean up build directories
rm -rf /home/${USERNAME}/yay /home/${USERNAME}/grub-btrfs
success "yay installed."


info "Enabling essential system services..."
systemctl enable NetworkManager
systemctl enable sddm # Display manager for Plasma
systemctl enable tuned
systemctl enable fstrim.timer # For SSDs
systemctl enable bluetooth # For Spectre laptop
success "Services enabled."

info "Chroot setup complete. Exiting chroot."
# --- End of Chroot ---
EOF

# --- 9. Unmount and Finish ---
info "Unmounting all partitions..."
umount -R /mnt

success "Installation complete!"
echo
echo "------------------------------------------------------------------"
echo " PLEASE REBOOT YOUR SYSTEM NOW"
echo " You can do this by typing: reboot"
echo
echo " After rebooting, log in as user '${USERNAME}' with password '${PASSWORD}'."
echo " It is strongly recommended to change both user and root passwords immediately."
echo "------------------------------------------------------------------"

exit 0
