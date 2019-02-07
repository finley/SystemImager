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
# This file is the main systemimager dracut module logic. It is responsible for
# deploying the image on the client (it downloads, choses and run the
# deployment scripts).

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh
type save_logs_to_sysroot >/dev/null 2>&1 || . /lib/autoinstall-lib.sh
type sis_prepare_disks >/dev/null 2>&1 || . /lib/disksmgt-lib.sh

# Load variables.txt
. /tmp/variables.txt

logdebug "==== systemimager-deploy-client ===="

# 1st, check that we have IMAGENAME. It is used by init_transfer() to compute IMAGESIZE
# That is then later used by start_report_task() to compute transfert progress.
if test -z "$IMAGENAME"
then
	logerror "IMAGENAME not set!"
	loginfo  "set si.image-name= cmdline parameter or"
	loginfo  "set IMAGENAME= in ${IMAGESERVER}:/var/lib/systemimager/scripts/configs/<configname>.conf and"
	loginfo  "set si.conf=<vonfigname>.conf"
	shellout "IMAGENAME not set!"
fi

# Then, detect attached disks si ${DISKS[@]} gets initialized.
# ${DISKS[@]}: exported table of detected disk devices.
detect_storage_devices

# load image transfer API and compute IMAGESIZE
loginfo "Initializing protocol: $DL_PROTOCOL ..."
init_transfer
. /tmp/variables.txt # re-read variables.

if [ "$TMPFS_STAGING" = "yes" ]; then
    tmpfs_watcher
fi

if [ "x$SSHD" = "xy" ]; then
    loginfo "SSHD=y => start_sshd"
    start_sshd
fi

if [ ! -z "$SSH_DOWNLOAD_URL" ]; then
    SSH=y
fi
if [ "x$SSH" = "xy" ]; then
    loginfo "SSH=y => start_ssh"
    start_ssh
fi

# Give pre-install scripts a chance to do stuffs before we lay down the image.
getarg 'si.break=pre-install' && logwarn "Break pre-install" && interactive_shell
run_pre_install_scripts
. /tmp/variables.txt # Read variables that could have been updated in pre-install script like IMAGENAME

# If none of SCRIPTNAME, HOSTNAME, or IMAGENAME is set, then we cannot proceed.
# (IMAGENAME may have been set by local.cfg).  -BEF-
if [ -z $SCRIPTNAME ] && [ -z $IMAGENAME ] && [ -z $HOSTNAME ]; then
    logerror "FATAL:  None of SCRIPTNAME, IMAGENAME, or HOSTNAME were set, and I"
    logerror "can no proceed!  (Scottish accent -- think Groundskeeper Willie)"
    logerror ""
    logerror "HOSTNAME is what most people use, and I try to determine it automatically"
    logerror "from this hosts IP address ($IPADDR) in the following order:"
    logerror ""
    logerror "  1)  /var/lib/systemimager/scripts/hosts on your imageserver"
    logerror "  2)  DNS"
    logerror ""
    logerror "Finally, you can explicitly set many variables pre-boot, including SCRIPTNAME,"
    logerror "IMAGENAME, and HOSTNAME, as kernel append parameters or with a local.cfg file."

    shellout "None of SCRIPTNAME, IMAGENAME, or HOSTNAME were set"
fi

# Prepare disks and mount them as described in disk layout file (autoinstallscript.conf xml file)
getarg 'si.break=prepare-disks' && logwarn "Break prepare-disks" && interactive_shell
sis_prepare_disks

# Run the autoinstall script (before image installation).
# the autoinstall script (also called main-install) is optional.
getarg 'si.break=main-install' && logwarn "Break main-install" && interactive_shell
run_autoinstall_script # Last chance to set IMAGENAME
. /tmp/variables.txt # Read variables that could have been updated in autoinstall script like IMAGENAME

# Download and install the image
if test -z "${IMAGENAME}"
then
	logerror "FATAL: IMAGENAME not set, I cannot proceed!"
	logerror "Set it in cmdline parameter, dhcp options, /var/lib/systemimager/scripts/configs/"
	logerror "or set it in pre install scripts or main-install script"
	shellout "IMAGENAME not set"
fi

getarg 'si.break=download-image' && logwarn "Break download-image" && interactive_shell
download_image # Download and extract image if no staging dir is used

getarg 'si.break=extract-image' && logwarn "Break extract-image" && interactive_shell
extract_image  # Extract image to /sysroot if staging dir was used, else do noting

getarg 'si.break=install-overrides' && logwarn "Break install-overrides" && interactive_shell
install_overrides # download and install override files

# Mount os filesystems to /sysroot (will shellout in case of failure)
# We need devices for sis_install_config (chroot /sysroot vgscan at least)
mount_os_filesystems_to_sysroot

# Install fstab, mdadm.conf, lvm.conf and update initramfs so it is aware of raid or lvm
getarg 'si.break=install-configs' && logwarn "Break install-configs" && interactive_shell
sis_install_configs

# Avoid having mounted filesystems buzy
cd /tmp

# Leave notice of which image is installed on the client
mkdir -p /sysroot/etc/systemimager/
echo "${IMAGENAME}" > /sysroot/etc/systemimager/IMAGE_LAST_SYNCED_TO || shellout "Failed to save IMAGENAME in /etc/systemimager/IMAGE_LAST_SYNCED_TO"

