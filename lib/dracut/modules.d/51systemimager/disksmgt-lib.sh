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
#      This file hosts functions realted to disk initialization.
#

# Load API and variables.txt (HOSTNAME, IMAGENAME, ..., including detected disks array: $DISKS)
type logmessage >/dev/null 2>&1 || . /lib/systemimager-lib.sh

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
		DISKS_LAYOUT_FILE=`choose_filename ${SCRIPTS_DIR}/disks-layouts ".xml"`
	else
		DISKS_LAYOUT_FILE=${SCRIPTS_DIR}/disks-layouts/${DISKS_LAYOUT}
		test ! -f "${DISKS_LAYOUT_FILE}" && DISKS_LAYOUT_FILE=${SCRIPTS_DIR}/disks-layouts/${DISKS_LAYOUT}.xml
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

	# 1st, we need to validdate the disk-layout file.
	loginfo "Validating disk layout: ${DISKS_LAYOUT_FILE}"
	xmlstarlet val --err --xsd /lib/systemimager/disks-layout.xsd ${DISKS_LAYOUT_FILE} || shellout "Disk layout file is invalid. Check error logs and fix problem."
	loginfo "Disk layout seems valid; continuing..."

	# Initialisae / check LVM version to use. (defaults to v2).
	LVM_VERSION=`xmlstarlet sel -t -m "config/lvm" -if "@version" -v "@version" --else -o "2" -b ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d'`

	loginfo "Stopping software raid and LVM that may still be active."
	stop_software_raid_and_lvm
	loginfo "Stopping UDEV exec queue to prevent raid restart when creating partitions"
	udevadm control --stop-exec-queue
	_do_partitions
	_do_raids
	# Raid are created, restard udev so /dev/md* devices are created (needed for mdadm.conf generation)
	loginfo "Restarting UDEV exec queue now that disk(s) is (are) set up"
	udevadm control --start-exec-queue
	_do_mdadm_conf
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
			lvm config --type default --withcomments > /sysroot/etc/lvm/lvm.conf 6>&- 7>&-

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
		logaction "chroot /sysroot vgscan"
		chroot /sysroot vgscan 6>&- 7>&-
		loginfo "lvm configuration done"
	fi

	# 4/ Make sure /etc/mtab -> /proc/self/mounts in /sysroot (so df works)
	loginfo "Creating /etc/mtab"
	logaction "chroot /sysroot ln -sf /proc/self/mounts /etc/mtab"
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
	CMD=""
	loginfo "Generating initramfs for kernel: ${KERNEL_VERSION}"
	case "$(get_distro_vendor /sysroot)" in
		redhat|centos|almalinux|rocky|fedora)
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
			logwarn "Image has no /etc/os-release or similar identification file"
			logwarn "Can't determine distribution, thus:"
			logwarn "Don't know how to regenerate initramfs for installed kernels"
			logwarn "Assuming it'll be done using a post-install script"
			logwarn "Failing to generate a suited initramfs may result in unbootable system"
			;;
	esac

	if test -n "${CMD}"
	then
		logaction "chroot /sysroot ${CMD}"
		if ! chroot /sysroot ${CMD}
		then
			logerror "Failed to update initramfs for kernel ${KERNEL_VERSION}"
			logwarn "Failing to generate a suited initramfs may result in unbootable system"
		fi
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
    lvm lvs --noheadings 6>&- 7>&- |awk '{print $2}' | sort -u |\
    while read VOL_GROUP
    do
        loginfo "Removing volumegroup [${VOL_GROUP}]"
        lvm vgchange -a n ${VOL_GROUP} 6>&- 7>&-
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

	. /tmp/variables.txt # Read variables to get the DISKS_LAYOUT_FILE

	local IFS=';'

	BL_INSTALLED="no"

	xmlstarlet sel -t -m 'config/bootloader' -v "concat(@flavor,';',@install_type,';',@default_entry,';',@timeout)" -n ${DISKS_LAYOUT_FILE}  | sed '/^\s*$/d' |\
		while read BL_FLAVOR BL_TYPE BL_DEFAULT BL_TIMEOUT;
		do
			[ "$BL_INSTALLED" = "yes" ] && shellout "Only one bootloader section allowed in disk layout".

			loginfo "Got Bootloader request: $BL_FLAVOR install type=$BL_TYPE"

			# 1st, update config (default menu entry and timeout
			loginfo "Setting default menu=$BL_DEFAULT and timeout=$BL_TIMEOUT"
			case "${BL_FLAVOR}" in
				"systemd")
					# nothing to do here.
					;;
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
					logwarn "Setting Default entry and timeout not yet supported for grub1"
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
					logwarn "rEFInd menu entries not configurable yet."
					;;
				*)
					shellout "Unsupported bootloader [$BL_FLAVOR]."
					;;
			esac

			# 2nd: install bootloader
			case "$BL_TYPE" in
				"legacy") # legacy: write in disk or partition device
					xmlstarlet sel -t -m "config/bootloader[@flavor=\"${BL_FLAVOR}\"]/target" -v "@dev" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d' |\
                		                while read BL_DEV
						do
							case "$BL_FLAVOR" in
								"systemd")
									shellout "systemd-boot doesn't support legacy BIOS. (EFI/UEFI only bootloader)";
									;;
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
					[ ! -d /sys/firmware/efi ] && shellout "BIOS is not EFI. Switch your BIOS to EFI, or use legacy for bootloader type in disks-layout."
					[ -z "`findmnt -o target,fstype --raw|grep -e '/boot/efi\svfat'`" ] && shellout "No EFI filesystem mounted (/sysroot/boot/efi not a vfat partition)."
					[ ! -d /sysroot/boot/efi/EFI/BOOT ] && shellout "Missing /boot/efi/EFI/BOOT (EFI BOOT directory). Check/Update your image."
					[ -r /tmp/EFI.conf ] && . /tmp/EFI.conf # read requested EFI configuration (boot manager, kernel name, ...)
					case "$BL_FLAVOR" in
						"systemd")
							[ -x /sysroot/usr/bin/bootctl ] || shellout "bootctl (systemd-boot) missing in image! Update your imlage!"
							logaction "/usr/bin/bootctl --path=/boot/efi install"
							chroot /sysroot /usr/bin/bootctl --path=/boot/efi install
							loginfo "systemd-boot installed on EFI partition."
							# install is incomplete, we need to move entries, kernels and initrds into ESP.
							if test $(find /sysroot/boot/efi/loader/entries/ -type f|wc -l) -eq 0
							then
								loginfo "systemd-boot entries not in EFI partition, moving them to correct location"
								mv -f /sysroot/boot/loader/entries /sysroot/boot/efi/loader/entries
							fi
							logininfo "copying kernel and intrd to EFI system partition"
							cp -v /sysroot/boot/(*linu*,*kernel*,*init*,config*,*.map*) /sysroot/boot/efi/
							# BUG: review this process
							# Need to set default entry and timeout in /sysroot/boot/efi/loader/loader.conf

							touch /tmp/bootloader.installed
							;;
						"grub2")
							[ -x /sysroot/usr/sbin/efibootmgr ] || shellout "efibootmgr missing in image! Update your imlage!"
							[ -d /sysroot/usr/lib/grub/$(uname -m)-efi ] || shellout "/usr/lib/grub/$(uname -m)-efi missing in image! Install grube2-efi-*-modules package"

							# grub2-install doesn't support EFI starting from RHEL 8.3
							#logaction "chroot /sysroot /sbin/grub2-install --force --target=$(uname -m)-efi"
							# chroot /sysroot /sbin/grub2-install --force --target=$(uname -m)-efi || shellout "Failed to install grub2 EFI bootloader"

							# Loop on all EFI partitions (more than one if soft raid 1)
							IFS='\n'
							for EFI_PART in $(xmlstarlet sel -t -m 'config/disk/part[@flags="esp"]' -v "concat('-d ',ancestor::disk/@dev,' -p ',@num)" -n ${DISKS_LAYOUT_FILE})
							do
								logaction "/usr/sbin/efibootmgr -c -D $EFI_PART -L '"$IMAGENAME"' -l '\EFI\shimx64.efi'"
								chroot /sysroot /usr/sbin/efibootmgr -c -D $EFI_PART -L "$IMAGENAME" -l '\EFI\shimx64.efi'
								loginfo "EFI grub2 installed on EFI partition."
								touch /tmp/bootloader.installed
							done
							unset IFS
							;;
						"grub")
							shellout "grub v1 doesn't supports EFI. Set your bios in legacy boot mode or use another bootloader."
							;;
						"clover")
							shellout "Clover bootloader not yet supported."
							;;
						"rEFInd")
							test -x /usr/sbin/refind-install || shellout "refind-install missing in image. Install rEFInd in image!"

							# Remove any existing NVRAM entry for rEFInd, to avoid creating a duplicate.
							OLD_REFIND_ENTRY=$(efibootmgr | grep "rEFInd Boot Manager" | cut -c 5-8)
							if test -n "${OLD_REFIND_ENTRY}" ; then
					   			efibootmgr --bootnum $OLD_REFIND_ENTRY --delete-bootnum &> /dev/null && loginfo "Removed old rEFInd boot entry from NVRAM"
							fi
							EFI_PRELOADER=`find /boot -name shim\.efi -o -name shimx64\.efi -o -name PreLoader\.efi 2> /dev/null | head -n 1`
							test -z "${EFI_PRELOADER}" && logwarn "No EFI preloader in /boot; You should install shim or shim-x64 package in image. Using our own."
							PRELOADER_OPT="--shim ${EFI_PRELOADER}"

							# Check if system is using secure boot.
							test -r /sys/firmware/efi/vars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c/data && SECURE_BOOT=$(od -An -t u1 /sys/firmware/efi/vars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c/data | tr -d '[[:space:]]') || SECURE_BOOT="0"
					
							test -x /usr/bin/sbsign -a -x /usr/bin/openssl && KEY_OPTION="--localkeys"

							if test "${SECURE_BOOT}" = "1"
							then
								CMD="refind-install $PRELOADER_OPT $KEY_OPTION --yes"
							else
								CMD="refind-install $KEY_OPTION --yes"
							fi

							logaction "$CMD"
							eval "$CMD" || shellout "Failed to setup rEFInd boot manager".
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
# _get_part_dev_from_disk_dev()
# $1: Path to disk device
# $2: PArtition number
# return: Partition full device PATH
#
# Note: Patition Path is NOT equal to concat of disk device and partition number
#       => /dev/cciss/c0d0 part 1 is NOT /dev/cciss/c0d01. (/dev/cciss/c0d0p1)
################################################################################

