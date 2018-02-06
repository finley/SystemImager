#!/bin/sh
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
# This file hosts functions realted to disk initialization.


# Load API and variables.txt (including detected disks array: $DISKS)
type logmessage >/dev/null 2>&1 || . /lib/systemimager-lib.sh

# Assumptions
# primary partitions are created at 1st in order 1, 2, 3, 4 ...
# TODO: partition are aligned to 1MiB so it fits all disks aligments.
# TODO: Enhancement: use http://people.redhat.com/msnitzer/docs/io-limits.txt if possible for optimal aligment; fallback to 1MiB aligment only if not supported.
#

# TODO: Make sure we have the XML disk configuration file.
[ -z "${AUTOINSTALL_CONF}" ] && AUTOINSTALL_CONF=/tmp/disk.conf

# Initialisae / check LVM version to use. (defaults to v2).
LVM_VERSION=`xmlstarlet sel -t -m "config/lvm" -if "@version" -v "@version" --else -o "2" -b ${AUTOINSTALL_CONF}`

################################################################################
#
# get_disks_from_autoinstall_conf()
#		Returns all raw disk devices to be configured.
#		This is usefull to check that at least we detected thoses disks
#		We can have more available disks. the extraneous disks will be
#		left untouched, but if miss some, we'll fail.
################################################################################
get_disks_from_autoinstall_conf() {
    xmlstarlet sel -t -m 'config/disk' -m "@dev" -v . -n ${AUTOINSTALL_CONF}
}

################################################################################
#
# sis_prepare_disks()
#		Main function. Processes autoinstallscript.conf xml file to
#		Prepare disks for imaging (partitions, raids, lvms, filesystems,
#		fstab and mount them so image can be deployed.
################################################################################
#		
sis_prepare_disks() {
	_do_partitions
	_do_raids
	_do_lvms
	_do_filesystems
	_do_fstab
}

################################################################################
#
# _do_partitions()
#		This function does some low level stuffs:
#			- Create the partition table
#			- Create the partitions
#
################################################################################
#
_do_partitions() {
	IFS=';'
	xmlstarlet sel -t -m 'config/disk' -v "concat(@dev,';',@label_type,';',@unit_of_measurement)" -n ${AUTOINSTALL_CONF}|\
		while read DISK_DEV LABEL_TYPE T_UNIT;
	       	do
			loginfo "Setting up partitions for disk $DISK_DEV"

			# Create the partition table
			logaction "parted -s -- $DISK_DEV mklabel ${LABEL_TYPE}"
			LC_ALL=C parted -s -- ${DISK_DEV} mklabel "${LABEL_TYPE}" || shellout "Failed to create new partition table for disk $DISK_DEV partition type=$PART_TYPE!"

			# Create the partitions
			T_UNIT=`echo $T_UNIT|sed "s/percent.*/%/g"` # Convert all variations of percent{,age{,s}} to "%"
			xmlstarlet sel -t -m "config/disk[@dev=\"${DISK_DEV}\"]/part" -v "concat(@num,';',@size,';',@p_type,';',@id,';',@p_name,';',@flags,';',@lvm_group,';',@raid_dev)" -n ${AUTOINSTALL_CONF}|\
				while read P_NUM P_SIZE P_TYPE P_ID P_NAME P_FLAGS P_LVM_GROUP P_RAID_DEV
				do
					# TODO: Add missing @raid_dev in man autoinstallscript.conf
					if test "$P_SIZE" = "*"
					then
						P_SIZE="0" # 0 means 100% for parted
					else
						P_UNIT="$T_UNIT"
					fi
					# Get partition filesystem if it exists (no raid, no lvm) so we can put it in partition filesystem info
					P_FS=`xmlstarlet sel -t -m "config/fsinfo[@real_dev=\"${DISK_DEV}${P_NUM}\"]" -v "@fs" -n ${AUTOINSTALL_CONF}`

					# 1/ Create the partition
					CMD="parted -s -- ${DISK_DEV} unit ${P_UNIT} mkpart ${P_TYPE} ${P_FS} `_find_free_space ${DISK_DEV} ${P_UNIT} ${P_TYPE} ${P_SIZE}`"
					logaction "$CMD"
					eval "LC_ALL=C $CMD" || shellout "Failed to create partition ${DISK_DEV}${P_NUM}"

					# 2/ Set partition number ($partition) using sfdisk
					# Do nothing; assuming xml file use partition in order just like parted.

					# 3/ Set the partition flags
					for flag in `echo $P_FLAGS|tr ',' ' '`
					do
						CMD="parted -s -- ${DISK_DEV} set ${P_NUM} ${flag} on"
						logaction "$CMD"
						eval "LC_ALL=C $CMD" || shellout "Failed to set flag ${flag}=on for partition ${DISK_DEV}${P_NUM}"
					done

					# Testing that lvm flag is set if lvm group is defined.
					[ -n "${P_LVM_GROUP}" ] && [ -z "`echo $P_FLAGS|grep lvm`" ] && shellout "Missing lvm flag for ${DISK_DEV}${P_NUM}"
				done
	       	done
}

