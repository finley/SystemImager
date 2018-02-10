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

logdebug "==== systemimager-deploy-client ===="

# 1st, check that we have IMAGENAME. It is used by init_transfer() to compute IMAGESIZE
# That is then later used by start_report_task() to compute transfert progress.
if test -z "$IMAGENAME"
then
	logerror "IMAGENAME not set!"
	loginfo  "set rd.sis.image-name= cmdline parameter or"
	loginfo  "set IMAGENAME= in ${IMAGESERVER}:/etc/systemimager/sis-image.conf and"
	loginfo  "set rd.sis.conf=sis-image.conf"
	shellout "IMAGENAME not set!"
fi

# Then, detect attached disks si ${DISKS[@]} gets initialized.
# ${DISKS[@]}: exported table of detected disk devices.
detect_storage_devices

# load image transfer API and compute IMAGESIZE
loginfo "Initializing protocol: $DL_PROTOCOL ..."
init_transfer
. /tmp/variables.txt # re-read variables.

# Start si_monitor progress and status report.
#loginfo "Starting monitor progress report task..."
#start_report_task

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

# Download install scripts and disk layouts.
# TODO: move this function in protocol plugins.
get_scripts_directory

# HOSTNAME may already be set via cmdline, dhcp or local.cfg
if [ -z "$HOSTNAME" ]; then
    get_hostname_by_hosts_file
fi

if [ -z "$HOSTNAME" ]; then
    get_hostname_by_dns
fi

if [ -n "$HOSTNAME" ]; then
    loginfo "This hostname is: $HOSTNAME"
fi

# Give pre-install scripts a chance to do stuffs before we lay down the image.
run_pre_install_scripts

# If none of SCRIPTNAME, HOSTNAME, or IMAGENAME is set, then we cannot proceed.
# (IMAGENAME may have been set by local.cfg).  -BEF-
if [ -z $SCRIPTNAME ] && [ -z $IMAGENAME ] && [ -z $HOSTNAME ]; then
    logwarn "FATAL:  None of SCRIPTNAME, IMAGENAME, or HOSTNAME were set, and I"
    logwarn "can no proceed!  (Scottish accent -- think Groundskeeper Willie)"
    logwarn ""
    logwarn "HOSTNAME is what most people use, and I try to determine it automatically"
    logwarn "from this hosts IP address ($IPADDR) in the following order:"
    logwarn ""
    logwarn "  1)  /var/lib/systemimager/scripts/hosts on your imageserver"
    logwarn "  2)  DNS"
    logwarn ""
    logwarn "Finally, you can explicitly set many variables pre-boot, including SCRIPTNAME,"
    logwarn "IMAGENAME, and HOSTNAME, as kernel append parameters or with a local.cfg file."

    shellout
fi

# Prepare disks and mount them as described in disk layour file (autoinstallscript.conf xml file)
sis_prepare_disks

# Mount os filesystems to /sysroot (will shellout in case of failure)
mount_os_filesystems_to_sysroot

# Run the autoinstall script (image installation)
run_autoinstall_script

# Download and install the image
download_image # Download and extract image if no staging dir is used
extract_image  # Extract image to /sysroot if staging dir was used, else do noting
install_overrides # download and install override files

# Install fstab, mdadm.conf, lvm.conf and update initramfs so it is aware of raid or lvm
sis_install_configs

# Leave notice of which image is installed on the client
mkdir -p /sysroot/etc/systemimager/
echo $IMAGENAME > /sysroot/etc/systemimager/IMAGE_LAST_SYNCED_TO || shellout "Failed to save IMAGENAME in /etc/systemimager/IMAGE_LAST_SYNCED_TO"

# Now install bootloader (before post_install scripts to give a chance to scripts to modify this)
# OL: TODO: We should be smarter here. We should install bootloader only on the disk containing the /boot partition.
# OL: TODO: We should handle software raid.
install_boot_loader ${DISKS[@]}

# Now run post install scripts.
run_post_install_scripts

# SE Linux relabel
SEL_FixFiles

# Save virtual console session in the imaged client
[ ! -d /sysroot/root ] && mkdir -p /sysroot/root
save_logs_to_sysroot # Saves /tmp/relevant install infos to /root/SIS_Install/

# Setup kexec if necessary
# TODO

# Unmount system filesystems
umount_os_filesystems_from_sysroot

# Unmount imaged OS filesystems (they are listed in initrd:/etc/fstab)
# We can't use /sysroot/etc/fstab as it also contain swap and other stuffs
# like some nfs mountpoints added by postinstall scripts
loginfo "Unmounting imaged OS filesystems"
for mount_point in `cat /etc/fstab|grep sysroot|awk '{print $2}'|sort -r -k2,2`
do
	logdebug "Unmounting $mount_point"
	umount $mount_point || logerror "Failed to umount $mount_point" # don't fail here, image is on disk.
done

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
terminate_transfer

# Announce completion (even for non beep-incessantly --post-install options)
beep 3

# Everything is finished. Tell initqueue/finished that we are done.
# $SIS_POST_ACTION can contain: shell, reboot, shutdown, (emergency is reserved)
# It is set as PXE cmdline parameter rd.sis.post-action
# default value is "reboot".
# This action can be overrided in /tmp/SIS_action by imaging script
test ! -e /tmp/SIS_action && echo "${SIS_POST_ACTION}" > /tmp/SIS_action

