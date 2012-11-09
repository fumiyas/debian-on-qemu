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

echo 'T0:23:respawn:/sbin/getty -L ttyAMA0 115200 vt100' >>/etc/inittab
echo 'root:root' |chpasswd

## FIXME
#sed -i 's/^UTC$/LOCAL/' /etc/adjtime

rm "$0"

exec /sbin/init