_get_part_dev_from_disk_dev() {
	test ! -b "$1" && shellout "[$1] is not a block device."
	test -z "$2" && shellout "Missing partition number."
	test -n "${2//[0-9]/}" && shellout "[$2] is not a partition number"
	if test -b "$1"
	then
		PART_NAME=$1
		# If block device ends with a number we need to add a "p"
		LAST_DEVNAME_CHAR=${1: -1} # Get the last char
		test -z ${LAST_DEVNAME_CHAR/[0-9]/} && PART_NAME="${PART_NAME}p" # add a "p" if it's a number
		PART_NAME="${PART_NAME}$2"
		test ! -b $PART_NAME && shellout "Device [$PART_NAME] for partition $2 of block device $1 is not a block device or doesn't exists."
		echo $PART_NAME
	fi
	#Doess't work when udev is frozen
	#if test -b "$1"
	#then
	#	PART_SYMLINK_PATH=$(udevadm info -q symlink $1|cut -d' ' -f1)-part$2
	#	if test -l /dev/$PART_SYMLINK_PATH
	#	then
	#		PART_DEVICE=$(readlink -f /dev/$PART_SYMLINK_PATH)
	#		if test -d $PART_DEVICE
	#		then
	#			echo $PART_DEVICE
	#		else
	#			shellout "No such device: [$PART_DEVICE]"
	#		fi
	#	else
	#		shellout "$1 has not partition #$2".
	#	fi
	#else
	#	shellout "[$1] is no a block device"
	#fi

	#if test -b "$1"
	#then
	#	DEV_MAJOR=$(printf "%d" "0x$(stat -c '%t' $1)")
	#else
	#	shellout "[$1] is no a block device"
	#fi

	#test -n "${2//[0-9]/}" && shellout "[$2] is not a partition number"
	
	#if test ! -r /sys/dev/block/$DEV_MAJOR:$2/uevent
	#then
	#	logerror "Can't read /sys/dev/block/$DEV_MAJOR:$2/uevent"
	#	shellout "Can't gather $1 partition $2 informations"
	#fi

	#. /sys/dev/block/$DEV_MAJOR:$2/uevent
	#test "$DEVTYPE" != "partition" && shellout "/sys/dev/block/$DEV_MAJOR:$2 TYPE=$DEVTYPE is not a partition."

	# echo $(udevadm info --query=name --path=/sys/dev/block/$DEV_MAJOR:$2)
	#echo "/dev/$DEVNAME"
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
# OL: Tips: Beginning of disk: 2048s (1MiB), End of disk: -2048s (space for GPT table)
_do_partitions() {
	sis_update_step part
	local IFS=';'

	xmlstarlet sel -t -m 'config/disk' -v "concat(@dev,';',@label_type,';',@unit_of_measurement)" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d' |\
		while read DISK_DEV LABEL_TYPE T_UNIT;
	       	do
			loginfo "Setting up partitions for disk $DISK_DEV"

			# Create the partition table: Do not write/create partition table if it is not type msdos or gpt.
			if test -n "$(echo ${LABEL_TYPE}|grep -iE 'msdos|gpt')"
			then
				logaction "parted -s -- $DISK_DEV mklabel ${LABEL_TYPE}"
				LC_ALL=C parted -s -- ${DISK_DEV} mklabel "${LABEL_TYPE}" || shellout "Failed to create new partition table for disk $DISK_DEV partition type=$PART_TYPE!"
				sleep $PARTED_DELAY
			elif test -n "$(echo ${LABEL_TYPE}|grep -iE 'convert')"
			then
				loginfo "Converting ${DISK_DEV} partition table to GPT..."
				logaction "sgdisk  --mbrtogpt ${DISK_DEV}"
				sgdisk  --mbrtogpt ${DISK_DEV} || shellout "Failed to convert ${DISK_DEV} partition table to GPT."
			fi
		done

	# We use an xsd translmation file to present partition in an order that
	# permit to create variable size (*) partition in the middle of 2 others
	xmlstarlet tr /lib/systemimager/do_partitions.xsl ${DISKS_LAYOUT_FILE} |\
		while read DISK_DEV LABEL_TYPE P_RELATIV P_NUM P_SIZE P_UNIT P_TYPE P_ID P_NAME P_FLAGS P_LVM_GROUP P_RAID_DEV
		do
			# P_TYPE / P_NUM choherence check
			case $P_TYPE in
				"logical")
					test "$P_NUM" -lt 5 && shellout "Logical partition $P_NUM ($DISK_DEV) invalid (@num <= 4 is invalid)"
					test "$LABEL_TYPE" = "gpt" && shellout "Logical patition $P_NUM not allowed on GPT table ($DISK_DEV)"
					;;
				"primary")
					test "$P_NUM" -gt 4 -a "$LABEL_TYPE" = "msdos" && shellout "Primary partition $P_NUM ($DISK_DEV) invalid (@num > 4 is invalid)"
					;;
				"extended")
					test "$LABEL_TYPE" = "gpt" && shellout "Extended partition $P_NUM ($DISK_DEV) incompatible with label type $LABEL_TYPE"
					test "$P_NUM" -gt 4 && shellout "Extended partition $P_NUM ($DISK_DEV) invalid (@num > 4 is invalid)"
					test "$EXTENDED_SEEN" = "$DISK_DEV" && shellout "Only ONE extended partition allowed per disk. ($DISK_DEV)"
					EXTENDED_SEEN="$DISK_DEV"
					;;
				*)
					shellout "BUG: P_TYPE invalid [$P_TYPE]; please report."
					;;
			esac
			test ! -b "$DISK_DEV" && shellout "Device [$DISK_DEV] does not exists."

			# Create the partitions
			P_UNIT=`echo $P_UNIT|sed "s/percent.*/%/g"` # Convert all variations of percent{,age{,s}} to "%"
			test -z "${P_SIZE/[0\*]/}" && P_SIZE=0

			P_SIZE_SECTORS=$(convert2sectors "${DISK_DEV##*/}" "$P_SIZE" "$P_UNIT"|cut -d. -f1)
			P_START_SIZE=( `_find_free_space $DISK_DEV $P_RELATIV $P_TYPE $P_SIZE_SECTORS` )
			# If resulting table is empty, this means we didn't find a large enough space to host this partition.
			test ${#P_START_SIZE[*]} -eq 0 && shellout "No sufficient space left on device $DISK_DEV for a partition of size $P_SIZE$P_UNIT"
			START_BLOCK=${P_START_SIZE[0]}
			SIZE=${P_START_SIZE[1]}
			case $LABEL_TYPE in
				"msdos")
					test -z "${SIZE/0/}" && OFFSET_SIZE="" || OFFSET_SIZE="+$((${SIZE}-1))" # fdisk computes wrong size bigger by one block
					logaction "fdisk -u -c $DISK_DEV <<< 'n\\n$P_TYPE\\n$P_NUM\\n$START_BLOCK\\n$OFFSET_SIZE\\nw'"
					fdisk -u -c $DISK_DEV > /dev/null <<EOF
