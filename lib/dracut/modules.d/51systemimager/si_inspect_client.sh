#!/bin/bash

. /lib/autoinstall-lib.sh

MOUNTS=`mktemp -u`
cat /etc/fstab.systemimager|sort -b -k2 |awk '{print $1}' > $MOUNTS
cat $MOUNTS | while read MOUNT_POINT
do
	echo "mountng $MOUNT_POINT"
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