################################################################################
#
# _find_free_space()
#		This functions return a "start end" positions withing available
#		space on disk that matches requirements.
#		(free space for logical partitions is searched withing extended
#		partition)
# 	- $1 disk dev
#	- $2 unit of mesurement
#	- $3 type (primary extended logical)
#	- $4 requested size
#
# TODO: Need to return aligned partitions. For this, we need to convert to MiB
#       and aligne to 1MiB so it fits all disks aligments...
# TODO: Enhancement: use http://people.redhat.com/msnitzer/docs/io-limits.txt
#       if possible for optimal aligment; fallback to 1MiB aligment only if not
#       supported by disk device.
#
################################################################################
#
_find_free_space() {
	case "$3" in
		logical)
			# if partition is logical, get the working range to seach for free space
			MIN_SIZE_EXT=( `LC_ALL=C parted -s -- $1 unit $2 print|grep "extended"|sed "s/$2//g"|awk '{ print $2 $4 }'` )
			[ ${MIN_SIZE_EXT[#]} -eq 0 ] && shellout "Can't create logical partition if no extended partition exists"
			;;
		*)
			# if primary or logical, search the whole disk
			MIN_SIZE_EXT=( 0 0 )
			;;
	esac
	# For each free space
	# if ext_size is non null (we create a logical part) and if checked free space is beyond end of extended, then abort
	# if free block start is within search space and if free block size is big enough for requested size, we found it! => print and exit
	BEGIN_END=( `LC_ALL=C parted -s -- $1 unit $2 print free | grep "Free Space" | sed "s/$2//g" | sort -g -r -k2 | awk -v min=${MIN_SIZE_EXT[0]} -v ext_size=${MIN_SIZE_EXT[1]} -v required="$4" '
	(ext_size>0) && ($1<min || $1>min+ext_zise) { exit 1 }
	($1>=min) && (($1<(min+ext_size)) || ext_size==0) && (required==0) { print $1 " " $2 ; exit 0 }
	($1>=min) && ($1+required)<=$2 && (required!=0) { print $1 " " $1+required ; exit 0 }
' ` ) || shellout "Failed to find free space for a $3 partition of size $4$2"
	echo ${BEGIN_END[@]}
}

################################################################################
# _do_raids()
#		Create software raid devices if any are defined.
#
# TODO: Save software raid device config to config file.
# TODO: at end of imaging, dracut must regenerate the initramfs with this config
#       in place, otherwise, main filesystem won't be able to be mounted.
#
################################################################################
_do_raids() {
	loginfo "Creating software raid devices if needed."
	IFS=';'
	xmlstarlet sel -t -m 'config/raid/raid_disk' -v "concat(@name,';',@raid_level,';',@raid_devices,';',@spare_devices,';',@rounding,';',@layout,';',@chunk_size,';',@lvm_group,';',@devices)" -n ${AUTOINSTALL_CONF} |\
		while read R_NAME R_LEVEL R_DEVS_CNT R_SPARES_CNT R_ROUNDING R_LAYOUT R_CHUNK_SIZE R_LVM_GROUP R_DEVICES
		do
			# If Raid volume uses partitions, get them
			P_DEVICES=`xmlstarlet sel -t -m "config/disk/part[@raid_dev=\"$R_NAME\"]"  -v "concat(ancestor::disk/@dev,@num,' ')" ${AUTOINSTALL_CONF}`
			loginfo "creating raid volume ${R_NAME} (raid${R_LEVEL})".
			[ -z "${R_SPARES_CNT}" ] && R_SPARES_CNT=0
			logdetail "Number of spares: ${R_SPARES_CNT}"
			[ -z "${R_DEVS_CNT}" ] && R_DEVS_CNT=$(( `echo "${P_DEVICES} ${R_DEVICES}"|wc -w` - ${R_SPARES_CNT} ))
			logdetail "Number of active devices: ${R_DEVS_CNT}"
			logdetail "Devices used for ${R_NAME}: ${P_DEVICES} ${R_DEVICES}"

			CMD="mdadm --create ${R_NAME} --auto=yes --level ${R_LEVEL}"
			[ -n "${R_DEVS_CNT}" ] && CMD="${CMD} --raid-devices ${R_DEVS_CNT}" # Number of raid devices
			[ -n "${R_SPARES_CNT}" ] && CMD="${CMD} --spare-devices ${R_SPARES_CNT}" # Number of spare devices
			if test -n "${R_ROUNDING}"
			then
				[ "${R_LEVEL}" -ne 1 ] && shellout "Rounding needs raid level 1."
				CMD="${CMD} --rounding ${R_ROUNDING/K/}" # TODO: check that "K" should be removed. can we have M?
				logdetail "Rounding: ${R_ROUNDING}"
			fi
			if test -n "${R_LAYOUT}"
			then
				[ -z "`echo 'left-asymmetric right-asymmetric left-symmetric right-symmetric' | grep \"${R_LAYOUT/ /}\"`" ] && shellout "Invalid layout [${R_LAYOUT}] for raid [${R_NAME}]."
				CMD="${CMD} --layout ${R_LAYOUT}" # The parity algorithm to use with RAID5
				logdetail "Layout: ${R_LAYOUT}"
			fi
			[ -n "${R_CHUNK_SIZE}" ] && CMD="${CMD} --chunk ${R_CHUNK_SIZE/K/}" && logdetail "Chunk size: ${R_CHUNK_SIZE}"

			# Now adding devices for the raid volume. Either partitions and disk devices can go here.
			[ -n "${P_DEVICES}" ] && CMD="${CMD} ${P_DEVICES}" # Add partition devices if any are part of this raid volume.
			[ -n "${R_DEVICES}" ] && CMD="${CMD} ${R_DEVICES}" # Add disk devices if any are defines for this raid volume.

			logaction "${CMD}"
			eval "yes | LC_ALL=C ${CMD}"
		done

}

################################################################################
# _do_lvm()
#		Initialize LVM if any are defined in the AUTOINSTALL_CONF
#		
################################################################################
_do_lvms() {
	IFS=";"
	# Note: in dracut, locking_type is set to 4 (readonly) for lvm (/etc/lnm/lvm.conf) to prevent any lvm modification during early boot.
	# We need to get raound this default config.
	# See https://bugzilla.redhat.com/show_bug.cgi?id=865015 (not a bug)
	LVM_LOCK_1="--config 'global {locking_type=1}'"

	loginfo "Creating volume groups"

	xmlstarlet sel -t -m "config/lvm/lvm_group" -v "concat(@name,';',@max_log_vols,';',@max_phys_vols,';',@phys_extent_size)" -n ${AUTOINSTALL_CONF} |\
		while read VG_NAME VG_MAX_LOG_VOLS VG_MAX_PHYS_VOLS VG_PHYS_EXTENT_SIZE
		do
			VG_PARTS=`xmlstarlet sel -t -m "config/disk/part[@lvm_group=\"${VG_NAME}\"]" -s A:T:U num -v "concat(ancestor::disk/@dev,@num,' ')" ${AUTOINSTALL_CONF}`
			VG_RAIDS=`xmlstarlet sel -t -m "config/raid/raid_disk[@lvm_group=\"${VG_NAME}\"]" -s A:T:U name -v "concat(@name,' ')" ${AUTOINSTALL_CONF}`
			# Doing some checks on volume group devices.
			[ -n "${VG_PARTS/ /}" ] && [ -n "${VG_RAIDS/ /}" ] && logwarn "volume group ${VG_NAME} has partitions mixed with raid volumes"
			[ -z "${VG_PARTS/ /}${VG_RAIDS}/ /" ] && logwarn "Volume group [${VG_NAME}] has no devices associated!"

			loginfo "Creating physical volume group ${VG_NAME} for device(s) ${VG_PARTS}${VG_RAIDS}."

			# Getting specific params for volume group ${VG_NAME}
			xmlstarlet sel -t -m "config/lvm/lvm_group[name=\"${VG_NAME}\"]" -v "concat(@max_log_vols,';',@max_phys_vols,';',@phys_extent_size)" -n ${AUTOINSTALL_CONF} | read L_MAX_LOG_VOLS L_MAX_PHYS_VOLS L_PHYS_EXTENT_SIZE

			CMD="pvcreate ${LVM_LOCK_1} -M${LVM_VERSION} -ff -y ${VG_PARTS}${VG_RAIDS}"
			logaction $CMD
			eval "$CMD" || shellout "Failed to prepare devices for being part of a LVM"

			# Now we cleanup any previous volume groups.
			loginfo "Cleaning up any previous volume groups named [${VG_NAME}]"
			lvremove -f /dev/${VG_NAME} >/dev/null 2>&1 && vgremove ${VG_NAME} >/dev/null 2>&1

			# Now we create the volume group.
			CMD="vgcreate ${LVM_LOCK_1} -M${LVM_VERSION}"
			[ -n "${VG_MAX_LOG_VOLS/ /}" ] && CMD="${CMD} -l ${VG_MAX_LOG_VOLS/ /}"
			[ -n "${VG_MAX_PHYS_VOLS/ /}" ] && CMD="${CMD} -p ${VG_MAX_PHYS_VOLS/ /}"
			[ -n "${VG_PHYS_EXTENT_SIZE/ /}" ] && CMD="${CMD} -s ${VG_PHYS_EXTENT_SIZE/ /}"
			CMD="${CMD} ${VG_NAME} ${VG_PARTS}${VG_RAIDS}"
			logaction "${CMD}"
			eval "${CMD}" || shellout "Failed to create volume group [${VG_NAME}]"

			# TODO: Add missing @lv_options doc in man autoinstallscript.conf
			xmlstarlet sel -t -m "config/lvm/lvm_group[@name=\"${VG_NAME}\"]/lv" -v "concat(@name,';',@size,';',@lv_options)" -n ${AUTOINSTALL_CONF} |\
				while read LV_NAME LV_SIZE LV_OPTIONS
				do
					# TODO: Add @lv_options to man autoinstallscript.conf
					loginfo "Creating logical volume ${LV_NAME} for volume groupe ${VG_NAME}."
					CMD="lvcreate ${LVM_LOCK_1} ${LV_OPTIONS}"
					if test "${LV_SIZE/ /}" = "*"
					then
						CMD="${CMD} -l100%FREE"
					else
						CMD="${CMD} -L${LV_SIZE/ /}"
					fi
					CMD="${CMD} -n ${LV_NAME} ${VG_NAME}"
					logaction "${CMD}"
					eval "LC_ALL=C ${CMD}" || shellout "Failed to create logical volume ${LV_NAME}"

					loginfo "Enabling logical volume ${LV_NAME}"
					CMD="lvscan > /dev/null; lvchange -a y /dev/${VG_NAME}/${LV_NAME}"
					logaction "${CMD}"
					eval "${CMD}" || shellout "lvchange -a y /dev/${VG_NAME}/${LV_NAME} failed!"
				done
		done
}

################################################################################
#
# _do_filesystems()
#		- Format volumes
#		- Create fstab
################################################################################
#
_do_filesystems() {
	loginfo "Creating filesystems mountpoints and fstab."

	# Prepare fstab skeleton.
	cat > /tmp/fstab.temp <<EOF
#
# /etc/fstab
# Created by System Imager on $(date)
#
# Source: ${AUTOINSTALL_CONF}
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
EOF

	# Processing filesystem informations sorted by line number
	IFS='<' # (need to use an XML forbidden char that is not & (used for escaped chars) (we could have used '>')
	# Comment field can have any chars except &,<,>. forced output as TEXT (-T) so we dont end up with "&lt" instead of "<".
	xmlstarlet sel -T -t -m "config/fsinfo" -s A:N:- "@line" -v "concat(@line,'<',@comment,'<',@real_dev,'<',@mount_dev,'<',@mp,'<',@fs,'<',@mkfs_opts,'<',@options,'<',@dump,'<',@pass,'<',@format)" -n ${AUTOINSTALL_CONF} |\
		while read FS_LINE FS_COMMENT FS_REAL_DEV FS_MOUNT_DEV FS_MP FS_FS FS_MKFS_OPTS FS_OPTIONS FS_DUMP FS_PASS FS_FORMAT
		do
			# 1/ Get the label if any.
			[ "${FS_MOUNT_DEV%=*}"="LABEL" ] && FS_LABEL="${FS_MOUNT_DEV##*=}"

			# Get the UUID, will be usefull for fastab later.
			[ "${FS_MOUNT_DEV%=*}"="UUID" ] && FS_UUID="${FS_MOUNT_DEV##*=}"

			# 2/ Format filesystem
			MKFS_CMD="mkfs -t ${FS_FS/ /} ${FS_MKFS_OPTS/ /}" # Generic mkfs version
			case "${FS_FS}" in
				ext2|ext3|ext4)
					SET_UUID_CMD="tune2fs -U ${FS_UUID}"
					[ -n "${FS_LABEL/ /}" ] && MKFS_CMD="${MKFS_CMD} -L ${FS_LABEL/ /}"
					MKFS_CMD="${MKFS_CMD} -q"
					;;
				xfs)
					SET_UUID_CMD="xfs_admin -U ${FS_UUID}"
					[ -n "${FS_LABEL/ /}" ] && MKFS_CMD="${MKFS_CMD} -L ${FS_LABEL/ /}"
					MKFS_CMD="${MKFS_CMD} -q -f"
					;;
				jfs)
					SET_UUID_CMD="jfs_tune -U ${FS_UUID}"
					[ -n "${FS_LABEL/ /}" ] && MKFS_CMD="${MKFS_CMD} -L ${FS_LABEL/ /}"
					MKFS_CMD="yes|${MKFS_CMD} -q"
					;;
				reiserfs)
					SET_UUID_CMD="reiserfstune -u ${FS_UUID}"
					[ -n "${FS_LABEL/ /}" ] && MKFS_CMD="${MKFS_CMD} -l ${FS_LABEL/ /}"
					MKFS_CMD="${MKFS_CMD} -q -ff"
					;;
				btrfs)
					SET_UUID_CMD="btrfstune -U ${FS_UUID}"
					[ -n "${FS_LABEL/ /}" ] && MKFS_CMD="${MKFS_CMD} -L ${FS_LABEL/ /}"
					MKFS_CMD="${MKFS_CMD} -q -f"
					;;
				ntfs)
					SET_UUID_CMD=""
					[ -n "${FS_LABEL/ /}" ] && MKFS_CMD="${MKFS_CMD} -L ${FS_LABEL/ /}"
					MKFS_CMD="${MKFS_CMD} -q"
					;;
				vfat|msdos|fat)
					SET_UUID_CMD=""
					[ -n "${FS_LABEL/ /}" ] && MKFS_CMD="${MKFS_CMD} -n ${FS_LABEL/ /}"
					;;
				swap)
					MKFS_CMD="mkswap -v1 ${FS_MKFS_OPTS/ /}"
					[ -n "${FS_UUID/ /}" ] && MKFS_CMD="${MKFS_CMD} -U ${FS_UUID/ /}"
					;;
				*)
					[ -z "${FS_FS/ /}" -a -z "${FS_COMMENT}" ] && shellout "Missing filesystem type line ${FS_LINE}".
					FS_FORMAT="no" # Don't try to format this (virtual filesystems, nfs, ...)
					;;
			esac

			if test "${FS_FORMAT/ /}" != "no"
			then
				loginfo "Initializing ${FS_REAL_DEV} (filesystem: ${FS_FS})"
				logaction "${MKFS_CMD} ${FS_REAL_DEV}"
				eval "${MKFS_CMD} ${FS_REAL_DEV}" || shellout "Failed to initialise filesystem (${FS_FS}) for ${FS_REAL_DEV}"
				if test -n "${FS_UUID/ /}" -a -n "${SET_UUID_CMD/ /}"
				then
					loginfo "Setting UUID=${FS_UUID/ /} for ${FS_REAL_DEV}"
					logaction "${SET_UUID_CMD}"
					eval "${SET_UUID_CMD}" || shellout "Failed to set UUID=${FS_UUID/ /} for ${FS_REAL_DEV}"
				fi
			else
				loginfo "${FS_MP} will not be formated (format=no or non physiscal filesystem)"
			fi
			# 3/ Add it to fstab
			# If no mount dev specified, use the real dev.
			[ -z "${FS_MOUNT_DEV/ /}" ] && FS_MOUNT_DEV="${FS_REAL_DEV/ /}"
			# Check that we have a mount dev to work with. If empty while other parameters are specified. whine!
			[ -z "${FS_MOUNT_DEV/ /}" -a -n "${FS_MP/ /}${FS_FS/ /}${FS_OPTIONS/ /}${FS_DUMP/ /}${FS_PASS/ /}" ] && shellout "Error: line ${FS_LINE}. No device to mount while some parameters are defined."
			# Check that we have a mount point if we have a real dev.
			if test -n "${FS_MOUNT_DEV/ /}" # We have something to mount (not a comment line)
			then
				# Check that we have at least a mount point and a filesystem.
				[ -z "${FS_MP/ /}" ] && shellout "No mount point for ${FS_MOUNT_DEV/ /} line ${FS_LINE}"
				[ -z "${FS_FS/ /}" ] && shellout "No filesystem type for ${FS_MOUNT_DEV/ /} line ${FS_LINE}"
				# now, sets defaults for missing fields.
				[ -z "${FS_OPTIONS/ /}" ] && FS_OPTIONS="defaults" # no mount options => defaulting to "defaults".
				[ -z "${FS_DUMP/ /}" ] && FS_DUMP="0"
				[ -z "${FS_PASS/ /}" ] && FS_PASS="0"
				FSTAB_LINE="${FS_MOUNT_DEV/ /}\t${FS_MP/ /}\t${FS_FS/ /}    ${FS_OPTIONS/ /}  ${FS_DUMP/ /} ${FS_PASS/ /} ${FS_COMMENT}"
			else # Must be a comment line at this point.
				FSTAB_LINE="${FS_COMMENT}"
			fi
			echo -e "${FSTAB_LINE}" >> /tmp/fstab.temp
		done
}