n
${P_TYPE}
${P_NUM}
${START_BLOCK}
${OFFSET_SIZE}
w
EOF
					test $? -ne 0 && shellout "Failed to create partition ${P_NUM} on ${DISK_DEV}"
					sleep $PARTED_DELAY
					;;
				"gpt")
					test -z "${SIZE/0/}" && OFFSET_SIZE="0" || OFFSET_SIZE="+${SIZE}"
					logaction "sgdisk -n ${P_NUM}:${START_BLOCK}:${OFFSET_SIZE} ${DISK_DEV}"
					sgdisk -n ${P_NUM}:${START_BLOCK}:${OFFSET_SIZE} ${DISK_DEV} || shellout "Failed to create partition ${P_NUM} on ${DISK_DEV}"
					sleep $PARTED_DELAY
					;;
				*)
					;;
			esac

			# Get partition filesystem if it exists (no raid, no lvm) so we can set the correct partition type/id
			P_DEV=$(_get_part_dev_from_disk_dev ${DISK_DEV} ${P_NUM}) # Find correct partition device path.
			P_FS=`xmlstarlet sel -t -m "config/fsinfo[@real_dev=\"${P_DEV}\"]" -v "@fs" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d'`
			# Set partition filesystem
			if test -n "$P_FS"
			then
				_set_partition_flag_and_id "$LABEL_TYPE" "$DISK_DEV" "$P_NUM" "$P_FS"
			else
				logwarn "$P_DEV has no filesystem defined in disk-layout"
				logwarn "Update ${DISKS_LAYOUT_FILE##*/} in /var/lib/systemimager/scripts/disks-layouts/"
				logwarn "by adding appropriate fsinfo section on your image server."
				logwarn "See systemimager.disks-layout(7) manual for more informations."
			fi

			# Set partition ID if provided
			if test -n "$P_ID"
			then
				_set_partition_flag_and_id $LABEL_TYPE $DISK_DEV $P_NUM $P_ID
				# TODO Handle error
			fi

			# 3/ Set the partition flags
			for flag in `echo $P_FLAGS|tr ',' ' '`
			do
				test -n "${flag/-/}" && _set_partition_flag_and_id "$LABEL_TYPE" "$DISK_DEV" "$P_NUM" "$flag"
			done

			# Testing that lvm flag is set if lvm group is defined.
			[ -n "${P_LVM_GROUP}" ] && [ -z "`echo $P_FLAGS|grep lvm`" ] && shellout "Missing lvm flag for ${P_DEV}"

		done
}

