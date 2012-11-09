#!/usr/bin/env make
##
## Helper scripts to construct Debian/GNU Linux env on QEMU
## Copyright (c) 2012 SATOH Fumiyasu @ OSS Technology Corp., Japan
##
## License: GNU General Public License version 3
##

SOURCE_DIR=	.

## ======================================================================

DEB_HOSTNAME=	`uname -n`-$(DEB_CODENAME)-$(DEB_ARCH)
DEB_ROOTFS_SIZE=10G

DEB_CODENAME=	wheezy
DEB_ARCH=	armhf
DEB_KERNEL=	linux-image-3.2.0-4-vexpress
DEB_MIRROR=	http://ftp.jaist.ac.jp/debian

## ======================================================================

ROOTFS=		rootfs.raw
VMLINUZ=	vmlinuz
INITRD=		initrd.cpio.gz

FAKEROOT_ENV=	fakeroot.env
FAKEROOT=	fakeroot -i $(FAKEROOT_ENV) -s $(FAKEROOT_ENV)

DEBOOTSTRAP=	debootstrap
DEBOOTSTRAP_INCLUDE=	$(DEB_KERNEL),busybox-static
DEBOOTSTRAP_EXCLUDE=	aptitude
DEBOOTSTRAP_TAR=rootfs-debs.tar

BUILD_TARGETS=	$(ROOTFS) $(VMLINUZ) $(INITRD) rootfs.2nd.stamp
CLEAN_TARGETS=	rootfs initrd $(DEBOOTSTRAP_TAR) $(FAKEROOT_ENV) $(BUILD_TARGETS)

include $(SOURCE_DIR)/build/Makefile.common

## ======================================================================

$(ROOTFS): rootfs.stamp
	qemu-img create -f raw $@.tmp $(DEB_ROOTFS_SIZE)
	mkfs -t ext4 -F $@.tmp
	tune2fs -c0 -i0 $@.tmp
	mkdir -p mnt
	( \
	  trap 'sudo umount mnt' EXIT; \
	  sudo mount $@.tmp mnt; \
	  $(FAKEROOT) tar cfC - rootfs . |sudo tar xfC - mnt; \
	)
	mv $@.tmp $@

rootfs.stamp: rootfs-debs.tar
	rm -rf rootfs
	$(FAKEROOT) $(DEBOOTSTRAP) --arch $(DEB_ARCH) --unpack-tarball=`pwd`/rootfs-debs.tar --foreign $(DEB_CODENAME) rootfs
	$(FAKEROOT) cp script/debootstrap.2nd.sh rootfs/debootstrap.2nd
	echo $(DEB_HOSTNAME) >rootfs/etc/hostname
	echo 'ttyAMA0' >>rootfs/etc/securetty
	touch $@

rootfs-debs.tar:
	$(FAKEROOT) $(DEBOOTSTRAP) --arch $(DEB_ARCH) --make-tarball=$@.tmp --include "$(DEBOOTSTRAP_INCLUDE)" --exclude "$(DEBOOTSTRAP_EXCLUDE)" $(DEB_CODENAME) rootfs $(DEB_MIRROR)
	mv $@.tmp $@

rootfs.2nd.stamp: $(VMLINUZ) $(INITRD) $(ROOTFS)
	QEMU_DEBIAN_INIT=/debootstrap.2nd script/qemu-debian-armhf.init
	touch $@

## ======================================================================

$(INITRD): initrd.stamp
	(cd initrd && find . |cpio -o -H newc --owner=0:0 |gzip -9) >$@.tmp
	mv $@.tmp $@

initrd.stamp: rootfs.stamp
	rm -rf initrd
	mkdir -p -m 0755 initrd/bin
	cp -p script/initrd.init initrd/init
	dpkg-deb --fsys-tarfile rootfs/var/cache/apt/archives/busybox-static_*.deb \
	  |tar xfC - initrd ./bin/busybox
	for c in sh cp rm mkdir sed mknod mount modprobe insmod switch_root; do \
	  ln -s busybox initrd/bin/$$c; \
	done
	dpkg-deb --fsys-tarfile rootfs/var/cache/apt/archives/$(DEB_KERNEL)_*.deb \
	  |tar -x -f - -C initrd --wildcards ./lib/modules './boot/vmlinuz-*'
	depmod -b initrd `ls initrd/lib/modules`
	touch $@

## ======================================================================

$(VMLINUZ): $(INITRD)
	mv initrd/boot/vmlinuz-* $@
	touch $@

