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


# Load API and variables.txt (HOSTNAME, IMAGENAME, ..., including detected disks array: $DISKS)
type logmessage >/dev/null 2>&1 || . /lib/systemimager-lib.sh

# Assumptions
# primary partitions are created at 1st in order 1, 2, 3, 4 ...
# TODO: partition are aligned to 1MiB so it fits all disks aligments.
# TODO: Enhancement: use http://people.redhat.com/msnitzer/docs/io-limits.txt if possible for optimal aligment; fallback to 1MiB aligment only if not supported.
#

################################################################################
#
# get_disks_from_autoinstall_conf()
#		Returns all raw disk devices to be configured.
#		This is usefull to check that at least we detected thoses disks
#		We can have more available disks. the extraneous disks will be
#		left untouched, but if miss some, we'll fail.
################################################################################
get_disks_from_autoinstall_conf() {
    xmlstarlet sel -t -m 'config/disk' -m "@dev" -v . -n ${DISKS_LAYOUT_FILE}
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
	if test -z "${DISKS_LAYOUT}"
	then
		DISKS_LAYOUT_FILE=`choose_filename /scripts/disks-layouts "" ".xml"`
	else
		DISKS_LAYOUT_FILE=/scripts/disks-layouts/${DISKS_LAYOUT}
		test ! -f "${DISKS_LAYOUT_FILE}" && DISKS_LAYOUT_FILE=/scripts/disks-layouts/${DISKS_LAYOUT}.xml
	fi
	if test ! -f "${DISKS_LAYOUT_FILE}"
	then
		logerror "Could not get a valid disk layout file"
		test -n "${DISKS_LAYOUT_FILE}" && logerror "Tryed ${DISKS_LAYOUT_FILE}"
		logerror "Neiter DISKS_LAYOUT, HOSTNAME, IMAGENAME is set or"
		logerror "No group, group_override, base_hostname matches a layout file"
		logerror "Can't find a disk layout config file. Can't initilize disks."
		logerror "Please read autoinstallscript.conf manual and create a disk layout file"
		logerror "Store it on image sarver in /var/lib/systemimager/scripts/disks-layouts/"
		logerror "Use the one of possible names: {\$DISKS_LAYOUT,\$HOSTNAME,\$GROUPNAME,\$BASE_HOSTNAME,\$IMAGENAME,default}{,.xml}"
		shellout "Can't initilize disks. No layout found."
	fi
	loginfo "Using Disk layout file: ${DISKS_LAYOUT_FILE}"

	# Initialisae / check LVM version to use. (defaults to v2).
	LVM_VERSION=`xmlstarlet sel -t -m "config/lvm" -if "@version" -v "@version" --else -o "2" -b ${DISKS_LAYOUT_FILE}`

	_stop_software_raid_devices
	_do_partitions
	_do_raids
	_do_lvms
	_do_filesystems
	_do_fstab
}