################################################################################
#
# _set_partition_flag_and_id()
#    - $1: partition label type (msdos or gpt)
#    - $2: device
#    - $3: partition
#    - $4: flag or id(2digits) or od(4digits) or filesystem
#
# Note: flag/id/filesystem are often similar. for exemple efi flag under parted
#       is in fact a special partition GUID.
#
################################################################################
_set_partition_flag_and_id() {
	loginfo "Setting [$4] attribute for partition $(_get_part_dev_from_disk_dev $2 $3)"
	case $4 in
		ext2|ext3|ext4|xfs|jfs|reiserfs|btrfs)
			case $1 in
				msdos)
					logdebug "sfdisk --change-id $2 $3 83"
					sfdisk --change-id $2 $3 83
					;;
				gpt)
					logdebug "sgdisk $2 -t $3:8300"
					sgdisk $2 -t $3:8300
					;;
			esac
			;;
		ntfs|msdos|vfat|fat|fat32|fat16)
			case $1 in
				msdos)
					logdebug "sfdisk --change-id $2 $3 7"
					sfdisk --change-id $2 $3 7
					;;
				gpt)
					logdebug "sgdisk $2 -t $3:0700"
					sgdisk $2 -t $3:0700
					;;
			esac
			;;
		swap)
			case $1 in
				msdos)
					logdebug "sfdisk --change-id $2 $3 82"
					sfdisk --change-id $2 $3 82
					;;
				gpt)
					logdebug "sgdisk $2 -t $3:8200"
					sgdisk $2 -t $3:8200
					;;
			esac
			;;
		root)
			# This flag only exists on MacOS to inform linux of its root partition.
			case $1 in
				msdos|gpt)
					logdebug "Ignoring root flag (only required on MAC partition tables)"
					;;
				mac)
					logdebug "parted -s $2 -- set $3 root on"
					parted -s $2 -- set $3 root on
					;;
			esac
			;;
		boot)
			logdebug "parted -s $2 -- set $3 boot on"
			parted -s $2 -- set $3 boot on
			;;
		esp)
			# 1sgt set boot flag.
			logdebug "parted -s $2 -- set $3 boot on"
			parted -s $2 -- set $3 boot on

			# Then set PART-GUID/ef flag
			case $1 in
				msdos)
					logwarn "EFI on msdos partition table is strongly discouraged"
					logwarn "If you really want to do so you must enable legacy support"
					logwarn "in your EFI BIOS - AND - Disable secure boot!"
					logdebug "sfdisk --change-id $2 $3 ef"
					sfdisk --change-id $2 $3 ef
					;;
				gpt)
					# Set correct Partition GUID
					# sgdisk $2 -t $3:ef00 # Same as below.
					logdebug "sgdisk $2 -t \"$3:C12A7328-F81F-11D2-BA4B-00A0C93EC93B\""
					sgdisk $2 -t "$3:C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
					sleep $PARTED_DELAY
					# Set correct partition label (name)
					logdebug "sgdisk $2 -c \"$3:EFI System Partition\""
					sgdisk $2 -c "$3:EFI System Partition"
					;;
			esac
			;;
		hidden)
			logdebug "parted -s $2 -- set $3 hidden on"
			parted -s $2 -- set $3 hidden on
			;;
		lvm)
			case $1 in
				msdos)
					logdebug "sfdisk --change-id $2 $3 31"
					sfdisk --change-id $2 $3 31
					;;
				gpt)
					logdebug "sgdisk $2 -t $3:8e00"
					sgdisk $2 -t $3:8e00
					;;
			esac
			;;
		raid)
			logdebug "parted -s $2 -- set $3 raid on"
			parted -s $2 -- set $3 raid on
			;;
		lba)
			logdebug "parted -s $2 -- set $3 lba on"
			parted -s $2 -- set $3 lba on
			;;
		legacy_boot)
			case $1 in
				msdos)
					loginfo "Enabling 'legacy_boot' for Device $2 Partition $3."
					logdebug "fdisk -u -c $2 <<< 'a\\n$3\\nc\\nw'"
					# BUG: Will fail if only one partition: need to use sfdisk instead
					fdisk -u -c $2 > /dev/null <<EOF
