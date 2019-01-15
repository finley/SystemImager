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

PARTED_DELAY=0.5 # On older kernels, system needs time to update partitions.

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
		logerror "Store it on image server in /var/lib/systemimager/scripts/disks-layouts/"
		logerror "Use the one of possible names: {\$DISKS_LAYOUT,\$HOSTNAME,\$GROUPNAME,\$BASE_HOSTNAME,\$IMAGENAME,default}{,.xml}"
		shellout "Can't initilize disks. No layout found."
	fi
	loginfo "Using Disk layout file: ${DISKS_LAYOUT_FILE}"
	write_variables # Save DISKS_LAYOUT_FILE variable for future use.

	# Initialisae / check LVM version to use. (defaults to v2).
	LVM_VERSION=`xmlstarlet sel -t -m "config/lvm" -if "@version" -v "@version" --else -o "2" -b ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d'`

	loginfo "Stopping software raid and LVM that may still be active."
	stop_software_raid_and_lvm
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
#		1 - /etc/fstab
#		2 - /etc/mdadm/mdadm.conf if needed
#		3 - /etc/lvm/lvm.conf if needed
#		4 - Makes sure /etc/mtab -> /proc/self/mounts
#		5 - re-run chrooted dracut so initramfs is aware for raid and lvm
################################################################################
#
sis_install_configs() {
	# 1/ Install fstab
	loginfo "Installing /etc/fstab"
	cp /tmp/fstab.image /sysroot/etc/fstab || shellout "Failed to copy /tmp/fstab.image as /sysroot/etc/fstab"

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

	# 4/ Make sure /etc/mtab -> /proc/self/mounts in /sysroot (so df works)
	chroot /sysroot ln -sf /proc/self/mounts /etc/mtab

	# 5/ Regenerate initramfs for all deployed kernels
	loginfo "Generating initramfs for all installed kernels"
	for KERNEL in `ls /sysroot/boot|grep vmlinuz`
	do
		si_create_initramfs "${KERNEL#*-}"
	done

}

################################################################################
# si_create_initramfs <kver>
################################################################################
si_create_initramfs() {
	KERNEL_VERSION=$1
	loginfo "Generating initramfs for kernel: ${KERNEL_VERSION}"
	case "$(get_distro_vendor /sysroot)" in
		redhat|centos|fedora)
			INITRD_NAME="/boot/initramfs-${KERNEL_VERSION}.img"
			CMD="dracut --force --hostonly ${INITRD_NAME} ${KERNEL_VERSION}"
			;;
		debian|ubuntu)
			# INITRD_NAME="/boot/initrd.img-${KERNEL_VERSION}"
			CMD="update-initramfs -u -k ${KERNEL_VERSION}"
			;;
		opensuse|suse)
			INITRD_NAME="/boot/initrd-${KERNEL_VERSION}"
			CMD="dracut --force --hostonly "${INITRD_NAME} ${KERNEL_VERSION}
			;;
		*)
			logwarn "Don't know how to regenerate initramfs for installed kernels"
			logwarn "Assuming it'll be done using a post-install script"
			logwarn "Failing to generate a suited initramfs may result in unbootable system"
			;;
	esac

	logaction "chroot /sysroot ${CMD}"
	if ! chroot /sysroot ${CMD}
	then
		logerror "Failed to update initramfs for kernel ${KERNEL_VERSION}"
		logwarn "Failing to generate a suited initramfs may result in unbootable system"
	fi
}

