#!/bin/bash

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: $0 (root=)"
            exit 0;;
        root=*)
            root=${i#*=};;
    esac
done

mkdir -p $root/usr/bin
install -v -m755 liveiso.sh $root/usr/bin/liveiso

mkdir -p $root/usr/share/liveiso/efiboot
for f in loader uefi-shell-v1 uefi-shell-v2 liveiso-usb liveiso-cd; do
	install -v -m644 ${f}.conf $root/usr/share/liveiso/efiboot
done

mkdir -p $root/usr/share/liveiso/syslinux
install -v -m644 syslinux.cfg $root/usr/share/liveiso/syslinux

mkdir -p $root/usr/share/liveiso/isolinux
install -v -m644 isolinux.cfg $root/usr/share/liveiso/isolinux