ln -sf /usr/share/zoneinfo/America/Phoenix /etc/localtime
hwclock --systohc
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "archlinux" > /etc/hostname
echo "#<ip-address> <hostname.domain.org> <hostname>" > /etc/hosts
echo "127.0.0.1 archlinux.localdomain archlinux" >> /etc/hosts
echo "::1 localhost.localdomain localhost" >> /etc/hosts
systemctl enable systemd-networkd.service
sed -i 's/MODULES=(/MODULES=(btrfs /' /etc/mkinitcpio.conf
# Add hooks (ORDER IS IMPORTANT)
sed -i 's/fsck)/consolefont encrypt fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P
passwd

# Failed systemd-boot attempt. bootctl install doesn't create the EFI boot entries.
: '
mkdir /efi/EFI
mkdir /efi/EFI/systemd
mkdir /efi/EFI/systemd/drivers
cp -r /usr/lib/efifs-x64/* /efi/EFI/systemd/drivers
mkdir /efi/loader
mkdir /efi/loader/entries

echo "default arch.conf" > /efi/loader/loader.conf
echo "timeout 4" >> /efi/loader/loader.conf
echo "console-mode max" >> /efi/loader/loader.conf
echo "editor no" >> /efi/loader/loader.conf

echo "title Arch Linux" > /efi/loader/entries/arch.conf
echo "linux /vmlinuz-linux" >> /efi/loader/entries/arch.conf
echo "initrd /amd-ucode.img" >> /efi/loader/entries/arch.conf
echo "initrd /initramfs-linux.img" >> /efi/loader/entries/arch.conf
echo "options root="LABEL=ARCHBTRFS1" rootflags=subvol=r1 rw" >> /efi/loader/entries/arch.conf

echo "title Arch Linux (fallback)" > /efi/loader/entries/arch-fallback.conf
echo "linux /vmlinuz-linux" >> /efi/loader/entries/arch-fallback.conf
echo "initrd /amd-ucode.img" >> /efi/loader/entries/arch-fallback.conf
echo "initrd /initramfs-linux-fallback.img" >> /efi/loader/entries/arch-fallback.conf
echo "options root="LABEL=ARCHBTRFS1" rootflags=subvol=r1 rw" >> /efi/loader/entries/arch-fallback.conf

bootctl --esp-path=/efi install
'

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCHLINUX
sed -i 's@GRUB_CMDLINE_LINUX_DEFAULT="@GRUB_CMDLINE_LINUX_DEFAULT="cryptdevice=UUID=0ed20ab4-ad66-4f70-bc63-fc1dd33dbe1e:crypt1 root=/dev/mapper/crypt1 amdgpu.ppfeaturemask=0xffffffff CONFIG_FW_LOADER_COMPRESS@' /etc/mkinitcpio.conf
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCHLINUX
grub-mkconfig -o /boot/grub/grub.cfg
sed -i 's/#Color/Color/' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
systemctl enable sddm.service
useradd -m -G users,wheel,uucp -s /bin/zsh sapien
passwd sapien
