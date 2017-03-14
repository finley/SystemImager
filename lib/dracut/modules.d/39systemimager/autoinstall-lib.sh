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
        cp /tmp/variables.txt /sysroot/root/SIS_Install_logs/
        cp /tmp/dhcp_info.${DEVICE} /sysroot/root/SIS_Install_logs/
        cp /tmp/si_monitor.log /sysroot/root/SIS_Install_logs/
        cp /tmp/si.log /sysroot/root/SIS_Install_logs/
	echo ${IMAGENAME} > /sysroot/root/SIS_Install_logs/image.txt
        test -f /run/initramfs/rdsoreport.txt && cp /run/initramfs/rdsoreport.txt /sysroot/root/SIS_Install_logs/
    else
        logwarn "/sysroot/root does not exists"
        shellout
    fi
}

################################################################################
#
# Mount OS virtual filesystems for /sysroot so chrooted cmd can work.
#
#

mount_os_filesystems_to_sysroot() {
    for mountpoint in /dev /proc /run /sys
    do
        if test -d $mountpoint
        then
            loginfo "Binding mount point ${mountpoint} to /sysroot${mountpoint} ."
            mkdir -p /sysroot${mountpoint} || shellout
            # In case of failure, we die as next steps will fail.
            mount -o bind ${mountpoint} /sysroot${mountpoint} || shellout
        fi
    done
}

################################################################################
#
# Umount OS virtual filesystems from /sysroot so umount /sysroot can succeed later
#
#

umount_os_filesystems_from_sysroot()
{
    for mountpoint in /dev /proc /run /sys
    do
        if test -d $mountpoint
        then
            if umount /sysroot${mountpoint}
            then
                loginfo "unmounted /sysroot${mountpoint}"
                return 0
            else
                # In case of failure we just report the issue. (imaging is finished in theory)".
                logwarn " failed to umount /sysroot${mountpoint}"
                return 1
            fi
        fi
    done
}

