#!/bin/bash

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: $0 (rootdir=<directory>)"
            exit 0;;
        rootdir=*)
            rootdir=${i#*=};;
    esac
done

mkdir -p $rootdir/usr/bin
install -v -m755 liveiso.sh $rootdir/usr/bin/liveiso
install -v -m755 liveiso-desktop.sh $rootdir/usr/bin/liveiso-desktop

for i in grub isolinux; do
	mkdir -p $rootdir/usr/share/liveiso/$i
	install -v -m644 $i.cfg $rootdir/usr/share/liveiso/$i
done

mkdir -p $rootdir/usr/share/liveiso/systemd
install -v -m644 override.conf $rootdir/usr/share/liveiso/systemd

mkdir -p $rootdir/usr/share/liveiso/gdm
install -v -m644 gdm-autologin.conf $rootdir/usr/share/liveiso/gdm/custom.conf

install -v -m644 install.txt $rootdir/usr/share/liveiso