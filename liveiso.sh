#!/bin/bash

set -e -u

kver=$(uname -r)
iso_version=$(date +%Y.%m.%d)
iso_name="gnuramalinux-$iso_version.iso"
iso_label="GNURAMALINUX_$(date +%Y%m)"
iso_publisher="GNUrama Linux <http://www.gnurama.org>"
iso_application="GNUrama Linux Live/Rescue CD"

if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

mkdir -p work/rootfs
setup-chroot -m work/rootfs
pan -A base rootdir=work/rootfs
pan -a gnurama-scripts syslinux mtools gptfdisk parted shim \
btrfs-progs iw wpa_supplicant openssh rootdir=work/rootfs
setup-chroot -u work/rootfs

mkdir -p work/rootfs/etc/systemd/system/getty@tty1.service.d
cp /usr/share/liveiso/systemd/override.conf work/rootfs/etc/systemd/system/getty@tty1.service.d
chroot work/rootfs /bin/sh -c "echo \"KEYMAP=uk\" > /etc/vconsole.conf"
chroot work/rootfs /bin/sh -c "ln -s /usr/share/zoneinfo/Europe/Stockholm /etc/localtime"
chroot work/rootfs /bin/sh -c "systemctl enable dhcpcd"
chroot work/rootfs /bin/sh -c "echo \"For the installation instructions,\" >> /etc/motd"
chroot work/rootfs /bin/sh -c "echo \"read the file /root/install.txt\" >> /etc/motd"
cp /usr/share/liveiso/install.txt work/rootfs/root

mkdir -p work/live/LiveOS
truncate -s 32G work/live/LiveOS/rootfs.img
mkfs.ext4 -O ^has_journal,^resize_inode -E lazy_itable_init=0 -m 0 -F work/live/LiveOS/rootfs.img
tune2fs -c 0 -i 0 work/live/LiveOS/rootfs.img &> /dev/null

mkdir -p work/mnt/rootfs
mount work/live/LiveOS/rootfs.img work/mnt/rootfs
cp -aT work/rootfs/ work/mnt/rootfs
umount -d work/mnt/rootfs
rm -r work/mnt

mkdir -p work/iso/LiveOS
mksquashfs work/live work/iso/LiveOS/squashfs.img -noappend -comp xz -no-progress
rm -r work/live

mkdir work/iso/isolinux
cp /usr/lib/syslinux/bios/isolinux.bin work/iso/isolinux
cp /usr/lib/syslinux/bios/isohdpfx.bin work/iso/isolinux
cp /usr/lib/syslinux/bios/ldlinux.c32 work/iso/isolinux
cp /usr/lib/syslinux/bios/vesamenu.c32 work/iso/isolinux
cp /usr/lib/syslinux/bios/libcom32.c32 work/iso/isolinux
cp /usr/lib/syslinux/bios/libutil.c32 work/iso/isolinux
sed "s|GNURAMALINUX|$iso_label|g" \
    /usr/share/liveiso/isolinux/isolinux.cfg > work/iso/isolinux/isolinux.cfg

cp /boot/vmlinuz work/iso/isolinux
dracut -N -L 3 --add "dmsquash-live pollcdrom" work/iso/isolinux/initramfs $kver

truncate -s 10M work/iso/isolinux/efiboot.img
mkdosfs -n LIVEISO_EFI work/iso/isolinux/efiboot.img

mkdir -p work/efiboot
mount work/iso/isolinux/efiboot.img work/efiboot

mkdir -p work/efiboot/EFI/{boot,fonts}
cp /boot/efi/EFI/gnurama/{boot,grub}x64.efi work/efiboot/EFI/boot
cp /boot/efi/EFI/gnurama/fonts/unicode.pf2 work/efiboot/EFI/fonts
sed "s|GNURAMALINUX|$iso_label|g" \
    /usr/share/liveiso/grub/grub.cfg > work/efiboot/EFI/boot/grub.cfg

umount -d work/efiboot

mkdir -p work/iso/EFI/{boot,fonts}
cp /boot/efi/EFI/gnurama/{boot,grub}x64.efi work/iso/EFI/boot
cp /boot/efi/EFI/gnurama/fonts/unicode.pf2 work/iso/EFI/fonts
sed "s|GNURAMALINUX|$iso_label|g" \
    /usr/share/liveiso/grub/grub.cfg > work/iso/EFI/boot/grub.cfg

xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "$iso_label" \
        -appid "$iso_application" \
        -publisher "$iso_publisher" \
        -preparer "prepared by liveiso" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -isohybrid-mbr work/iso/isolinux/isohdpfx.bin \
        -eltorito-alt-boot \
        -e isolinux/efiboot.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -output "$iso_name" \
        work/iso