a
$3
c
w
EOF
					;;
				gpt)
					logwarn "Device $2 Partition $3: legacy_boot incompatible with GPT partition table"
					;;
			esac
			;;
		*)
			# 2digits (msdos)
			if test -z "$(echo $4|sed -E 's/^[0-9A-Za-z]{1,2}//g')"
			then
				test $1='gpt' && shellout "gpt id are 4 digits (see sgdisk -L output for a list)"
				logdebug "sfdisk --change-id $2 $3 $4"
				sfdisk --change-id $2 $3 $4
			# 4digits (gpt)
			elif test -z "$(echo $4|sed -E 's/^[0-9A-Za-z]{4}//g')"
			then
				test $1='msdos' && shellout "gpt ids are 1 or 2 digits (see fdisk manual)"
				logdebug "sgdisk $2 -t $3:$4"
				sgdisk $2 -t $3:$4
			else
				# else ignore.
				# we don't support palo, prep, diag, ...
				logwarn "Device $2 Partition $3 Unknown or unsupported flag/id: [$4]"
			fi
			;;
	esac
	test $? -ne 0 && logerror "Failed to set [$4] attribute for partition $3 on device $2"
	sleep $PARTED_DELAY
}

################################################################################
#
# _find_free_space()
#		This functions return a "aligned-start-sector size-or-100%" positions withing available
#		space on disk that matches requirements.
#		(free space for logical partitions is searched withing extended
#		partition)
# 	- $1 disk dev
#	- $2 search from (end / beginning)
#	- $3 type (primary extended logical)
#	- $4 requested size (sectors)
#
# TODO: Need to return aligned partitions. For this, we need to convert to MiB
#       and aligne to 1MiB so it fits all disks aligments...
#	Also need to use lsblk -dt /dev/sda to compute aligment
# TODO: Enhancement: use http://people.redhat.com/msnitzer/docs/io-limits.txt
#       if possible for optimal aligment; fallback to 1MiB aligment only if not
#       supported by disk device.
#
################################################################################
#
_find_free_space() {
	unset IFS # Make sure IFS is not set
	case "$3" in
		logical)
			# if partition is logical, get the working range to seach for free space
			START_END_PART_ZONE=( `LC_ALL=C parted -s -- $1 unit s print|grep "extended"|sed "s/s//g"|awk '{ print $2,$3 }'` )
			[ ${#START_END_PART_ZONE[*]} -eq 0 ] && shellout "Can't create logical partition if no extended partition exists"
			;;
		*)
			# if primary or extended, search the whole disk
			LAST_BLOCK=$(echo "$(blockdev --getsize $1) 1 - p" | dc)
								# We don't search free space starting at zero as there is some reserved space
								# for partition table, boot sector and such.
								# we start at 34, the smalest value we can encounter
								# it will get rounded to next alignment value anyway.
			START_END_PART_ZONE=( 34 $LAST_BLOCK )  # msdos: start_free=63s / gpt: start_free=34s.
			;;
	esac

	case "$2" in
		# We try to find a matching space given the partition size and the aligment value.
		# Spaces smaller than aligment value are ignored ($3 > align required).
		# This will avoid returning a useless gap when looking for a zero sized (max size) partition.
		end) # Searching from the end.
			# We align to the lower rounded aligned partition to make sure we can honnor
		        # the requested space. We use 0 size (100%), so trailing sectors beween end
		        # of partition and next aligned partition are included in current partition
			START_SIZE=(`LC_ALL=C parted -s -- $1 unit s print free | tac | grep 'Free Space' | sed 's/s//g' | awk -v ext_start=${START_END_PART_ZONE[0]} -v ext_end=${START_END_PART_ZONE[1]} -v req_size="$4" -v align=$(_get_sectors_aligment ${1##*/}) '
			BEGIN { exit_code=1 }
			($3 > align) && (req_size == 0) { printf "%d 0",($1-1+align)-(($1-1)%align) ; exit_code=0; exit }
			($3 > align) && ($1 >= ext_start) && ($2 <= ext_end) && (($2-req_size+1)-(($2-req_size+1)%align) >= $1) { printf "%d 0",($2-req_size+1)-(($2-req_size+1)%align); exit_code=0; exit } # Align to lower block. Second argument: 0 means 100% \
			END { exit exit_code }
			'` ) || shellout "Failed to find free space for a $3 partition of size ${4}s"
			;;
		beginning) # Searching from beginning
			# We round the requested size to multiple of aligment in order to avoid
		        # loosing space between end of artition and next aligned one. We assume
			# that (empty disk last block + 1) % aligment = 0. If not, creating a
			# fixed size partition of exact blocks count could fail. (disk layout
			# replication with no variable size partition for example)
			START_SIZE=(`LC_ALL=C parted -s -- $1 unit s print free |       grep 'Free Space' | sed 's/s//g' | awk -v ext_start=${START_END_PART_ZONE[0]} -v ext_end=${START_END_PART_ZONE[1]} -v req_size="$4" -v align=$(_get_sectors_aligment ${1##*/}) '
			BEGIN { exit_code=1; opt_size=(req_size-1+align)-(req_size-1)%align }
			($3 > align) && (req_size == 0) { printf "%d 0",($1-1+align)-(($1-1)%align) ; exit_code=0; exit }
			($3 > align) && ((($1-1+align)-(($1-1)%align))>=ext_start) && ($2<=ext_end) && ((($1-1+align)-(($1-1)%align)+opt_size)<=$2) { printf "%d %d",($1-1+align)-(($1-1)%align),opt_size; exit_code=0; exit } # Enough space: print start block rounded to next alig position and size)\
			END { exit exit_code }
			'` ) || shellout "Failed to find free space for a $3 partition of size ${4}s"
			;;
	esac

	local IFS=';'
	echo "${START_SIZE[*]}" 
}