################################################################################
# sis_install_configs()
#		Must be run after image deployment and overrides install
#		Installs in /sysroot
#		- /etc/fstab
#		- /etc/mdadm/mdadm.conf if needed
#		- /etc/lvm/lvm.conf if needed
#		- re-run chrooted dracut so initramfs is aware for raid and lvm
################################################################################
#
sis_install_configs() {
	# 1/ Install fstab
	loginfo "Installing /etc/fstab"
	cp /tmp/fstab.temp /sysroot/etc/fstab || shellout "Failed to copy /tmp/fstab.temp as /sysroot/etc/fstab"

	# 2/ Install mdadm.conf if needed
	if [ -f /tmp/mdadm.conf.temp ]
	then
		# Check that imaged system has mdadm command so it can reboot
		[ ! -e /sysroot/sbin/mdadm -a ! -e /sysroot/usr/sbin/mdadm ] && logwarn "mdadm seems missing in imaged system. System may fail to boot"

		# Install the config file
		loginfo "Installing /etc/mdadm/mdadm.conf"
		mkdir -p /sysroot/etc/mdadm || shellout "Failed to create /sysroot/etc/mdadm/"
		[ -f /sysroot/etc/mdadm/mdadm.conf ] && ( mv -f /sysroot/etc/mdadm/mdadm.conf /sysroot/etc/mdadm/mdadm.conf.bak || shellout "Failed to backup default mdadm.conf" )
		[ -f /sysroot/etc/mdadm.conf ] && ( mv -f /sysroot/etc/mdadm.conf /sysroot/etc/mdadm/mdadm.conf.old.bak || shellout "Failed to backup obsolete mdadm.conf" )
		cp /tmp/mdadm.conf.temp /sysroot/etc/mdadm/mdadm.conf || shellout "Failed to copy /tmp/mdadm.conf.temp as /sysroot/etc/mdadm/mdadm.conf"
	fi

	# 3/ Install lvm.conf if needed
	if test -n "${WANT_LVM}"
	then
		# Check that imaged system has lvm command so it can reboot
		[ ! -e /sysroot/sbin/lvm -a ! -e /sysroot/usr/sbin/lvm ] && logwarn "lvm seems missing in imaged system. System may fail to boot"

		if test ! -f /sysroot/etc/lvm/lvm.conf
		then
			loginfo "Installing /etc/lvm/lvm.conf"
			mkdir -p /sysroot/etc/lvm || shellout "Failed to create /sysroot/etc/lvm/"
			lvm config --type default --withcomments > /sysroot/etc/lvm/lvm.conf

		else
			loginfo "Using /etc/lvm/lvm.conf from image"
			if test -f /sysroot/etc/lvm.conf
			then
				# /etc/lvm.conf is oboslete. should be /etc/lvm/lvm.conf
				loginfo "Backing up obsolete /etc/lvm.conf file as /etc/lvm/lvm.conf.old.bak"
				mv -f /sysroot/etc/lvm.conf /sysroot/etc/lvm/lvm.conf.old.bak || shellout "Failed to backup obsolete lvm.conf"
			fi
		fi

		# Also create /etc/lvm/{archive,backup}
		loginfo "Creating lvm archive and backup dirs with lvm config"
		chroot /sysroot vgscan
	fi

	# 4/ Regenerate initramfs for all deployed kernels
	for KERNEL in `ls /sysroot/boot|grep vmlinuz`
	do
		loginfo "Generating initramfs for kernel: ${KERNEL}"
		logaction "dracut --force --kver "${KERNEL#*-}" --hostonly"
		chroot /sysroot dracut --force --kver "${KERNEL#*-}" --hostonly
	done
}

################################################################################
#
# _stop_software_raid()
#		stops all software raid volumes so we can initialise disks
#		some raid can be running (enabled to read local.cfg for instance)
################################################################################
_stop_software_raid_devices() {
    if [ -f /proc/mdstat ]; then
        RAID_DEVICES=` cat /proc/mdstat | grep ^md | sed 's/ .*$//g' `

        # Turn dem pesky raid devices off!
        for RAID_DEVICE in ${RAID_DEVICES}
        do
            DEV="/dev/${RAID_DEVICE}"
	    loginfo "stopping ${DEV} raid device"
            logdebug "mdadm --manage ${DEV} --stop"
            mdadm --manage ${DEV} --stop
        done
    fi
}

################################################################################
#
# _save_configs_to_image
#		Save configs specific to disk in imaged system
#		- /etc/fstab
#		- /etc/mdadm/mdadm.conf
#		- /etc/lvm/lvm.conf
#
################################################################################
_save_configs_to_image() {
	loginfo "Installing fstab on imaged system"
	cp /tmp/fstab.image /sysroot/etc/fstab || shellout "Failed to install /etc/fstab in imaged system."
	# Make sure /etc/mdadm exists on imaged system.
	if test -f /tmp/mdadm.conf
	then
		mkdir -p /sysroot/etc/mdadm || shellout "Failed to create /sysroot/etc/mdadm"
		loginfo "Installing software raid config file mdadm.conf"
		cp /tmp/mdadm.conf /sysroot/etc/mdadm/mdadm.conf || shellout "Failed to install /etc/mdadm/mdadm.conf in imaged system."
	fi
	# Make sure /etc/lvm exists on imaged system.
	if test -f /tmp/lvm.conf
	then
		mkdir -p /sysroot/etc/lvm || shellout "Failed to create /sysroot/etc/lvm"
		loginfo "Installing logical volume manager config file lvm.conf"
		cp /tmp/lvm.conf /sysroot/etc/lvm/lvm.conf || shellout "Failed to install /etc/lvm/lvm.conf in imaged system."
	fi
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
	sis_update_step part
	IFS=';'
	xmlstarlet sel -t -m 'config/disk' -v "concat(@dev,';',@label_type,';',@unit_of_measurement)" -n ${DISKS_LAYOUT_FILE}|\
		while read DISK_DEV LABEL_TYPE T_UNIT;
	       	do
			loginfo "Setting up partitions for disk $DISK_DEV"

			# Create the partition table
			logaction "parted -s -- $DISK_DEV mklabel ${LABEL_TYPE}"
			LC_ALL=C parted -s -- ${DISK_DEV} mklabel "${LABEL_TYPE}" || shellout "Failed to create new partition table for disk $DISK_DEV partition type=$PART_TYPE!"

			# Create the partitions
			T_UNIT=`echo $T_UNIT|sed "s/percent.*/%/g"` # Convert all variations of percent{,age{,s}} to "%"
			xmlstarlet sel -t -m "config/disk[@dev=\"${DISK_DEV}\"]/part" -v "concat(@num,';',@size,';',@p_type,';',@id,';',@p_name,';',@flags,';',@lvm_group,';',@raid_dev)" -n ${DISKS_LAYOUT_FILE}|\
				while read P_NUM P_SIZE P_TYPE P_ID P_NAME P_FLAGS P_LVM_GROUP P_RAID_DEV
				do
					if test "$P_SIZE" = "*"
					then
						P_SIZE="0" # 0 means 100% for parted
					else
						P_UNIT="$T_UNIT"
					fi
					# Get partition filesystem if it exists (no raid, no lvm) so we can put it in partition filesystem info
					P_FS=`xmlstarlet sel -t -m "config/fsinfo[@real_dev=\"${DISK_DEV}${P_NUM}\"]" -v "@fs" -n ${DISKS_LAYOUT_FILE}`

					# 1/ Create the partition
					CMD="parted -s -- ${DISK_DEV} unit ${P_UNIT} mkpart ${P_TYPE} ${P_FS} `_find_free_space ${DISK_DEV} ${P_UNIT} ${P_TYPE} ${P_SIZE}`"
					logaction "$CMD"
					eval "$CMD" || shellout "Failed to create partition ${DISK_DEV}${P_NUM}"

					# 2/ Set partition number ($partition) using sfdisk
					# Do nothing; assuming xml file use partition in order just like parted.

					# 3/ Set the partition flags
					for flag in `echo $P_FLAGS|tr ',' ' '`
					do
						CMD="parted -s -- ${DISK_DEV} set ${P_NUM} ${flag} on"
						logaction "$CMD"
						eval "$CMD" || shellout "Failed to set flag ${flag}=on for partition ${DISK_DEV}${P_NUM}"
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
	IFS=" "
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
	[ -n "`echo ${BEGIN_END[0]}|grep '^0'`" ] && BEGIN_END[0]="1MiB" # Make sure we start at aligned position and that there is room for grub.
	echo ${BEGIN_END[@]}
}

################################################################################
# _do_raids()
#		Create software raid devices if any are defined.
#
################################################################################
_do_raids() {
	loginfo "Creating software raid devices if needed."
	IFS=';'
	xmlstarlet sel -t -m 'config/raid/raid_disk' -v "concat(@name,';',@raid_level,';',@raid_devices,';',@spare_devices,';',@rounding,';',@layout,';',@chunk_size,';',@lvm_group,';',@devices)" -n ${DISKS_LAYOUT_FILE} |\
		while read R_NAME R_LEVEL R_DEVS_CNT R_SPARES_CNT R_ROUNDING R_LAYOUT R_CHUNK_SIZE R_LVM_GROUP R_DEVICES
		do
			# If Raid volume uses partitions, get them
			P_DEVICES=`xmlstarlet sel -t -m "config/disk/part[@raid_dev=\"$R_NAME\"]"  -v "concat(ancestor::disk/@dev,@num,' ')" ${DISKS_LAYOUT_FILE}`
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
			eval "yes | ${CMD}" || shellout "Failed to create raid${R_LEVEL} with ${R_DEVICES}"

			# Create the grub2 config the force raid assembling in initramfs.
			# GRUB_CMDLINE_LINUX_DEFAULT is use in normal operation but not in failsafe
			# GRUB_CMDLINE_LINUX is use in al circumstances. We do not want to try to assemble raid in failsafe.
			cat > /tmp/grub_default.cfg <<EOF
GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} rd.auto"
EOF
		done
	# Now check if we need to create a mdadm.conf
	if [ -n "${CMD}" ] # We created at least one raid volume.
	then
		loginfo "Generating mdadm.conf"
		cat > /tmp/mdadm.conf.temp <<EOF
# mdadm.conf
#
# Please refer to mdadm.conf(5) for information about this file.
#

DEVICE partitions

# auto-create devices with Debian standard permissions
CREATE owner=root group=disk mode=0660 auto=yes

# automatically tag new arrays as belonging to the local system
HOMEHOST <system>

# instruct the monitoring daemon where to send mail alerts
MAILADDR root

# definitions of existing MD arrays
EOF
		mdadm --detail --scan >> /tmp/mdadm.conf.temp
	fi

}

