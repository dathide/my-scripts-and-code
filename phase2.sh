ln -sf /usr/share/zoneinfo/America/Phoenix /etc/localtime
sleep 0.5
hwclock --systohc
sleep 0.5
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sleep 0.5
locale-gen
sleep 0.5
echo "LANG=en_US.UTF-8" > /etc/locale.conf
sleep 0.5
echo "KEYMAP=us" > /etc/vconsole.conf
sleep 0.5
echo "archlinux" > /etc/hostname
sleep 0.5
echo "#<ip-address> <hostname.domain.org> <hostname>" > /etc/hosts
sleep 0.5
echo "127.0.0.1 archlinux.localdomain archlinux" >> /etc/hosts
sleep 0.5
echo "::1 localhost.localdomain localhost" >> /etc/hosts
sleep 0.5
systemctl enable systemd-networkd.service
sleep 0.5
# After lines starting with MODULES, add line
# MODULES=(btrfs)
# From beginning to first line starting with MODULES, replace MODULES with #MODULES
sed -i '0,/^\MODULES/ s//#MODULES/' /etc/mkinitcpio.conf
sleep 0.5

sleep 0.5
# The order of hooks is important
# Order used from https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Configuring_mkinitcpio
# From beginning to first line starting with HOOKS, add line
# HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)
# From beginning to first line starting with HOOKS, replace HOOKS with #HOOKS
sed -i '0,/^\HOOKS/ s//#HOOKS/' /etc/mkinitcpio.conf
sleep 0.5

sleep 0.5
mkinitcpio -P
sleep 0.5
passwd
sleep 0.5

# Failed systemd-boot attempt. bootctl install didn't create the necessary EFI boot entries.
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
sleep 0.5
sed -i 's@GRUB_CMDLINE_LINUX_DEFAULT="@GRUB_CMDLINE_LINUX_DEFAULT="cryptdevice=UUID=0ed20ab4-ad66-4f70-bc63-fc1dd33dbe1e:crypt1 root=/dev/mapper/crypt1 amdgpu.ppfeaturemask=0xffffffff CONFIG_FW_LOADER_COMPRESS@' /etc/mkinitcpio.conf
sleep 0.5
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
sleep 0.5
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCHLINUX
sleep 0.5
grub-mkconfig -o /boot/grub/grub.cfg
sleep 0.5
sed -i 's/#Color/Color/' /etc/pacman.conf
sleep 0.5
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
sleep 0.5
systemctl enable sddm.service
sleep 0.5
useradd -m -G users,wheel,uucp -s /bin/zsh sapien
sleep 0.5
passwd sapien
sleep 0.5
