#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# "SystemImager"
#
#  Copyright (C) 1999-2018 Brian Elliott Finley <brian@thefinleys.com>
#  Code written by Olivier LAHAYE.
#
#  $Id$
#
#
# This file will cleanup all remaining systemimager stuffs (processes, files, env, ...) from initrd

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type send_monitor_msg >/dev/null 2>&1 || . /lib/systemimager-lib.sh

logstep "systemimager-cleanup"

. /tmp/variables.txt

# Now we can kill the monitor, everything is finished we are just before swap-root and normal boot.
if test -s /run/systemimager/si_monitor.pid; then
    MONITOR_PID=`cat /run/systemimager/si_monitor.pid`
    loginfo "Stopping remote monitor task: PID=$MONITOR_PID. (last monitor message)"
    rm -f /run/systemimager/si_monitor.pid
    # Making sure it is an integer.
    test -n "${MONITOR_PID//[0-9]/}" && shellout "Can't kill monitor task: /run/systemimager/si_monitor.pid is not a pid."
    if [ -n "$MONITOR_PID" ]; then
        kill -9 $MONITOR_PID
        # wait $MONITOR_PID # Make sure process is killed before continuing.
        # (We can't use shell wait because process is not a child of this shell)
        while test -e /proc/${MONITOR_PID}
        do
            sleep 0.5
        done
        # At this point systemimager log helpers like loginfo, logwarn, logerror, ... may not be saved and seen remotely.
        loginfo "SystemImager remote monitor task stopped"
    fi
fi

# Prevent ourself to reenter wait imaging loop when doing directboot and something goes wrong.
# New dracut (CentOS-7 and newer)
test -f /usr/lib/dracut/hooks/initqueue/finished/90-systemimager-wait-imaging.sh && \
    rm -f /usr/lib/dracut/hooks/initqueue/finished/90-systemimager-wait-imaging.sh
# Old dracut (CentOS-6)
test -f /initqueue-finished/90-systemimager-wait-imaging.sh && \
    rm -f /initqueue-finished/90-systemimager-wait-imaging.sh

# Now we can clean systemimager garbages.
logdebug "Cleaning systemimager garbage (/run/systemimager/* SIS_action fstab.image grub_default.cfg mdadm.conf.temp variables.txt)"
rm -rf /run/systemimager/*
(cd /tmp; rm -f SIS_action fstab.image grub_default.cfg mdadm.conf.temp variables.txt)

if test -d "${STAGING_DIR}"
then
	logdebug "Cleaning staging dir: ${STAGING_DIR}/*.*"
	rm -rf ${STAGING_DIR}/*.*
fi


# Umount /scripts ramfs filesystem
logdebug "Unmounting ${SCRIPTS_DIR} ramfs filesystem"
umount ${SCRIPTS_DIR} || logerror "Failed to umount ${SCRIPTS_DIR}"

# We are in directbootmode, thus more message may have raised up.
# At this point, rootfs is mounted to /sysroot again.
# So we can try to save an updated si_monitor.log to imaged system.
if test -f /sysroot/root/SIS_Install_logs/si_monitor.log
then
    if test -d /dev/.initramfs/ # old distros
    then
        loginfo "Saving ultimate version of /root/SIS_Install_logs/si_monitor.log to /dev/.initramfs"
	mkdir -p /dev/.initramfs/systemimager
	cp -f /tmp/si_monitor.log /dev/.initramfs/systemimager/si_monitor.log
    elif test -f /run/initramfs/ # new distros
    then
        loginfo "Saving ultimate version of /root/SIS_Install_logs/si_monitor.log to /run/initramfs"
	mkdir -p /run/initramfs/systemimager/
        cp -f /tmp/si_monitor.log /run/initramfs/systemimager/si_monitor.log
    fi
fi

unset SIS_SYSMSG_ENABLED
loginfo "Disconnecting life support!"
loginfo "Control given back to system..."
