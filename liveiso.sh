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
pan -A infra root=work/rootfs
pan -a syslinux mtools gptfdisk parted prebootloader btrfs-progs root=work/rootfs
setup-chroot -u work/rootfs
copy-pkgs infra work/rootfs/pkg/arc
copy-pkgs x11 work/rootfs/pkg/arc
copy-pkgs supra work/rootfs/pkg/arc
cp -a /pkg/rcs work/rootfs/pkg/rcs

mkdir -p work/rootfs/etc/systemd/system/getty@tty1.service.d
cp /usr/share/liveiso/systemd/override.conf work/rootfs/etc/systemd/system/getty@tty1.service.d
chroot work/rootfs /bin/sh -c "echo \"KEYMAP=uk\" > /etc/vconsole.conf"
chroot work/rootfs /bin/sh -c "ln -s /usr/share/zoneinfo/Europe/Stockholm /etc/localtime"
chroot work/rootfs /bin/sh -c "systemctl enable dhcpcd"
chroot work/rootfs /bin/sh -c "echo \"For the installation instructions,\" >> /etc/motd"
chroot work/rootfs /bin/sh -c "echo \"read the file /root/install.txt\" >> /etc/motd"
cp /usr/share/liveiso/install.txt work/rootfs/root

mkdir -p work/LiveOS
truncate -s 32G work/LiveOS/rootfs.img
mkfs.ext4 -O ^has_journal,^resize_inode -E lazy_itable_init=0 -m 0 -F work/LiveOS/rootfs.img
tune2fs -c 0 -i 0 work/LiveOS/rootfs.img &> /dev/null

mkdir -p work/mnt/rootfs
mount work/LiveOS/rootfs.img work/mnt/rootfs
cp -aT work/rootfs/ work/mnt/rootfs
umount -d work/mnt/rootfs
rmdir work/mnt/rootfs

mkdir -p work/iso/LiveOS
mksquashfs work/LiveOS work/iso/LiveOS/squashfs.img -noappend -comp xz -no-progress -keep-as-directory
rm -r work/LiveOS

mkdir work/iso/isolinux
cp /usr/lib/syslinux/bios/isolinux.bin work/iso/isolinux
cp /usr/lib/syslinux/bios/isohdpfx.bin work/iso/isolinux
cp /usr/lib/syslinux/bios/ldlinux.c32 work/iso/isolinux
cp /usr/share/liveiso/isolinux/isolinux.cfg work/iso/isolinux

mkdir -p work/iso/LiveOS/boot/syslinux
cp /usr/lib/syslinux/bios/ldlinux.c32 work/iso/LiveOS/boot/syslinux
cp /usr/lib/syslinux/bios/menu.c32 work/iso/LiveOS/boot/syslinux
cp /usr/lib/syslinux/bios/libutil.c32 work/iso/LiveOS/boot/syslinux
cp /usr/share/liveiso/syslinux/syslinux.cfg work/iso/LiveOS/boot/syslinux
sed "s|GNURAMALINUX|$iso_label|g" \
    /usr/share/liveiso/syslinux/syslinux.cfg > work/iso/LiveOS/boot/syslinux/syslinux.cfg

cp /boot/vmlinuz work/iso/LiveOS/boot
dracut -N -L 3 --add "dmsquash-live pollcdrom" work/iso/LiveOS/boot/initramfs $kver

mkdir -p work/iso/EFI/boot
cp /usr/lib/prebootloader/PreLoader.efi work/iso/EFI/boot/bootx64.efi
cp /usr/lib/prebootloader/HashTool.efi work/iso/EFI/boot
cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi work/iso/EFI/boot/loader.efi

mkdir -p work/iso/loader/entries
cp /usr/share/liveiso/efiboot/loader.conf work/iso/loader
cp /usr/share/liveiso/efiboot/uefi-shell-v1.conf work/iso/loader/entries
cp /usr/share/liveiso/efiboot/uefi-shell-v2.conf work/iso/loader/entries
sed "s|GNURAMALINUX|$iso_label|g" \
    /usr/share/liveiso/efiboot/liveiso-usb.conf > work/iso/loader/entries/liveiso.conf

curl -o work/iso/EFI/shellx64_v2.efi https://svn.code.sf.net/p/edk2/code/trunk/edk2/ShellBinPkg/UefiShell/X64/Shell.efi
curl -o work/iso/EFI/shellx64_v1.efi https://svn.code.sf.net/p/edk2/code/trunk/edk2/EdkShellBinPkg/FullShell/X64/Shell_Full.efi

mkdir -p work/iso/EFI/liveiso
truncate -s 41M work/iso/EFI/liveiso/efiboot.img
mkdosfs -n LIVEISO_EFI work/iso/EFI/liveiso/efiboot.img

mkdir -p work/efiboot
mount work/iso/EFI/liveiso/efiboot.img work/efiboot

mkdir -p work/efiboot/EFI/liveiso
cp work/iso/LiveOS/boot/vmlinuz work/efiboot/EFI/liveiso
cp work/iso/LiveOS/boot/initramfs work/efiboot/EFI/liveiso

mkdir -p work/efiboot/EFI/boot
cp /usr/lib/prebootloader/PreLoader.efi work/efiboot/EFI/boot/bootx64.efi
cp /usr/lib/prebootloader/HashTool.efi work/efiboot/EFI/boot
cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi work/efiboot/EFI/boot/loader.efi

mkdir -p work/efiboot/loader/entries
cp /usr/share/liveiso/efiboot/loader.conf work/efiboot/loader
cp /usr/share/liveiso/efiboot/uefi-shell-v1.conf work/efiboot/loader/entries
cp /usr/share/liveiso/efiboot/uefi-shell-v2.conf work/efiboot/loader/entries
sed "s|GNURAMALINUX|$iso_label|g" \
    /usr/share/liveiso/efiboot/liveiso-cd.conf > work/efiboot/loader/entries/liveiso.conf

cp work/iso/EFI/shellx64_v2.efi work/efiboot/EFI
cp work/iso/EFI/shellx64_v1.efi work/efiboot/EFI

umount -d work/efiboot

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
        -e EFI/liveiso/efiboot.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -output "$iso_name" \
        work/iso