# Now install bootloader (before post_install scripts to give a chance to scripts to modify this)
getarg 'si.break=boot-loader' && logwarn "Break boot-loader" && interactive_shell
si_install_bootloader

# Now run post install scripts.
getarg 'si.break=post-install' && logwarn "Break post-install" && interactive_shell
run_post_install_scripts

# SE Linux relabel
getarg 'si.break=se-linux' && logwarn "Break se-linux" && interactive_shell
SEL_FixFiles

# Save virtual console session in the imaged client
[ ! -d /sysroot/root ] && mkdir -p /sysroot/root
save_logs_to_sysroot # Saves /tmp/relevant install infos to /root/SIS_Install/

# Setup kexec if necessary
# TODO

# Keep track of available modules versions in imaged system in case "directboot" is set as POST_ACTION
IMAGED_MODULES=`(cd /sysroot/lib/modules; echo *)` # no need to store it in variables.txt (we are sourced from initqueue hook).
write_variables # Need to save that for non systemd dracut (we are run from udev online, not initqueue/online on those old stuffs)

# Install the systemimager-montor-rebooted service before we umount client filesystems.
/lib/systemimager-install-rebooted-script

# Unmount system filesystems
umount_os_filesystems_from_sysroot

# Unmount imaged OS filesystems (they are listed in initramfs:/etc/fstab.systemimager)
# We can't use /sysroot/etc/fstab as it also contain swap and other stuffs
# like some nfs mountpoints added by postinstall scripts

# 1st, check that NFS rpc_pipefs was not mounted during postinstall scripts. 
RPC_PIPEFS_MOUNTED=`mount|grep -E '/sysroot/.*/rpc_pipefs'|cut -d' ' -f3`
if test -n "${RPC_PIPEFS_MOUNTED}"
then
	logwarn "NFS rpc_pipefs mounted in image!"
	logwarn "Check your postinstall scripts for possible NFS related services started"
	logwarn "Use --no-reload option when enabling services using systemctl"
	logwarn "For example, use 'systemctl --no-reload enable rdma.service' to"
	logwarn "enable rdma service"
	loginfo "Unmounting ${RPC_PIPEFS_MOUNTED} filesystem from image"
	umount ${RPC_PIPEFS_MOUNTED} || logerror "Failed to umount ${RPC_PIPEFS_MOUNTED}"
fi

loginfo "Unmounting imaged OS filesystems"
getarg 'si.break=umount-client' && logwarn "Break umount-client" && interactive_shell
cat /etc/fstab.systemimager|grep sysroot|awk '{print $2}'|sort -r -k2,2| while read mount_point
do
	logdebug "Unmounting $mount_point"
	umount $mount_point || logerror "Failed to umount $mount_point" # don't fail here, image is on disk.
done

# We need to cleanup /sysroot/proc and such otherwise, dracut won't try to mount realroot if we chose "directboot"
loginfo "Cleaning up /sysroot remaining garbage dirs"
find /sysroot -not -iwholename '/sysroot' -type d -prune -exec rmdir {} \;

if test `ls /sysroot|wc -l` -gt 0
then
	logwarn "/sysroot still not empty!!!"
	logwarn "Content: "$(echo /sysroot/*)
fi

# Tell the image server we are done
rsync $IMAGESERVER::scripts/imaging_complete_$IPADDR > /dev/null 2>&1
loginfo "Imaging completed"

if [ -n "$MONITOR_SERVER" ]; then
    # Report the 'imaged' state to the monitor server.
    send_monitor_msg "status=100:speed=0"
    if [ "x$MONITOR_CONSOLE" = "xy" ]; then
        MONITOR_CONSOLE=yes
    fi
    if [ "x$MONITOR_CONSOLE" = "xyes" ]; then
        # Print some empty lines and sleep some seconds to give time to
        # the virtual console to get last messages.
        # XXX: this is a dirty solution, we should find a better way to
        # sync last messages... -AR-
        logmsg ""
        logmsg ""
        logmsg ""
        sleep 10
    fi
    # Report the post-install action.
    send_monitor_msg "status=106:speed=0"
fi

# Stops any remaining transfer processes (ssh tunnel, torrent seeder, ...
getarg 'si.break=terminate-transfer' && logwarn "Break terminate-transfer" && interactive_shell
terminate_transfer

# Tells to dracut that root in now known.
if [ -n "$DRACUT_SYSTEMD" ]; then
	# Ask systemd to re-reun its generators (dracut-rootfs-generator). See:
	# https://www.freedesktop.org/software/systemd/man/systemd.generator.html
	# and https://bbs.archlinux.org/viewtopic.php?pid=1501024#p1501024
	systemctl daemon-reload
else
	# Udev uses the inotify mechanism to watch for changes in the rules directory, in
	# both the library and in the local configuration trees (typically located at
	# /lib/udev/rules.d and /etc/udev/rules.d). So you don't need to do anything
	# when you change a rules file.
	# udevadm control --reload-rules && udevadm trigger
	echo > /dev/null # do nothing
fi

# Announce completion (even for non beep-incessantly --post-install options)
beep 3

# Everything is finished. Tell initqueue/finished that we are done.
# $SI_POST_ACTION can contain: directboot, shell, reboot, shutdown, (emergency is reserved)
# It is set as PXE cmdline parameter si.post-action
# default value is "reboot".
SI_IMAGING_STATUS="finished"
write_variables

getarg 'si.break=finished' && logwarn "Break finished" && interactive_shell
logdebug "leaving dracut initqueue/online hook."