################################################################################
# _do_lvm()
#		Initialize LVM if any are defined in the DISKS_LAYOUT_FILE
#		
################################################################################
_do_lvms() {
	IFS=";"
	# Note: in dracut, locking_type is set to 4 (readonly) for lvm (/etc/lvm/lvm.conf) to prevent any lvm modification during early boot.
	# We need to get raound this default config.
	# See https://bugzilla.redhat.com/show_bug.cgi?id=865015 (not a bug)
	# LVM_DEFAULT_CONFIG="--config 'global {locking_type=1}'" # At least we need this config.
	# We chose to replace the inapropriate lvm.conf with a generic one that fits our needs.
	lvmconfig --type default --withcomments > /etc/lvm/lvm.conf || shellout "Failed to overwrite initramfs:/etc/lvm/lvm.conf with default lvm.conf that permits lvm creation/modification/removal."

	loginfo "Creating volume groups"

	xmlstarlet sel -t -m "config/lvm/lvm_group" -v "concat(@name,';',@max_log_vols,';',@max_phys_vols,';',@phys_extent_size)" -n ${DISKS_LAYOUT_FILE} |\
		while read VG_NAME VG_MAX_LOG_VOLS VG_MAX_PHYS_VOLS VG_PHYS_EXTENT_SIZE
		do
			VG_PARTS=`xmlstarlet sel -t -m "config/disk/part[@lvm_group=\"${VG_NAME}\"]" -s A:T:U num -v "concat(ancestor::disk/@dev,@num,' ')" ${DISKS_LAYOUT_FILE}`
			VG_RAIDS=`xmlstarlet sel -t -m "config/raid/raid_disk[@lvm_group=\"${VG_NAME}\"]" -s A:T:U name -v "concat(@name,' ')" ${DISKS_LAYOUT_FILE}`
			# Doing some checks on volume group devices.
			[ -n "${VG_PARTS/ /}" ] && [ -n "${VG_RAIDS/ /}" ] && logwarn "volume group ${VG_NAME} has partitions mixed with raid volumes"
			[ -z "${VG_PARTS/ /}${VG_RAIDS}/ /" ] && logwarn "Volume group [${VG_NAME}] has no devices associated!"

			loginfo "Creating physical volume group ${VG_NAME} for device(s) ${VG_PARTS}${VG_RAIDS}."

			# Getting specific params for volume group ${VG_NAME}
			xmlstarlet sel -t -m "config/lvm/lvm_group[name=\"${VG_NAME}\"]" -v "concat(@max_log_vols,';',@max_phys_vols,';',@phys_extent_size)" -n ${DISKS_LAYOUT_FILE} | read L_MAX_LOG_VOLS L_MAX_PHYS_VOLS L_PHYS_EXTENT_SIZE

			CMD="pvcreate ${LVM_DEFAULT_CONFIG} -M${LVM_VERSION} -ff -y ${VG_PARTS}${VG_RAIDS}"
			logaction $CMD
			eval "$CMD" || shellout "Failed to prepare devices for being part of a LVM"

			# Now we cleanup any previous volume groups.
			loginfo "Cleaning up any previous volume groups named [${VG_NAME}]"
			lvremove ${LVM_DEFAULT_CONFIG} -f /dev/${VG_NAME} >/dev/null 2>&1 && vgremove ${VG_NAME} >/dev/null 2>&1

			# Now we create the volume group.
			CMD="vgcreate ${LVM_DEFAULT_CONFIG} -M${LVM_VERSION}"
			[ -n "${VG_MAX_LOG_VOLS/ /}" ] && CMD="${CMD} -l ${VG_MAX_LOG_VOLS/ /}"
			[ -n "${VG_MAX_PHYS_VOLS/ /}" ] && CMD="${CMD} -p ${VG_MAX_PHYS_VOLS/ /}"
			[ -n "${VG_PHYS_EXTENT_SIZE/ /}" ] && CMD="${CMD} -s ${VG_PHYS_EXTENT_SIZE/ /}"
			CMD="${CMD} ${VG_NAME} ${VG_PARTS}${VG_RAIDS}"
			logaction "${CMD}"
			eval "${CMD}" || shellout "Failed to create volume group [${VG_NAME}]"

			xmlstarlet sel -t -m "config/lvm/lvm_group[@name=\"${VG_NAME}\"]/lv" -v "concat(@name,';',@size,';',@lv_options)" -n ${DISKS_LAYOUT_FILE} |\
				while read LV_NAME LV_SIZE LV_OPTIONS
				do
					loginfo "Creating logical volume ${LV_NAME} for volume groupe ${VG_NAME}."
					CMD="lvcreate -y ${LVM_DEFAULT_CONFIG} ${LV_OPTIONS}"
					if test "${LV_SIZE/ /}" = "*"
					then
						CMD="${CMD} -l100%FREE"
					else
						CMD="${CMD} -L${LV_SIZE/ /}"
					fi
					CMD="${CMD} -n ${LV_NAME} ${VG_NAME}"
					logaction "${CMD}"
					eval "${CMD}" || shellout "Failed to create logical volume ${LV_NAME}"

					loginfo "Enabling logical volume ${LV_NAME}"
					CMD="lvscan > /dev/null; lvchange -a y /dev/${VG_NAME}/${LV_NAME}"
					logaction "${CMD}"
					eval "${CMD}" || shellout "lvchange -a y /dev/${VG_NAME}/${LV_NAME} failed!"
				done
		done
		if test -n "$CMD"
		then
			WANT_LVM="y"
		fi
}