################################################################################
# _do_raids()
#		Create software raid devices if any are defined.
#
################################################################################
_do_raids() {
	loginfo "Creating software raid devices if needed."
	local IFS=';'
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
			eval "yes 2> /dev/null | ${CMD}" || shellout "Failed to create raid${R_LEVEL} with ${R_DEVICES}"

		done
}

_do_mdadm_conf() {
	# Now check if we need to create a mdadm.conf
	if test $(xmlstarlet sel -t -m 'config/raid/raid_disk' -v '@name' -n ${DISKS_LAYOUT_FILE} |wc -l) -gt 0 # We created at least one raid volume.
	then
		# Create the grub2 config the force raid assembling in initramfs.
		# GRUB_CMDLINE_LINUX_DEFAULT is use in normal operation but not in failsafe
		# GRUB_CMDLINE_LINUX is use in al circumstances. We do not want to try to assemble raid in failsafe.
		loginfo "Adding rd.auto to grub cmdline to force raid assembling in initramfs"
		cat > /tmp/grub_default.cfg <<EOF
GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} rd.auto"
EOF

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
	else
		loginfo "No mdadm.conf file to create (no raid)"
	fi
}

################################################################################
# _do_lvm()
#		Initialize LVM if any are defined in the DISKS_LAYOUT_FILE
#		
################################################################################
_do_lvms() {
	# Note: in dracut, on some distros, locking_type is set to 4 (readonly) for lvm (/etc/lvm/lvm.conf)
	# to prevent any lvm modification during early boot.
	# We need to get raound this default config.
	# See https://bugzilla.redhat.com/show_bug.cgi?id=865015 (not a bug)
	# LVM_DEFAULT_CONFIG="--config 'global {locking_type=1}'" # At least we need this config.
	# We chose to replace the inapropriate lvm.conf with a generic one that fits our needs.
	# Note, closing fd 6 and 7 in order to avoir lvm leaked file descriptor warnings.
	#       LVM expect only FD 1, 2 and 3 and will close all other file descriptors.

	mkdir -p /etc/lvm # Make sure lvm config path exists (not present on CentOS-6 for example)
	lvmconfig --type default --withcomments > /etc/lvm/lvm.conf 6>&- 7>&- || shellout "Failed to create/overwrite initramfs:/etc/lvm/lvm.conf with default lvm.conf that permits lvm creation/modification/removal."

	loginfo "Creating volume groups"

	local IFS=';'
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
			eval "$CMD 6>&- 7>&-" || shellout "Failed to prepare devices for being part of a LVM"

			# Now we cleanup any previous volume groups.
			loginfo "Cleaning up any previous volume groups named [${VG_NAME}]"
			lvremove ${LVM_DEFAULT_CONFIG} -f /dev/${VG_NAME} >/dev/null 2>&1  6>&- 7>&- && vgremove ${VG_NAME} >/dev/null 2>&1  6>&- 7>&-

			# Now we create the volume group.
			CMD="vgcreate ${LVM_DEFAULT_CONFIG} -M${LVM_VERSION}"
			[ -n "${VG_MAX_LOG_VOLS/ /}" ] && CMD="${CMD} -l ${VG_MAX_LOG_VOLS/ /}"
			[ -n "${VG_MAX_PHYS_VOLS/ /}" ] && CMD="${CMD} -p ${VG_MAX_PHYS_VOLS/ /}"
			[ -n "${VG_PHYS_EXTENT_SIZE/ /}" ] && CMD="${CMD} -s ${VG_PHYS_EXTENT_SIZE/ /}"
			CMD="${CMD} ${VG_NAME} ${VG_PARTS}${VG_RAIDS}"
			logaction "${CMD}"
			eval "${CMD} 6>&- 7>&-" || shellout "Failed to create volume group [${VG_NAME}]"

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
					eval "${CMD} 6>&- 7>&-" || shellout "Failed to create logical volume ${LV_NAME}"

					loginfo "Enabling logical volume ${LV_NAME}"
					CMD="(lvscan > /dev/null; lvchange -a y /dev/${VG_NAME}/${LV_NAME})"
					logaction "${CMD}"
					eval "${CMD} 6>&- 7>&-" || shellout "lvchange -a y /dev/${VG_NAME}/${LV_NAME} failed!"
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
	local IFS='<' # (need to use an XML forbidden char that is not & (used for escaped chars) (we could have used '>')
	# Comment field can have any chars except &,<,>. forced output as TEXT (-T) so we dont end up with "&lt" instead of "<".
	xmlstarlet sel -T -t -m "config/fsinfo" -s A:N:- "@line" -v "concat(@line,'<',@comment,'<',@real_dev,'<',@mount_dev,'<',@mp,'<',@fs,'<',@mkfs_opts,'<',@options,'<',@dump,'<',@pass,'<',@format)" -n ${DISKS_LAYOUT_FILE} | sed '/^\s*$/d' |\
		while read FS_LINE FS_COMMENT FS_REAL_DEV FS_MOUNT_DEV FS_MP FS_FS FS_MKFS_OPTS FS_OPTIONS FS_DUMP FS_PASS FS_FORMAT
		do
			# 1/ Get the label if any.
			FS_LABEL=""
			[ "${FS_MOUNT_DEV%=*}" = "LABEL" ] && FS_LABEL="${FS_MOUNT_DEV##*=}"

			# Get the UUID, will be usefull for fstab later.
			FS_UUID=""
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
					[ -n "${FS_UUID/ /}" ] && logwarn "${FS_FS} does not support UUID. Ignoring..."
					SET_UUID_CMD=""
					[ -n "${FS_LABEL/ /}" ] && MKFS_CMD="${MKFS_CMD} -L ${FS_LABEL/ /}"
					MKFS_CMD="${MKFS_CMD} -q"
					;;
				vfat|msdos|fat)
					[ -n "${FS_UUID/ /}" ] && logwarn "${FS_FS} does not support UUID. Ignoring..."
					SET_UUID_CMD=""
					[ -n "${FS_LABEL/ /}" ] && MKFS_CMD="${MKFS_CMD} -n ${FS_LABEL/ /}"
					FS_FS="vfat"
					;;
				fat16)
					[ -n "${FS_UUID/ /}" ] && logwarn "${FS_FS} does not support UUID. Ignoring..."
					SET_UUID_CMD=""
					MKFS_CMD="mkfs -t msdos -F 16 ${FS_MKFS_OPTS/ /}"
					[ -n "${FS_LABEL/ /}" ] && MKFS_CMD="${MKFS_CMD} -n ${FS_LABEL/ /}"
					FS_FS="vfat"
					;;
				fat32)
					[ -n "${FS_UUID/ /}" ] && logwarn "${FS_FS} does not support UUID. Ignoring..."
					SET_UUID_CMD=""
					MKFS_CMD="mkfs -t msdos -F 32 ${FS_MKFS_OPTS/ /}"
					[ -n "${FS_LABEL/ /}" ] && MKFS_CMD="${MKFS_CMD} -n ${FS_LABEL/ /}"
					FS_FS="vfat"
					;;
				swap)
					MKFS_CMD="mkswap -v1 ${FS_MKFS_OPTS/ /}"
					[ -n "${FS_UUID/ /}" ] && MKFS_CMD="${MKFS_CMD} -U ${FS_UUID/ /}"
					[ -n "${FS_LABEL/ /}" ] && MKFS_CMD="${MKFS_CMD} -L ${FS_LABEL/ /}"
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
	unset IFS
	logdebug "Filesystems initialized."
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
	unset IFS # Make sure IFS is the default filed separator.
	cat /tmp/fstab.image |sed -e 's/#.*//' -e '/^$/d' | sort -k2,2 |\
		while read M_DEV M_MP M_FS M_OPTS M_DUMP M_PASS
		do
			# If mountpoint is a PATH, AND filesystem is not virtual, create the path and mount filesystem to sysroot.
			if test "${M_MP:0:1}" = "/" -a -n "`echo "ext2|ext3|ext4|xfs|jfs|reiserfs|btrfs|ntfs|msdos|vfat|fat|fat32|fat16" |grep \"${M_FS}\"`"
			then
				loginfo "Creating mountpoint for ${M_MP}"
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


