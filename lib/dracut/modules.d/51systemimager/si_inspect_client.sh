#!/bin/bash

. /lib/autoinstall-lib.sh

MOUNTS=`mktemp -u`
cat /etc/fstab|sort -b -k2 |awk '{print $1}' > $MOUNTS
for MOUNT_POINT in `cat $MOUNTS |tr '\n' ' '`
do
	echo "mountng $MOUNT_POINT"
	mount $MOUNT_POINT
done

mount_os_filesystems_to_sysroot

echo "Client ready. Quit using CTRL-D or exit"
PS1="Inspecting \h \W #" chroot /sysroot

umount_os_filesystems_from_sysroot

for MOUNT_POINT in `tac $MOUNTS | tr '\n' ' '`
do
	echo "umounting $MOUNT_POINT"
	umount $MOUNT_POINT
done
/bin/rm -f $MOUNTS

