#!/bin/sh
##
## Do debootstrap --second-stage and misc on debootstrap --foreign env.
## Copyright (c) 2012 SATOH Fumiyasu @ OSS Technology Corp., Japan
##
## License: GNU General Public License version 3
##

set -u
set -e
umask 0022

PS4="rootfs:$0:"
info=": INFO ::"
error=": ERROR ::"
warning=": WARNING ::"

trap '$error"mount -o remount,ro; Fallback to /bin/sh"; exec /bin/sh' EXIT
set -x

$info"Start"

mount -o remount,rw /

hostname '@HOSTNAME@'
cp /proc/mounts /etc/mtab
cp /proc/mounts /etc/mtab.tmp

/debootstrap/debootstrap --second-stage

if [ -f /etc/locale.gen ]; then
  sed -i 's/^# *\(@LANG@ \)/\1/i' /etc/locale.gen
fi
if type locale-gen >/dev/null 2>&1; then
  locale-gen
fi
if type update-locale >/dev/null 2>&1; then
  update-locale LANG='@LANG@'
fi

echo '@HOSTNAME@' >/etc/hostname
echo '@TIMEZONE@' >/etc/timezone
echo 'root:root' |chpasswd

echo 'T0:23:respawn:/sbin/getty -L @SERIAL_DEVICE@0 115200 vt100' >>/etc/inittab
if ! grep -q '^@SERIAL_DEVICE@0$' /etc/securetty; then
  echo '@SERIAL_DEVICE@0' >>/etc/securetty
fi

echo 'T1:0123456:respawn:/opt/debian-qemu/sbin/qemu-debian-control </dev/@SERIAL_DEVICE@1 >/dev/@SERIAL_DEVICE@1' >>/etc/inittab

## FIXME
#sed -i 's/^UTC$/LOCAL/' /etc/adjtime

mv /etc/mtab.tmp /etc/mtab

$info"End"

## Remount / read-only by an exec-ed shell to close removed $0
## before remount, then force to reboot the system
exec /bin/sh -c "mount -n -o remount,ro /; reboot -f -d"

