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

mount -o remount,rw /

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
echo 'T0:23:respawn:/sbin/getty -L @SERIAL_DEVICE@0 115200 vt100' >>/etc/inittab
if ! grep -q '^@SERIAL_DEVICE@0$'; then
  echo '@SERIAL_DEVICE@0' >>/etc/securetty
fi
echo 'root:root' |chpasswd

## FIXME
#sed -i 's/^UTC$/LOCAL/' /etc/adjtime

exec /sbin/init

