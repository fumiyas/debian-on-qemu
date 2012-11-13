#!/usr/bin/env make
##
## Bootstrap a Debian/GNU Linux system on QEMU
## Copyright (c) 2012 SATOH Fumiyasu @ OSS Technology Corp., Japan
##
## License: GNU General Public License version 3
##

SOURCE_DIR=	.

## ======================================================================

prefix=		/usr/local
sysconfdir=	$(prefix)/etc
localstatedir=	$(prefix)/var

var=		$(localstatedir)
initddir=	$(prefix)/etc/init.d

include Makefile.config

ifeq ($(DEB_ARCH), armhf)
  DEB_KERNEL_FLAVOR:=	vexpress
  QEMU_SERIAL_DEVICE:=	ttyAMA0
endif
ifeq ($(DEB_ARCH), armel)
  DEB_KERNEL_FLAVOR:=	versatile
  QEMU_SERIAL_DEVICE:=	ttyAMA0
endif
ifndef DEB_KERNEL_FLAVOR
  DEB_KERNEL_FLAVOR:=	$(DEB_ARCH)
  QEMU_SERIAL_DEVICE:=	ttyS0
endif

ifndef DEB_INCLUDE
  DEB_INCLUDE:=		dpkg ## dpkg is dummy
endif
ifndef DEB_EXCLUDE
  DEB_EXCLUDE:=		_dummy_
endif
ifndef DEB_TIMEZONE
  DEB_TIMEZONE:=	$(shell cat /etc/timezone)
endif
ifndef DEB_LANG
  DEB_LANG:=		$(shell sed -n 's/^LANG="*\(.*\)"*/\1/p' /etc/default/locale)
endif

## ======================================================================

BUILDDIR=	$(DEB_HOSTNAME)
BUILDDIR_STAMP=	$(BUILDDIR)/builddir.stamp
BUILD_STAMP=	$(BUILDDIR)/build.stamp

ROOTFS=		$(BUILDDIR)/rootfs
ROOTFS_STAMP=	$(ROOTFS).stamp
ROOTFS_IMAGE=	$(BUILDDIR)/rootfs.raw

KERNEL_IMAGE=	$(BUILDDIR)/vmlinuz

INITRD=		$(BUILDDIR)/initrd
INITRD_STAMP=	$(INITRD).stamp
INITRD_IMAGE=	$(BUILDDIR)/initrd.img
BUSYBOX_CMDS=   sh cp rm mkdir sed sleep mknod mount modprobe insmod switch_root

INIT=		$(BUILDDIR)/qemu-debian-$(DEB_HOSTNAME).init
INIT_DEFAULT=	$(BUILDDIR)/qemu-debian-$(DEB_HOSTNAME).default

BUILD_TARGETS=	$(BUILD_STAMP)
CLEAN_TARGETS=	$(BUILDDIR)

## ----------------------------------------------------------------------

FAKEROOT_ENV=	$(BUILDDIR)/fakeroot.env
FAKEROOT=	fakeroot -i $(FAKEROOT_ENV) -s $(FAKEROOT_ENV)

DEBOOTSTRAP_TAR=$(BUILDDIR)/debootstrap-rootfs.tar
DEBOOTSTRAP_INCLUDE= \
		linux-image-$(DEB_KERNEL_FLAVOR),busybox-static,$(DEB_INCLUDE)
DEBOOTSTRAP_EXCLUDE= \
		$(DEB_EXCLUDE)
DEBOOTSTRAP=	debootstrap
ifneq ($(DEBOOTSTRAP_INCLUDE),)
  DEBOOTSTRAP+=	  --include $(DEBOOTSTRAP_INCLUDE)
endif
ifneq ($(DEBOOTSTRAP_EXCLUDE),)
  DEBOOTSTRAP+=	  --exclude $(DEBOOTSTRAP_EXCLUDE)
endif

SUBST=	sed \
	  -e 's|@NAME@|$(DEB_HOSTNAME)|g' \
	  -e 's|@ARCH@|$(DEB_ARCH)|g' \
	  -e 's|@TIMEZONE@|$(DEB_TIMEZONE)|g' \
	  -e 's|@LANG@|$(DEB_LANG)|g' \
	  -e 's|@SERIAL_DEVICE@|$(QEMU_SERIAL_DEVICE)|g' \
	  -e 's|@VAR@|$(var)|g' \
	  ##

include $(SOURCE_DIR)/build/Makefile.common

## ======================================================================

$(BUILDDIR_STAMP):
	mkdir $(BUILDDIR)
	touch $@

