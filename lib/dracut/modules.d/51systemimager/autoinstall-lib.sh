#!/bin/bash
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
PARTED_UNIT=MB

################################################################################
#
#   Save the SIS imaging relevant logs to /root/SIS_Install_logs/ on the imaged
#   computer.
#
#
#
save_logs_to_sysroot() {
    loginfo "Saving logs to /sysroot/root..."
    if test -d /sysroot/root
    then
        mkdir -p /sysroot/root/SIS_Install_logs/
        cp /tmp/variables.txt       /sysroot/root/SIS_Install_logs/
	test -r /tmp/dhclient.${DEVICE}.dhcpopts && cp /tmp/dhclient.${DEVICE}.dhcpopts /sysroot/root/SIS_Install_logs/
	test -r /tmp/net.${DEVICE}.override && cp /tmp/net.${DEVICE}.override /sysroot/root/SIS_Install_logs/
        cat /tmp/si_monitor.log | sed -E 's/\[[0-9]{2}m//g' > /sysroot/root/SIS_Install_logs/si_monitor.log
        echo "${IMAGENAME}" >         /sysroot/root/SIS_Install_logs/image.txt
        test -f /run/initramfs/rdsosreport.txt && cp /run/initramfs/rdsosreport.txt /sysroot/root/SIS_Install_logs/
    else
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
    loginfo "Looking for system specific mounted filesystems..."
    findmnt -o target --raw|grep -v /sysroot | grep -v "${SCRIPTS_DIR}" | grep -v '^/$'|tail -n +2 > /tmp/system_mounts.txt
    logdebug "Found:"
    cat /tmp/system_mounts.txt | while read filesystem
    do
        logdebug "  - $filesystem"
    done
    test -s "/tmp/system_mounts.txt" || logerror "No OS specific special filesystems found! Unexpected situation. Trying to continue."
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
    loginfo "Binding system filesystems to image"
    test -s /tmp/system_mounts.txt || shellout "/tmp/system_mounts.txt doesn't exists. find_os_mounts() failed???"
    cat /tmp/system_mounts.txt | while read filesystem
    do
	# test "$filesystem" = "${SCRIPTS_DIR}" && continue
        logdetail "Bind-mount ${filesystem} to /sysroot${filesystem}"
        test -d "/sysroot${filesystem}" || mkdir -p "/sysroot${filesystem}" || shellout "Failed to mkdir -p /sysroot${filesystem}"
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
    loginfo "Unmounting binded system filesystems from image"
    test -s /tmp/system_mounts.txt || shellout "/tmp/system_mounts.txt doesn't exists or is empty."
    # using tac (reverse cat) to unmount in the correct umount order.
    tac /tmp/system_mounts.txt | while read mountpoint
    do
        if test -d /sysroot${mountpoint}
        then
            if umount /sysroot${mountpoint}
            then
                logdetail "Unmounted /sysroot${mountpoint}"
            else
                # In case of failure we just report the issue. (imaging is finished in theory)".
                logwarn "failed to umount /sysroot${mountpoint}"
                UMOUNT_ERR=1
            fi
        else
	    logerror "/sysroot${mountpoint} is NOT a directory!!! Can't unmount it"
	    UMOUNT_ERR=1
        fi
    done
    # If no error, we can remove the list of mount points.
    [ "$UMOUNT_ERR" -eq 0 ] && rm -f /tmp/system_mounts.txt
    return $UMOUNT_ERR
}

################################################################################
#
# set_ip_assignment_method replicant|static|dhcp
# OL: BUG: Not sure it is still relevant.

set_ip_assignment_method() {
	case "$1" in
		replicant|static|dhcp)
			IP_ASSIGNMENT_METHOD=$1
			write_variables
			;;
		*)
			shellout "Invalid IP assignment method: [$IP_ASSIGNMENT_METHOD]"
			;;
	esac
}

################################################################################
#
# refuse_to_run_on_a woring machine.
# Note: this function is now obsolete and is here for compatibility.
# It will prevent old scripts to be run on a running host.
#
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

