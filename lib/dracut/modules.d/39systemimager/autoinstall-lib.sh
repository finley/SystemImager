#!/bin/sh
#
# "SystemImager" 
# funtions related to imaging script only.
#
#  Copyright (C) 2017 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#  $Id$
#  vi: set filetype=sh et ts=4:
#

type logmessage >/dev/null 2>&1 || . /lib/systemimager-lib.sh

################################################################################
#
#   Save the SIS imaging relevant logs to /root/SIS_Install_logs/ on the imaged
#   computer.
#
#
#
save_logs_to_sysroot() {
    loginfo "========================="
    loginfo "Saving logs to /sysroot/root..."
    if test -d /sysroot/root
    then
        mkdir -p /sysroot/root/SIS_Install_logs/
        cp /tmp/variables.txt       /sysroot/root/SIS_Install_logs/
        cp /tmp/dhcp_info.${DEVICE} /sysroot/root/SIS_Install_logs/
	cp /tmp/dhclient.${DEVICE}.dhcpopts /sysroot/root/SIS_Install_logs/
        cp /tmp/si_monitor.log      /sysroot/root/SIS_Install_logs/
        echo "${IMAGENAME}" >         /sysroot/root/SIS_Install_logs/image.txt
        test -f /run/initramfs/rdsosreport.txt && cp /run/initramfs/rdsosreport.txt /sysroot/root/SIS_Install_logs/
    else
        logwarn "/sysroot/root does not exists"
        shellout "/sysroot/root does not exists"
    fi
}

################################################################################
#
# Find system filesystems and store them in /tmp/system_mounts.txt
# This file will be used to bind mount and unmount those filesystems in the image
# so the postinstall will work.
#
find_os_mounts() {
    loginfo "System specific mounted filesystems enumeration"
    findmnt -o target --raw|grep -v /sysroot |grep -v '^/$'|tail -n +2 > /tmp/system_mounts.txt
    loginfo "Found:"
    loginfo "$(cat /tmp/system_mounts.txt)"
    test -s "/tmp/system_mounts.txt" || shellout "No OS specific special filesystems found"
}

################################################################################
#
# Mount OS virtual filesystems for /sysroot so chrooted cmd can work.
#
#
mount_os_filesystems_to_sysroot() {
    # 1st, we enumerates what filesystems to bindmount
    find_os_mounts
    # 2nd, then we do the binds.
    loginfo "bindin OS filesystems to image"
    test -s /tmp/system_mounts.txt || shellout
    for filesystem in $(cat /tmp/system_mounts.txt)
    do
        loginfo "Bind-mount ${filesystem} to /sysroot${filesystem}"
        test -d "/sysroot${filesystem}" || mkdir -p "/sysroot${filesystem}" || shellout
        # In case of failure, we die as next steps will fail.
        mount -o bind "${filesystem}" "/sysroot${filesystem}" || shellout "Failed to bind-mount ${filesystem} to /sysroot${filesystem} ."
    done
}

################################################################################
#
# Umount OS virtual filesystems from /sysroot so umount /sysroot can succeed later
#
#

umount_os_filesystems_from_sysroot()
{
    UMOUNT_ERR=0
    loginfo "Unmounting OS filesystems from image"
    test -s /tmp/system_mounts.txt || shellout
    # using tac (reverse cat) to unmount in the correct umount order.
    for mountpoint in $(tac /tmp/system_mounts.txt)
    do
        if test -d $mountpoint
        then
            if umount /sysroot${mountpoint}
            then
                loginfo "unmounted /sysroot${mountpoint}"
            else
                # In case of failure we just report the issue. (imaging is finished in theory)".
                logwarn " failed to umount /sysroot${mountpoint}"
                UMOUNT_ERR=1
            fi
        fi
    done
    # If no error, we can remove the list of mount points.
    [ "$UMOUNT_ERR" -eq 0 ] && rm -f /tmp/system_mounts.txt
    return $UMOUNT_ERR
}

################################################################################
#
#  get_arch
#
# Usage: get_arch; echo $ARCH
get_arch() {
    ARCH=`uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/`
    loginfo "Detected ARCH=$ARCH"
}

################################################################################
#
# refuse_to_run_on_a woring machine.

fail_if_run_from_working_machine() {
	ERR_MSG="Sorry.  Must not run on a working machine..."

	# Test for mounted SCSI or IDE disks
	mount | grep [hs]d[a-z][1-9] > /dev/null 2>&1
	[ $? -eq 0 ] &&  shellout "$ERR_MSG"

	# Test for mounted software RAID devices
	mount | grep md[0-9] > /dev/null 2>&1
	[ $? -eq 0 ] &&  shellout "$ERR_MSG"

	# Test for mounted hardware RAID disks
	mount | grep c[0-9]+d[0-9]+p > /dev/null 2>&1
	[ $? -eq 0 ] &&  shellout "$ERR_MSG"
}