################################################################################
#
# _get_sectors_aligment <device name> (sda, sdb, ...)
#	This function return the sectors count for optimal aligment.
#	Each new partitions should start at a multiple of this value.
#	from: https://rainbow.chard.org/2013/01/30/how-to-align-partitions-for-best-performance-using-parted/
#	Part start at (optimal_io_size + aligment_offset)/physical_block_size
#
#	A conservative mesure is to start at 2048s (1MiB) multiples:
#	https://askubuntu.com/questions/201164/proper-alignment-of-partitions-on-an-advanced-format-hdd-using-parted
#
################################################################################
_get_sectors_aligment() {
	if test ! -d /sys/block/*$1
	then
		logwarn "/sys/block/*$1 does not exists. Assuming sector aligment: 2048s"
		echo 2048
		return
	fi

	OPTIM_IO_SIZE=$(cat /sys/block/*$1/queue/optimal_io_size)
	if test -z "${OPTIM_IO_SIZE/0/}"
	then
		logwarn "/sys/block/*$1/queue/optimal_io_size not supported. Assuming sector aligment: 2048s"
		echo 2048
		return
	fi

	ALIGMNT_OFFSET=$(cat /sys/block/*$1/alignment_offset)
	test -z "$ALIGMNT_OFFSET" && ALIGMNT_OFFSET=0

	PHY_BLOCK_SIZE=$(cat /sys/block/*$1/queue/physical_block_size)
	test -z "${PHY_BLOCK_SIZE/0/}" && PHY_BLOCK_SIZE=512 # Use 512 is value empty or zero.

	ALIGMNT=$(dc <<< "$OPTIM_IO_SIZE $ALIGMNT_OFFSET + $PHY_BLOCK_SIZE / p")

	if test "${ALIGMNT}" -lt 2048
	then
		logwarn "Aligment [$ALIGMNT] is lower than 2048s".
		logwarn "Taking conservative mesure by using 2048s boundaries aligments".
		ALIGMNT=2048
	fi
	echo ${ALIGMNT}
}


################################################################################
# convert2sectors()
# $1: disk device (e.g. sda)
# $2: partition requested size (float or integer)
# $3: unit of measurement
# output: number of sectors (float; will be cut later)
################################################################################
#
# DISC_SIZE: /sys/block/<device>/size
# BLOC_SIZE: /sys/block/<device>/queue/logical_block_size
#
#
convert2sectors() {
	# local LC_NUMERIC="en_US.UTF-8" # Make sure we use "." for decimal separator.

	test ! -f /sys/block/*$1/size && shellout "convert2sectors: device [$1] does not exists."
	if test -z "${2/0/}" # 0 means all space available. Keep it unchanged.
	then
		echo 0
		return
	fi
	test -z $(sed -E 's/^[0-9]+(\.[0-9]+)*//g' <<< $2) || shellout "convert2sectors: size [$2] for partition $1 is not numeric."
	DISK_SIZE=$(cat /sys/block/*$1/size) # percentage computation
	BLOCK_SIZE=$(cat /sys/block/*$1/queue/logical_block_size)
	test -z "${BLOCK_SIZE}" && logwarn "Failed to get $1 block size. Assuming 512 bytes." && BLOCK_SIZE=512
	test ${BLOCK_SIZE} -eq 0 && logwarn "$1 reports block size of 0. Assuming 512 bytes." && BLOCK_SIZE=512

	case $3 in
		"TB")
			dc <<< "$2 1000 * 1000 * 1000 * 1000 * ${BLOCK_SIZE} / n"
			;;
		"TiB")
			dc <<< "$2 1024 * 1024 * 1024 * 1024 * ${BLOCK_SIZE} / n"
			;;
		"GB")
			dc <<< "$2 1000 * 1000 * 1000 * ${BLOCK_SIZE} / n"
			;;
		"GiB")
			dc <<< "$2 1024 * 1024 * 1024 * ${BLOCK_SIZE} / n"
			;;
		"MB")
			dc <<< "$2 1000 * 1000 * ${BLOCK_SIZE} / n"
			;;
		"MiB")
			dc <<< "$2 1024 * 1024 * ${BLOCK_SIZE} / n"
			;;
		"kB")
			dc <<< "$2 1000 * ${BLOCK_SIZE} / n"
			;;
		"KiB")
			dc <<< "$2 1024 * ${BLOCK_SIZE} / n"
			;;
		"B")
			dc <<< "$2 ${BLOCK_SIZE} / n"
			;;
		"s")
			echo $2
			;;
		"%")
			dc <<< "${DISK_SIZE} $2 * 100 / n"
			;;
		*)
			shellout "convert2sectors: unknown unit [$3]. (Valid units: TB, TiB, GB, GiB, MB, MiB, kB, KiB, B, s, %)"
			;;
	esac
}