################################################################################
#
# detect_storage_devices => returns a list of attached mass storage devices (disks / flash / ... excluding cdroms)
#
detect_storage_devices() {
    loginfo "Detecting disks..." # (-e 2 => exclude floppies (block disk with device major = 2 and ramdisks (major=1) on old distros)
    DISKS=( `lsblk -d -r -e 1,2 -o NAME,TYPE|grep -i disk|sed -e 's/^/\/dev\//g' -e 's/!/\//g'|cut -d' ' -f1` )

    if test ${#DISKS[@]} -eq 0
    then
        beep
        beep
        logerror ""
        logerror "NO DISK DEVICE FILES WERE FOUND.  THIS USUALLY MEANS THE KERNEL DID NOT"
        logerror "RECOGNIZE ANY OF THE ATTACHED DISKS."
        logerror ""
        logerror "The kernel boot messages, which preceded this, may indicate why."
        logerror ""
        logerror "Reverting to disk configuration specified by image master script."
        logerror ""
    else
        loginfo "Found ${#DISKS[*]} disk(s): ${DISKS[*]}"
	write_variables
        beep
    fi
}


################################################################################
#
# print_partition_table <disk device>
#
print_partition_table() {
    if test -z `echo ${DISKS[@]} |grep "$1"`""
    then
	    shellout "$1 is not a disk device; can't print layout."
    fi

    LC_ALL=C parted -s -- $1 print > /dev/console
}

################################################################################
#
# wipe_out_partition_table <disk device> <partition type=msdos|gpt>
#      => Print old partition table and create a new empty one.
#
wipe_out_partition_table() {
    if test -z `echo ${DISKS[@]} |grep "$1"`""
    then
	    shellout "$1 is not a disk device; can't wipe out its partition table."
    fi

    logdetail "Old partition table for $1:"
    print_partition_table $1

    # Wipe the MBR (Master Boot Record) clean.
    loginfo "Whipping out old partition table on disk $1 !"
    logaction "dd if=/dev/zero of=$1 bs=512 count=1"
    dd if=/dev/zero of=$1 bs=512 count=1 || shellout "dd if=/dev/zero of=$1 failed"

    # Avoid disk driver being buzy later
    sleep 0.5s

    # Make sure kernel is aware of the partition table wipe out.
    _reread_partition_table $1

    # Create new partition table
    PART_TYPE="$2"
    # default to GPT partition table
    [ -n "$PART_TYPE" ] || PART_TYPE="gpt"
    loginfo "Initializing new partition table for disk $1: type=$PART_TYPE"
    logaction "parted -s -- $1 mklabel $PART_TYPE"
    LC_ALL=C parted -s -- $1 mklabel $PART_TYPE || shellout "Failed to create new partition table for disk $1 partition type=$PART_TYPE!"

    # Avoid disk driver being buzy later
    sleep 0.5s
}

################################################################################
#
# add_partition <disk_device> <size($PARTED_UNIT)> [<part_type>]
# - disk_device: full path of the disk device. example: /dev/sda
# - size: The partition requested size in unit $PARTED_UNIT (or 0 (zero) for all space left)
# - part_type: All parted partition types accepted by mkpart comand. (optional; default primary)
#
add_partition() {
    if test -z `echo ${DISKS[@]} |grep "$1"`""
    then
            shellout "$1 is not a disk device; add_partition $1 ${2}$PARTED_UNIT failed."
    fi

    TYPE="$3"
    [ -n "$3" ] || TYPE="primary"

    if test "$2" -gt 0
    then
        START=`LC_ALL=C parted -s -- $1 unit $PARTED_UNIT print free | grep "Free Space" | sed "s/$PARTED_UNIT//g" | awk -v size="$2" '$3 > size {print $1;exit 0}'`
        # Round START to next unit
        START=$((${START%.*}+1))
	END=$(( $START + $2 ))
    else # we want the end of disk.
        BIGGEST_FREE_BLOCK=( `LC_ALL=C parted -s -- $1 unit $PARTED_UNIT print free|grep "Free Space"|sed "s/$PARTED_UNIT//g"|awk 'START {S=0;E=0} $3 > S {S=$1;E=$2} END { print S " " E }'` )

	START=${BIGGEST_FREE_BLOCK[0]}
        # Round START to next unit
        START=$((${START%.*}+1))

	END=${BIGGEST_FREE_BLOCK[1]}
        # Round END
        END=$((${END%.*}+0))
    fi

    if test -z "${START}"
    then
	    logerror "Insufficient space in $1 for a ${2}$PARTED_UNIT partition"
	    BIGGEST_SPACE=`LC_ALL=C parted -s -- $1 unit $PARTED_UNIT print free|grep "Free Space"|sed "s/$PARTED_UNIT//g"|awk 'START {S=0} $3 > S {S=$1} END {print S}'`
	    logerror "Available space: ${BIGGEST_SPACE}"
	    shellout "add_partition() failed: Insufficient space"
    fi

    loginfo "Adding a partition to $1 start: ${START} end: ${END} type: ${TYPE}"
    logaction "parted -s -- $1 unit ${PARTED_UNIT} mkpart ${TYPE} ${START} ${END}"
    LC_ALL=C parted -s -- $1 unit ${PARTED_UNIT} mkpart ${TYPE} ${START} ${END} || shellout "parted failed to create partition".
}

################################################################################
#
# set_partition_flag() <disk_device> <partition_number> <flag>
#     - flag can bee: boot, esp, root, swap, ...
# => set the partition flag to "on".
#
set_partition_flag() {
    if test -z `echo ${DISKS[@]} |grep "$1"`""
    then
            shellout "$1 is not a disk device; set partition type failed."
    fi

    loginfo "Setting partition flag $3=on on partition $1$2."
    if test "$3" = "esp"
    then
	logaction "parted -s -- $1 set $2 $3 on"
	if ! parted -s -- $1 set $2 esp on
	then
		logwarn "parted doesn't seem to support esp flag. Trying boot flag instead"
		LC_ALL=C parted -s -- $1 set $2 boot on || shellout "parted failed to set boot=on for $1$2."
	fi
    else
	 LC_ALL=C parted -s -- $1 set $2 $3 on || shellout "parted failed to set $3=on for $1$2."
    fi
}

################################################################################
################################################################################
# Private API below.

################################################################################
#
# _reread_partition_table() <disk_device>
# => for kernel to reread the partition table.
#
_reread_partition_table() {
    # Make sure we got a disk device.
    if test -z `echo ${DISKS[@]} |grep "$1"`""
    then
            shellout "$1 is not a disk device."
    fi

    # Inform kernel of new partition table.
    CMD="blockdev --rereadpt $1"
    loginfo "$CMD"
    $CMD || shellout "Failed to re-read partition table!"

    # Avoid disk driver being buzy later
    sleep 0.5s
}