################################################################################
# _do_fstab()
#		- Process fstab to create moutpoints for all defined filesystems
#		  If it is a virtual filesystem, a warning is issued.
#		  Now virtual filesystems are not listed in fstab anymore.
#		- Mount physical filesystems so they can receive the image
################################################################################
_do_fstab() {
	# Process fstab to create moutpoints
	# Now process fstab to create mount points and effectively mout filesystems.
	# We sort it by mount point (we need to create /var before
	# /var/tmp even if user wants /var/tmp before /var in /etc/fstab for example)
	loginfo "Processing fstab: Creating mount points and mounting physical filesystems."
	unset IFS
	cat /tmp/fstab.temp |sed -e 's/#.*//' -e '/^$/d' | sort -k2,2 |\
		while read M_DEV M_MP M_FS M_OPTS
		do
			# If mountpoint is a PATH, AND filesystem is not virtual, create the path and mount filesystem to sysroot.
			if test "${M_MP:0:1}" = "/" -a -n "`echo "ext2|ext3|ext4|xfs|jfs|reiserfs|btrfs|ntfs|msdos|vfat|fat" |grep \"${M_FS/ /}\"`"
			then
				loginfo "Creating mountpoint ${M_MP/ /}"
				logaction "mkdir -p /sysroot${M_MP/ /}"
				mkdir -p /sysroot${M_MP/ /} || shellout "Failed to create ${M_MP/ /}"
				loginfo "Mounting ${M_DEV} to /sysroot${M_MP}"
				mount -t ${M_FS/ /} ${M_DEV/ /} /sysroot${M_MP/ /} || shellout "Failed to mount ${M_DEV/ /} to /sysroot${M_MP/ /}"
			elif [ "${M_MP:0:4}" != "swap" ] # filesystem is not a disk filesystem.
			then
				logwarn "Virtual filesystems are now handled by systemd."
				logwarn "${M_FS/ /} filesystem shouldn't be put in fstab!"
				logwarn "Creating mount point, but it may be hidden by systemd mount!"
				logwarn "For example /dev/pts may be hidden by /dev virtual filesystem."
				logaction "mkdir -p /sysroot${M_MP/ /}"
				mkdir -p /sysroot${M_MP/ /} || shellout "Failed to create ${M_MP/ /}"
			fi
		done
}