## ======================================================================

$(ROOTFS_IMAGE): $(BUILDDIR_STAMP) $(ROOTFS_STAMP)
	qemu-img create -f raw $@.tmp $(DEB_ROOTFS_SIZE)
	mkfs -t ext4 -F $@.tmp
	tune2fs -c0 -i0 $@.tmp
	mkdir -p $(BUILDDIR)/mnt
	( \
	  trap 'sudo umount $(BUILDDIR)/mnt' EXIT; \
	  sudo mount $@.tmp $(BUILDDIR)/mnt; \
	  $(FAKEROOT) tar cfC - $(ROOTFS) . |sudo tar xfC - $(BUILDDIR)/mnt; \
	)
	mv $@.tmp $@

$(ROOTFS_STAMP): $(BUILDDIR_STAMP) $(DEBOOTSTRAP_TAR) script/debootstrap.2nd.sh
	rm -rf $(ROOTFS)
	$(FAKEROOT) \
	  $(DEBOOTSTRAP) \
	    --arch $(DEB_ARCH) \
	    --unpack-tarball=`pwd`/$(DEBOOTSTRAP_TAR) \
	    --foreign \
	    $(DEB_CODENAME) \
	    $(ROOTFS) \
	  ;
	$(FAKEROOT) \
	  $(SUBST) \
	    script/debootstrap.2nd.sh \
	    >$(ROOTFS)/debootstrap/debootstrap.2nd \
	  ;
	$(FAKEROOT) \
	  chmod +x $(ROOTFS)/debootstrap/debootstrap.2nd
	echo $(DEB_HOSTNAME) >$(ROOTFS)/etc/hostname
	echo '$(QEMU_SERIAL_DEVICE)' >>$(ROOTFS)/etc/securetty
	touch $@

$(DEBOOTSTRAP_TAR): $(BUILDDIR_STAMP)
	: >$(FAKEROOT_ENV)
	$(FAKEROOT) \
	  $(DEBOOTSTRAP) \
	    --arch $(DEB_ARCH) \
	    --make-tarball=$@.tmp \
	    $(DEB_CODENAME) \
	    $(ROOTFS) \
	    $(DEB_MIRROR) \
	  ;
	mv $@.tmp $@

$(BUILD_STAMP): $(BUILDDIR_STAMP) \
  $(KERNEL_IMAGE) $(INITRD_IMAGE) $(ROOTFS_IMAGE) $(INIT) $(INIT_DEFAULT)
	env \
	  QEMU_DEBIAN_INIT=/debootstrap/debootstrap.2nd \
	  QEMU_DEBIAN_VAR_DIR=. \
	  $(INIT) start
	touch $@

## ======================================================================

$(INITRD_IMAGE): $(BUILDDIR_STAMP) $(INITRD_STAMP)
	(cd $(INITRD) && find . |cpio -o -H newc --owner=0:0 |gzip -9) >$@.tmp
	mv $@.tmp $@

$(INITRD_STAMP): $(BUILDDIR_STAMP) $(ROOTFS_STAMP) script/initrd.init
	rm -rf $(INITRD)
	mkdir -p -m 0755 $(INITRD)/bin
	cp -p script/initrd.init $(INITRD)/init
	dpkg-deb \
	  --fsys-tarfile $(ROOTFS)/var/cache/apt/archives/busybox-static_*.deb \
	  |tar xfC - $(INITRD) ./bin/busybox \
	  ;
	for c in $(BUSYBOX_CMDS); do \
	  ln -s busybox $(INITRD)/bin/$$c; \
	done
	dpkg-deb \
	    --fsys-tarfile $(ROOTFS)/var/cache/apt/archives/linux-image-[0-9]*_*.deb \
	  |tar -x -f - -C $(INITRD) --wildcards ./lib/modules './boot/vmlinuz-*'
	depmod -b $(INITRD) `ls $(INITRD)/lib/modules`
	touch $@

## ======================================================================

$(KERNEL_IMAGE): $(BUILDDIR_STAMP) $(INITRD_IMAGE)
	mv $(INITRD)/boot/vmlinuz-* $@
	touch $@

## ======================================================================

$(INIT): $(BUILDDIR_STAMP) script/qemu-debian.init
	$(SUBST) script/qemu-debian.init >$@.tmp
	chmod +x $@.tmp
	mv $@.tmp $@

$(INIT_DEFAULT): $(BUILDDIR_STAMP) script/qemu-debian.default
	$(SUBST) script/qemu-debian.default >$@.tmp
	mv $@.tmp $@