################################################################################
#
# stop_software_raid_and_lvm()
#		stops all volume groups
#		stops all software raid
#			=> disks devices should'nt be buzy there after.
################################################################################
stop_software_raid_and_lvm() {

    # 1/ Stop volume groups
    lvm lvs --noheadings |awk '{print $2}' | sort -u |\
    while read VOL_GROUP
    do
        loginfo "Removing volumegroup [${VOL_GROUP}]"
        lvm vgchange -a n ${VOL_GROUP}
    done

    # 2/ Stop software raid
    if [ -f /proc/mdstat ]; then
        RAID_DEVICES=` cat /proc/mdstat | grep ^md | sed 's/ .*$//g' `

        # Turn dem pesky raid devices off!
        for RAID_DEVICE in ${RAID_DEVICES}
        do
            DEV="/dev/${RAID_DEVICE}"
	    loginfo "stopping ${DEV} raid device"
            logdebug "mdadm --manage ${DEV} --stop"
            mdadm --manage ${DEV} --stop
	    sleep $PARTED_DELAY
        done
    fi

    # 3/ Stop multipath devices.
    if test -z "`LC_ALL=C dmsetup ls|grep 'No devices found'`"
    then
	    logininfo "cleaning up dm devices (multipath, ...)"
	    logdebug "Devices to clean: `dmsetup ls|cut -d' ' -f1|tr '\n' ' '`"
	    dmsetup remove_all
    fi

}

#################################################################################
#
# Install bootloader according disk layout specifications
# (Only supports grub2 and grub)
#
# USAGE: si_install_bootloader
#################################################################################
si_install_bootloader() {
	sis_update_step boot 0 0

	IFS=';'
	. /tmp/variables.txt # Read variables to get the DISKS_LAYOUT_FILE

	BL_INSTALLED="no"

	xmlstarlet sel -t -m 'config/bootloader' -v "concat(@flavor,';',@install_type,';',@default_entry,';',@timeout)" -n ${DISKS_LAYOUT_FILE}  | sed '/^\s*$/d' |\
		while read BL_FLAVOR BL_TYPE BL_DEFAULT BL_TIMEOUT;
		do
			[ "$BL_INSTALLED" = "yes" ] && shellout "Only one bootloader section allowed in disk layout".

			loginfo "Got Bootloader request: $BL_FLAVOR install type=$BL_TYPE"

			# 1st, update config (default menu entry and timeout
			loginfo "Setting default menu=$BL_DEFAULT and timeout=$BL_TIMEOUT"
			case "${BL_FLAVOR}" in
				"grub2")
					# Check that grub2-install is available on imaged system
					[ ! -x /sysroot/usr/sbin/grub2-install ] && [ ! -x /sysroot/sbin/grub2-install ] && shellout "grub2-install missing in image. Can't install grub2 bootloader"

					# Make sure /etc/default exists in /sysroot
					mkdir -p /sysroot/etc/default || shellout "Cannot create /etc/default on imaged system."

					# if a grub2 specific config exists, we need to install it before generating grub.cfg
					# Typically, this file is used to force raid reassembly in initramfs
					if test -r /tmp/grub_default.cfg
					then
						logdebug "Using /tmp/grub_default.cfg as base for /sysroot/etc/default/grub"
						cp -f /tmp/grub_default.cfg /sysroot/etc/default/grub || shellout "Cannot install /etc/default/grub"
					fi

					# Make sure our TIMEOUT and DEFAULT grub variable exists withing the config file
					touch /sysroot/etc/default/grub

					grep "^GRUB_TIMEOUT=" /sysroot/etc/default/grub || echo "GRUB_TIMEOUT=5" >> /sysroot/etc/default/grub
					grep "^GRUB_DEFAULT=" /sysroot/etc/default/grub || echo "GRUB_DEFAULT=saved" >> /sysroot/etc/default/grub

					# Update TIMEPOUT and DEFAULT with values from disk layout file if defined.
					[ -n "$BL_TIMEOUT" ] && sed -i -e "s/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=${BL_TIMEOUT}/g" /sysroot/etc/default/grub && logaction "Setting GRUB_TIMEOUT=$BL_TIMEOUT"
				        [ -n "$BL_DEFAULT" ] && sed -i -e "s/GRUB_DEFAULT=.*$/GRUB_DEFAULT=${BL_DEFAULT}/g" /sysroot/etc/default/grub && logaction "Setting GRUB_DEFAULT=$BL_DEFAULT"

					# Generate grub2 config file from OS already installed 10_linux cfg.
					loginfo "Creating /boot/grub2/grub.cfg"
					logaction "(chroot) grub2-mkconfig --output=/boot/grub2/grub.cfg"
					chroot /sysroot /sbin/grub2-mkconfig --output=/boot/grub2/grub.cfg || shellout "Can't create grub2 config"
					;;
				"grub")
					[ ! -x /sysroot/sbin/grub-install ] && shellout "grub-install missing in image. Can't install grub1 bootloader"
					logwarn "Setting Default entry and timeout not yet supportedi for grub1"
					[ -z "${BL_DEFAULT}" ] && BL_DEFAULT=0
					[ -z "${BL_TIMOUT}" ] && BL_TIMOUT=5
					ROOT=`cat /proc/self/mounts |grep " /sysroot "|cut -d" " -f1`
					OS_NAME=`cat /etc/system-release`
					# BUG: (hd0,0) is hardcoded: need to fix that.
					loginfo "Creating /boot/grub/menu.lst"
					logaction "(chroot) cat > /boot/grub/menu.lst"
					cat > /sysroot/boot/grub/menu.lst <<EOF
