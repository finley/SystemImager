#!/bin/bash
#
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
#      This file will cleanup all remaining systemimager stuffs (processes, files,
#      env, ...) from initrd
#

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type update_client_status >/dev/null 2>&1 || . /lib/systemimager-lib.sh

logstep "systemimager-cleanup"

. /tmp/variables.txt

# Now we can kill the monitor, everything is finished we are just before swap-root and normal boot.
stop_monitor_task

# Prevent ourself to reenter wait imaging loop when doing directboot and something goes wrong.
test -f "$f" && rm -f $f

# New dracut (CentOS-7 and newer)
#test -f /usr/lib/dracut/hooks/initqueue/finished/90-systemimager-wait-imaging.sh && \
#    rm -f /usr/lib/dracut/hooks/initqueue/finished/90-systemimager-wait-imaging.sh
# Old dracut (CentOS-6)
#test -f /initqueue-finished/90-systemimager-wait-imaging.sh && \
#    rm -f /initqueue-finished/90-systemimager-wait-imaging.sh

# Now we can clean systemimager garbages.
logdebug "Cleaning systemimager garbage (SIS_action fstab.image grub_default.cfg mdadm.conf.temp)"
(cd /tmp; rm -f SIS_action fstab.image grub_default.cfg mdadm.conf.temp)

if test -d "${STAGING_DIR}" -a "${STAGING_DIR}" != "/"
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
# the initramfs swaproot persistent dir is:
# - /dev/.initramfs on old distros/dracut
# - /run/initramfs on modern distro/dracut
for initramfs_persistent_dir in {/dev/.,/run/}initramfs
do
	if test -d ${initramfs_persistent_dir}
	then
		mkdir -p ${initramfs_persistent_dir}/systemimager
		loginfo "Saving ultimate version of si_monitor.log and variables.txt to ${initramfs_persistent_dir}/systemimager/"
		cp -f /tmp/{si_monitor.log,si_dracut.log,variables.txt} ${initramfs_persistent_dir}/systemimager/
	fi
done

unset SIS_SYSMSG_ENABLED

logdebug "Checking that plymouthd is available in installed client"

if test -x /sysroot/sbin/plymouthd -o -x /sysroot/usr/sbin/plymouthd
then
        logdebug "plymouthd available in installed client. Keeping splash"
else
        logwarn "plymouthd not available in installed client. Closing splash"
        plymouth --quit
fi

# Stop the log dispatcher task.
stop_log_dispatcher

logmessage local0.info systemimager "Disconnecting life support!"
logmessage local0.info systemimager "Control given back to system..."

# TODO: Kill log forwarding task (socat)
# Ugly hack for now using killall
sleep 1.1s # Wait for socat to flush its buffers.(every 1s)
killall -q -HUP socat

