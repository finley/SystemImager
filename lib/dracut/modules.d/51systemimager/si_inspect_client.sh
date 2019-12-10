#!/bin/bash
#    vi:set filetype=bash et ts=4:
#
#    This file is part of SystemImager.
#
#    SystemImager is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    SystemImager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with SystemImager. If not, see <https://www.gnu.org/licenses/>.
#
#    Copyright (C) 2017-2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#    Purpose:
#      Command that can mount installed client and chroot to /sysroot in
#      order to inspect manually what has been installed.
#      This command is available from initramfs imager command line only.

. /lib/autoinstall-lib.sh

MOUNTS=`mktemp -u`
cat /etc/fstab.systemimager|sort -b -k2 |awk '{print $1}' > $MOUNTS
cat $MOUNTS | while read MOUNT_POINT
do
	echo "mounting $MOUNT_POINT"
	mount --fstab /etc/fstab.systemimager $MOUNT_POINT
done

mount_os_filesystems_to_sysroot

echo "Client ready. Quit using CTRL-D or exit"
PS1="Inspecting \h \W #" chroot /sysroot

umount_os_filesystems_from_sysroot

tac $MOUNTS | while read MOUNT_POINT
do
	echo "umounting $MOUNT_POINT"
	umount $MOUNT_POINT
done
/bin/rm -f $MOUNTS