default=${BL_DEFAULT}
timeout=${BL_TIMEOUT}
title ${OS_NAME}
	root (hd0,0)
	kernel /$(cd /sysroot/boot; ls -rS vmli*|grep -v debug|tail -1) ro root=$ROOT rhgb quiet
	initrd /$(cd /sysroot/boot; ls -rS init*|grep -v debug|tail -1)
EOF
					test $? -ne 0 && shellout "Failed to create /boot/grub/menu.lst. Error: $?"
					;;
				"clover")
					shellout "Clover bootloader not yet supported."
					;;
				"rEFInd")
					shellout "rEFInd bootloader not yet supported."
					;;
				*)
					shellout "Unsupported bootloader"
					;;
			esac

			# 2nd: install bootloader
			case "$BL_TYPE" in
				"legacy") # legacy: write in disk or partition device
					xmlstarlet sel -t -m "config/bootloader[@flavor=\"${BL_FLAVOR}\"]/target" -v "@dev" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d' |\
                		                while read BL_DEV
						do
							case "$BL_FLAVOR" in
								"grub2")
									[ ! -b "$BL_DEV" ] && shellout "Can't install bootloader: [$BL_DEV] is not a block device!"
									logaction "chroot /sysroot /sbin/grub2-install --force $BL_DEV"
									chroot /sysroot /sbin/grub2-install --force $BL_DEV || shellout "Failed to install grub2 bootloader on ${disk}"
									loginfo "legacy grub2 installed on dev ${BL_DEV}"
									touch /tmp/bootloader.installed
									;;
								"grub")
									[ ! -b "$BL_DEV" ] && shellout "Can't install bootloader: [$BL_DEV] is not a block device!"
									logaction "chroot /sysroot /sbin/grub-install $BL_DEV"
									chroot /sysroot /sbin/grub-install $BL_DEV || shellout "Failed to install grub1 bootloader on ${BL_DEV}"
									loginfo "legacy grub1 installed on dev ${BL_DEV}"
									touch /tmp/bootloader.installed
									;;
								"clover")
									shellout "Clover bootloader not yet supported."
									;;
								"rEFInd")
									shellout "rEFInd doesn't support legacy BIOS. (EFI/UEFI only bootloader)"
									;;
								*)
									shellout "Bootloader [${BL_FLAVOR}] not supported in legacy mode."
									;;
							esac
						done
						;;	
				"efi"|"EFI") # Install in EFI partition an set boot order in EFI nvram
					# TODO: handle multiple EFI menu entries for raid 1 using efibootmgr.
					[ -z "`findmnt -o target,fstype --raw|grep -e '/boot/efi\svfat'`" ] && shellout "No EFI filesystem mounted (/sysroot/boot/efi not a vfat partition)."
					[ ! -d /sysroot/boot/efi/EFI/BOOT ] && shellout "Missing /boot/efi/EFI/BOOT (EFI BOOT directory)."
					[ -r /tmp/EFI.conf ] && . /tmp/EFI.conf # read requested EFI configuration (boot manager, kernel name, ...)
					case "$BL_FLAVOR" in
						"grub2")
							shellout "Not yet supported. Sorry."
							;;
						"grub")
							shellout "grub v1 doesn't supports EFI. Set your bios in legacy boot mode or use another bootloader."
							;;
						"clover")
							shellout "Clover bootloader not yet supported."
							;;
						"rEFInd")
							shellout "rEFInd bootloader not yet supported."
							;;
						*)
							shellout "Unsupported bootloader [$BL_FLAVOR]."
							;;
					esac
					;;
				*)
					shellout "Unknown bootloader type [$BL_TYPE]. Valid values are: legacy and efi."
					;;
			esac
			BL_INSTALLED="yes"
		done

	if test -r /tmp/bootloader.installed
	then
		rm -f /tmp/bootloader.installed
		logdebug "bootloader section treated."
	else
		logwarn "No bootloader installed. (bootloader section missing in disk layout file?)"
		logwarn "Assuming post-install scripts will do the job!"
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
	loginfo "Stopping UDEV exec queue to prevent raid restart when creating partitions"
	udevadm control --stop-exec-queue
	sis_update_step part
	IFS=';'
	xmlstarlet sel -t -m 'config/disk' -v "concat(@dev,';',@label_type,';',@unit_of_measurement)" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d' |\
		while read DISK_DEV LABEL_TYPE T_UNIT;
	       	do
			loginfo "Setting up partitions for disk $DISK_DEV"

			# Create the partition table
			logaction "parted -s -- $DISK_DEV mklabel ${LABEL_TYPE}"
			LC_ALL=C parted -s -- ${DISK_DEV} mklabel "${LABEL_TYPE}" || shellout "Failed to create new partition table for disk $DISK_DEV partition type=$PART_TYPE!"
			sleep $PARTED_DELAY

			# Create the partitions
			T_UNIT=`echo $T_UNIT|sed "s/percent.*/%/g"` # Convert all variations of percent{,age{,s}} to "%"
			xmlstarlet sel -t -m "config/disk[@dev=\"${DISK_DEV}\"]/part" -v "concat(@num,';',@size,';',@p_type,';',@id,';',@p_name,';',@flags,';',@lvm_group,';',@raid_dev)" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d' |\
				while read P_NUM P_SIZE P_TYPE P_ID P_NAME P_FLAGS P_LVM_GROUP P_RAID_DEV
				do
					if test "$P_SIZE" = "*"
					then
						P_SIZE="0" # 0 means 100% for parted
					else
						P_UNIT="$T_UNIT"
					fi
					# Get partition filesystem if it exists (no raid, no lvm) so we can put it in partition filesystem info
					P_FS=`xmlstarlet sel -t -m "config/fsinfo[@real_dev=\"${DISK_DEV}${P_NUM}\"]" -v "@fs" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d'`
					test "${P_FS}" = "swap" && P_FS="linux-swap" # fix swap FS type name for parted.

					# 1/ Create the partition
					CMD="parted -s -- ${DISK_DEV} unit ${P_UNIT} mkpart ${P_TYPE} ${P_FS} `_find_free_space ${DISK_DEV} ${P_UNIT} ${P_TYPE} ${P_SIZE}`"
					logaction "$CMD"
					eval "$CMD" || shellout "Failed to create partition ${DISK_DEV}${P_NUM}"
					sleep $PARTED_DELAY

					# 2/ Set partition number ($partition) using sfdisk
					# Do nothing; assuming xml file use partition in order just like parted.

					# 3/ Set the partition flags
					for flag in `echo $P_FLAGS|tr ',' ' '`
					do
						CMD="parted -s -- ${DISK_DEV} set ${P_NUM} ${flag} on"
						logaction "$CMD"
						eval "$CMD" || logwarn "Failed to set flag ${flag}=on for partition ${DISK_DEV}${P_NUM}"
						sleep $PARTED_DELAY
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
			MIN_SIZE_EXT=( `LC_ALL=C parted -s -- $1 unit $2 print|grep "extended"|sed "s/$2//g"|awk '{ print $2,$4 }'` )
			[ ${#MIN_SIZE_EXT[*]} -eq 0 ] && shellout "Can't create logical partition if no extended partition exists"
			;;
		*)
			# if primary or logical, search the whole disk
			MIN_SIZE_EXT=( 0 0 )
			;;
	esac
	# For each free space
	# if ext_size is non null (we create a logical part) and if checked free space is beyond end of extended, then abort
	# if free block start is within search space and if free block size is big enough for requested size, we found it! => print and exit
	# For extended partitions, if the 1st freeblock checked is outside, we exit without checking other ones if any.
	# => Case cannot occure because logical partition will reach the end of disk. (can't create primary after logical with parted)
	BEGIN_END=( `LC_ALL=C parted -s -- $1 unit $2 print free | grep "Free Space" | sed "s/$2//g" | sort -g -r -k2 | awk -v min=${MIN_SIZE_EXT[0]} -v ext_size=${MIN_SIZE_EXT[1]} -v required="$4" '
	(ext_size>0) && ($1<min || $1>min+ext_size) { exit 1 }
	($1>=min) && (($1<(min+ext_size)) || ext_size==0) && (required==0) { print $1,$2 ; exit 0 }
	($1>=min) && ($1+required)<=$2 && (required!=0) { print $1,$1+required ; exit 0 }
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
	xmlstarlet sel -t -m 'config/raid/raid_disk' -v "concat(@name,';',@raid_level,';',@raid_devices,';',@spare_devices,';',@rounding,';',@layout,';',@chunk_size,';',@lvm_group,';',@devices)" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d' |\
		while read R_NAME R_LEVEL R_DEVS_CNT R_SPARES_CNT R_ROUNDING R_LAYOUT R_CHUNK_SIZE R_LVM_GROUP R_DEVICES
		do
			# If Raid volume uses partitions, get them
			P_DEVICES=`xmlstarlet sel -t -m "config/disk/part[@raid_dev=\"$R_NAME\"]"  -v "concat(ancestor::disk/@dev,@num,' ')" ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d'`
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

			# Raid are created, restard udev so /dev/md* devices are created (needed for mdadm.conf generation)
			loginfo "Restarting UDEV exec queue now that disk(s) is (are) set up"
			udevadm control --start-exec-queue

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
	# Note: in dracut, on some distros, locking_type is set to 4 (readonly) for lvm (/etc/lvm/lvm.conf)
	# to prevent any lvm modification during early boot.
	# We need to get raound this default config.
	# See https://bugzilla.redhat.com/show_bug.cgi?id=865015 (not a bug)
	# LVM_DEFAULT_CONFIG="--config 'global {locking_type=1}'" # At least we need this config.
	# We chose to replace the inapropriate lvm.conf with a generic one that fits our needs.
	mkdir -p /etc/lvm # Make sure lvm config path exists (not present on CentOS-6 for example)
	lvmconfig --type default --withcomments > /etc/lvm/lvm.conf || shellout "Failed to create/overwrite initramfs:/etc/lvm/lvm.conf with default lvm.conf that permits lvm creation/modification/removal."

	loginfo "Creating volume groups"

	xmlstarlet sel -t -m "config/lvm/lvm_group" -v "concat(@name,';',@max_log_vols,';',@max_phys_vols,';',@phys_extent_size)" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d' |\
		while read VG_NAME VG_MAX_LOG_VOLS VG_MAX_PHYS_VOLS VG_PHYS_EXTENT_SIZE
		do
			VG_PARTS=`xmlstarlet sel -t -m "config/disk/part[@lvm_group=\"${VG_NAME}\"]" -s A:T:U num -v "concat(ancestor::disk/@dev,@num,' ')" ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d'`
			VG_RAIDS=`xmlstarlet sel -t -m "config/raid/raid_disk[@lvm_group=\"${VG_NAME}\"]" -s A:T:U name -v "concat(@name,' ')" ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d'`
			# Doing some checks on volume group devices.
			[ -n "${VG_PARTS/ /}" ] && [ -n "${VG_RAIDS/ /}" ] && logwarn "volume group ${VG_NAME} has partitions mixed with raid volumes"
			[ -z "${VG_PARTS/ /}${VG_RAIDS}/ /" ] && logwarn "Volume group [${VG_NAME}] has no devices associated!"

			loginfo "Creating physical volume group ${VG_NAME} for device(s) ${VG_PARTS}${VG_RAIDS}."

			# Getting specific params for volume group ${VG_NAME}
			xmlstarlet sel -t -m "config/lvm/lvm_group[name=\"${VG_NAME}\"]" -v "concat(@max_log_vols,';',@max_phys_vols,';',@phys_extent_size)" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d' | read L_MAX_LOG_VOLS L_MAX_PHYS_VOLS L_PHYS_EXTENT_SIZE

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

			xmlstarlet sel -t -m "config/lvm/lvm_group[@name=\"${VG_NAME}\"]/lv" -v "concat(@name,';',@size,';',@lv_options)" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d' |\
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
		if test -n "$CMD" # BUG: CMD will always be empty (something|while read.... creates sub process; variable in not updated upstream)
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
	cat > /tmp/fstab.image <<EOF
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
	xmlstarlet sel -T -t -m "config/fsinfo" -s A:N:- "@line" -v "concat(@line,'<',@comment,'<',@real_dev,'<',@mount_dev,'<',@mp,'<',@fs,'<',@mkfs_opts,'<',@options,'<',@dump,'<',@pass,'<',@format)" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d' |\
		while read FS_LINE FS_COMMENT FS_REAL_DEV FS_MOUNT_DEV FS_MP FS_FS FS_MKFS_OPTS FS_OPTIONS FS_DUMP FS_PASS FS_FORMAT
		do
			# 1/ Get the label if any.
			[ "${FS_MOUNT_DEV%=*}" = "LABEL" ] && FS_LABEL="${FS_MOUNT_DEV##*=}"

			# Get the UUID, will be usefull for fstab later.
			[ "${FS_MOUNT_DEV%=*}" = "UUID" ] && FS_UUID="${FS_MOUNT_DEV##*=}"

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
			echo -e "${FSTAB_LINE}" >> /tmp/fstab.image
			if test "${FS_MP/ /}" = "/"
			then # keep track of root for possible directboot
				loginfo "Saving root=block:${FS_MOUNT_DEV/ /} to allow normal boot after imaging."
				export root="block:${FS_MOUNT_DEV/ /}"
				export rflags="${FS_OPTIONS}"
				export rootok="1"
				update_dracut_root_infos
			fi
		done
}

################################################################################
# _do_fstab()
#		- Process fstab to create moutpoints for all defined filesystems
#		  If it is a virtual filesystem, a warning is issued.
#		  Now virtual filesystems are not listed in fstab anymore.
#		- Mount physical filesystems so they can receive the image
#		- Save mounted filesystems to initramfs:/etc/fstab.systemimager
################################################################################
_do_fstab() {
	# Process fstab to create moutpoints
	# Now process fstab to create mount points and effectively mout filesystems.
	# We sort it by mount point (we need to create /var before /var/tmp
	# even if user wants /var/tmp before /var in /etc/fstab for example)
	# We also populate initramfs:/etc/fstab.systemimager with mounted filesystems in sorted
        # order	so it's easier later to umount them.
	loginfo "Processing fstab: Creating mount points and mounting physical filesystems."
	unset IFS
	cat /tmp/fstab.image |sed -e 's/#.*//' -e '/^$/d' | sort -k2,2 |\
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
				# Add filesystem to initramfs:/etc/fstab.systemimager (needed when we'll need to unmount them)
				# Set 0 for dump and 0 for pass (not needed in initramfs).
				echo -e "${M_DEV}\t/sysroot${M_MP}\t${M_FS}\t${M_OPTS}\t0 0" >> /etc/fstab.systemimager
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
