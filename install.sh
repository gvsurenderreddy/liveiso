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

for i in grub isolinux; do
	mkdir -p $root/usr/share/liveiso/$i
	install -v -m644 $i.cfg $root/usr/share/liveiso/$i
done

mkdir -p $root/usr/share/liveiso/systemd
install -v -m644 override.conf $root/usr/share/liveiso/systemd

install -v -m644 install.txt $root/usr/share/liveiso