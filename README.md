Bootstrap a Debian/GNU Linux system on QEMU
======================================================================

  * Copyright (c) 2012 SATOH Fumiyasu @ OSS Technology Corp., Japan
  * License: GNU General Public License version 3
  * URL: <https://github.com/fumiyas/debian-on-qemu>
  * Twitter: <https://twitter.com/satoh_fumiyasu>

What's this?
----------------------------------------------------------------------

This is a build environment to bootstrap a Debian GNU/Linux system
on QEMU. Currently, the following Debian ports (architecture) are 
supported:

  * armhf (ARM Hard Float ABI)
  * armel (ARM EABI)
  * amd64 (AMD64 / Intel64)

Requirements:
----------------------------------------------------------------------

  * Debian GNU/Linux (tested on sid amd64)
  * Debian packages:
    * make
    * debootstrap
    * fakeroot
    * sudo
    * qemu-system
    * screen
    * misc?

To build
----------------------------------------------------------------------

  1. Confirm you can get root privileges via sudo
  2. Edit debian.config
  3. Run `make`
  4. See files `vmlinuz`, `initrd.img`, `rootfs.raw` in
     directory `$(DEB_HOSTNAME)`
  5. Run `sudo make install`
  6. Run `/usr/local/etc/init.d/qemu-* start`
  7. Run `/usr/local/etc/init.d/qemu-* attach`
  8. Login Debian GNU/Linux system on QEMU by user 'root' with
     password 'root'

TODO
----------------------------------------------------------------------

  * Avoid root privleges (sudo) on build
  * Replace initrd.img by /boot/initrd.img in rootfs.raw
  * Setup more OS config:
    * Network
    * Generate locale data (locale-gen(8), /etc/locale.gen)

