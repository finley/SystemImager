#!/bin/sh
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
# This file will cleanup all remaining systemimager stuffs i(processes, files, env, ...) from initrd

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type send_monitor_msg >/dev/null 2>&1 || . /lib/systemimager-lib.sh

logdebug "==== systemimager-cleanup ===="

. /tmp/variables.txt

# We are in directbootmode, thus more message may have raised up.
# At this point, rootfs is mounted to /sysroot again.
# Si we can try to save an updated si_monitor.log to imaged system.
if test -f /sysroot/root/SIS_Install_logs/si_monitor.log
then
    loginfo "Updating /root/SIS_Install_logs/si_monitor.log in image with latests logs"
    cp -f /tmp/si_monitor.log /root/SIS_Install_logs/si_monitor.log
fi

# Now we can kill the monitor, everything is finished we are just before swap-root and normal boot.
if test -s /run/systemimager/si_monitor.pid; then
    loginfo "Stopping remote monitor task. (last monitor message)"
    MONITOR_PID=`cat /run/systemimager/si_monitor.pid`
    rm -f /run/systemimager/si_monitor.pid
    # Making sure it is an integer.
    test -n "`echo ${MONITOR_PID}|sed -r 's/[0-9]*//g'`" && shellout "Can't kill monitor task: /run/systemimager/si_monitor.pid is not a pid."
    if [ ! -z "$MONITOR_PID" ]; then
        kill -9 $MONITOR_PID
        # wait $MONITOR_PID # Make sure process is killed before continuing.
        # (We can't use shell wait because process is not a child of this shell)
        while test -e /proc/${MONITOR_PID}
        do
            wleep 0.5
        done
        info "Remote monitor task stopped"
    fi
fi

# Now we can clean systemimager specific stuffs
rm -rf /run/systemimager /tmp/tmpfs_staging
(cd /tmp; rm -f SIS_action fstab.temp grub_default.cfg mdadm.conf.temp si_monitor.log variables.txt)

unset SIS_SYSMSG_ENABLED