################################################################################
#
# _do_filesystems()
#		- Format volumes
#		- Create fstab
################################################################################
#
_do_filesystems() {
	sis_update_step frmt
	loginfo "Creating filesystems mountpoints and fstab."

	# Prepare fstab skeleton.
	cat > /tmp/fstab.temp <<EOF
#
# /etc/fstab
# Created by System Imager on $(date)
#
# Source: ${DISKS_LAYOUT_FILE}
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
EOF

	# Processing filesystem informations sorted by line number
	IFS='<' # (need to use an XML forbidden char that is not & (used for escaped chars) (we could have used '>')
	# Comment field can have any chars except &,<,>. forced output as TEXT (-T) so we dont end up with "&lt" instead of "<".
	xmlstarlet sel -T -t -m "config/fsinfo" -s A:N:- "@line" -v "concat(@line,'<',@comment,'<',@real_dev,'<',@mount_dev,'<',@mp,'<',@fs,'<',@mkfs_opts,'<',@options,'<',@dump,'<',@pass,'<',@format)" -n ${DISKS_LAYOUT_FILE} |\
		while read FS_LINE FS_COMMENT FS_REAL_DEV FS_MOUNT_DEV FS_MP FS_FS FS_MKFS_OPTS FS_OPTIONS FS_DUMP FS_PASS FS_FORMAT
		do
			# 1/ Get the label if any.
			[ "${FS_MOUNT_DEV%=*}"="LABEL" ] && FS_LABEL="${FS_MOUNT_DEV##*=}"

			# Get the UUID, will be usefull for fstab later.
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
#		- Save mounted filesystems to initramfs:/etc/fstab
################################################################################
_do_fstab() {
	# Process fstab to create moutpoints
	# Now process fstab to create mount points and effectively mout filesystems.
	# We sort it by mount point (we need to create /var before /var/tmp
	# even if user wants /var/tmp before /var in /etc/fstab for example)
	# We also populate initramfs:/etc/fstab with mounted filesystems in sorted
        # order	so it's easier later to umount them.
	loginfo "Processing fstab: Creating mount points and mounting physical filesystems."
	unset IFS
	cat /tmp/fstab.temp |sed -e 's/#.*//' -e '/^$/d' | sort -k2,2 |\
		while read M_DEV M_MP M_FS M_OPTS M_DUMP M_PASS
		do
			# If mountpoint is a PATH, AND filesystem is not virtual, create the path and mount filesystem to sysroot.
			if test "${M_MP:0:1}" = "/" -a -n "`echo "ext2|ext3|ext4|xfs|jfs|reiserfs|btrfs|ntfs|msdos|vfat|fat" |grep \"${M_FS}\"`"
			then
				loginfo "Creating mountpoint ${M_MP}"
				logaction "mkdir -p /sysroot${M_MP}"
				mkdir -p /sysroot${M_MP} || shellout "Failed to create ${M_MP}"
				loginfo "Mounting ${M_DEV} to /sysroot${M_MP}"
				[ -n "${M_OPTS}" ] && MOUNT_OPT="-o ${M_OPTS}"
				CMD="mount -t ${M_FS} ${MOUNT_OPT} ${M_DEV} /sysroot${M_MP}"
				logdebug "$CMD"
				eval "$CMD" || shellout "Failed to mount ${M_DEV} to /sysroot${M_MP}"
				# Add filesystem to initramfs:/etc/fstab (needed when we'll need to unmount them)
				# Set 0 for dump and 0 for pass (not needed in initramfs).
				echo -e "${M_DEV}\t/sysroot${M_MP}\t${M_FS}\t${M_OPTS}\t0 0" >> /etc/fstab
			elif [ "${M_MP:0:4}" != "swap" ] # filesystem is not a disk filesystem.
			then
				logwarn "Virtual filesystems are now handled by systemd."
				logwarn "${M_FS} filesystem shouldn't be put in fstab!"
				logwarn "Creating mount point, but it may be hidden by systemd mount!"
				logwarn "For example /dev/pts may be hidden by /dev virtual filesystem."
				logaction "mkdir -p /sysroot${M_MP}"
				mkdir -p /sysroot${M_MP} || shellout "Failed to create ${M_MP}"
			fi
		done
}
