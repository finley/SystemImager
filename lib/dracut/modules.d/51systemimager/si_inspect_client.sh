#!/bin/bash
#
# "SystemImager" 
#
#  Copyright (C) 1999-2017 Brian Elliott Finley <brian@thefinleys.com>
#
#  $Id$
#  vi: set filetype=sh et ts=4:
#
#  Code written by Olivier LAHAYE.
#
# This file can be used from emergency shell to mount and chroot to freshly
# installed client.

. /lib/autoinstall-lib.sh

MOUNTS=`mktemp -u`
cat /etc/fstab|awk '{print $1}' | sort > $MOUNTS
for MOUNT_POINT in `cat $MOUNTS tr '\n' ' '`
do
	echo "mountng $MOUNT_POINT"
	mount $MOUNT_POINT
done

mount_os_filesystems_to_sysroot

echo "Client ready. Quit using CTRL-D or exit"
chroot /sysroot

umount_os_filesystems_from_sysroot

for MOUNT_POINT in `tac $MOUNTS | tr '\n' ' '`
do
	echo "umounting $MOUNT_POINT"
	umount $MOUNT_POINT
done

