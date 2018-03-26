#!/bin/sh
#
# "SystemImager" 
#
#  Copyright (C) 1999-2017 Brian Elliott Finley <brian@thefinleys.com>
#
#  $Id$
#  vi: set filetype=sh et ts=4:
#
#  Code mainly reworked or written by Olivier LAHAYE.
#
#  Others who have contributed to this code:
#   Charles C. Bennett, Jr. <ccb@acm.org>
#   Sean Dague <japh@us.ibm.com>
#   Dann Frazier <dannf@dannf.org>
#   Curtis Zinzilieta <czinzilieta@valinux.com>
#
# this file hosts functions related to dracut-initqueue logic.
# It is also used by imaging script.

################################################################################
#
#   Variables
#
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/tmp
export PATH
LD_LIBRARY_PATH=/lib
SCRIPTS=scripts
SCRIPTS_DIR=/scripts
TORRENTS=torrents
TORRENTS_DIR=/torrents
FLAMETHROWER_DIRECTORY_DIR=/var/lib/systemimager/flamethrower
BOEL_BINARIES_DIR=/tmp/boel_binaries
#CMDLINE_VARIABLES=/tmp/cmdline.txt
VERSION="SYSTEMIMAGER_VERSION_STRING"
FLAVOR="SYSTEMIMAGER_FLAVOR_STRING"
#
################################################################################

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

# On old distros like CentOS-6, the shell interpreter is "dash" (not "bash")
# it lacks the "disown command" we need to avoid ugly message when background
# shell processes get killed. In dash, we just ignore this lack.
type disown > /dev/null 2>&1 || alias disown="echo > /dev/null"

# Make sure we have a TERM variable set.
test -z "${TERM}" -o "${TERM}" = "dumb" && TERM=linux

# Some usefull values
COLORS=`tput -T${TERM} colors`
if test "0${COLORS}" -gt 1
then
	FG_GREEN=`tput -T${TERM} setaf 2`
	FG_RED=`tput -T${TERM} setaf 1`
	FG_WHITE=`tput -T${TERM} setaf 7`
	FG_AMBER=`tput -T${TERM} setaf 3`
	FG_BLUE=`tput -T${TERM} setaf 4`
	FG_CYAN=`tput -T${TERM} setaf 6`
	BG_BLACK=`tput -T${TERM} setab 0`
	BG_RED=`tput -T${TERM} setab 1`
	BG_BLUE=`tput -T${TERM} setab 4`
fi

################################################################################
#
#   Output log Subroutines
#
################################################################################
#
#  logerror, logwarn, loginfo, logaction, lognotice
#  - helper functions to log a message depending of its nature.
#    output is done as text and gfx if plymouth is active.
#
#  logdetail, logmsg
#  - helper functions to log a message depending of its nature.
#    output is done as text ONLY.
#

# Log an error.
logerror() {
	logmessage err "${BG_RED}  ERROR:${BG_BLACK} $@"
	plymouth --ping && plymouth update --status="mesg:E:$@" > /dev/null 2>&1
}

# Log a warning
logwarn() {
	logmessage warning "${FG_RED}warning:${FG_WHITE} $@"
	plymouth --ping && plymouth update --status="mesg:W:$@" > /dev/null 2>&1
}

# Log a simple information
loginfo() {
	logmessage info "${FG_GREEN}    info:${FG_WHITE} $@"
	plymouth --ping && plymouth update --status="mesg:I:$@" > /dev/null 2>&1
}

# Log a detailed information
logdetail() {
	logmessage info "${FG_GREEN}    info:${FG_WHITE} $@" > /dev/null 2>&1
}

# Log an action being done to client
logaction() {
	logmessage notice "${FG_AMBER}  action:${FG_WHITE} $@"
	plymouth --ping && plymouth update --status="mesg:A:$@" > /dev/null 2>&1
}

# Log debug / system stuffs
logdebug() {
	[ "${DEBUG}" != "y" ] && return # Debug output not enabled => ignore
	logmessage debug "${FG_BLUE}   debug:${FG_WHITE} $@"
	if [ "${SIS_SYSMSG_ENABLED}" != "y" ]
	then
		sis_enable_system_msg
		export SIS_SYSMSG_ENABLED="y" # In debug mode, we also display system messages.
		write_variables
		logdebug "System messages displayed in plymouth enabled."
	fi
	plymouth --ping && plymouth update --status="mesg:D:$@" > /dev/null 2>&1
}

# Log things that dont fit above cathegories
lognotice() {
	logmessage notice "${FG_BLUE}  notice:${FG_WHITE} $@"
	plymouth --ping && plymouth update --status="mesg:N:$@" > /dev/null 2>&1
}

# Compatibility function with older scripts.
logmsg() {
	logmessage notice "${FG_CYAN} message:${FG_WHITE} $@"
	# Old messages => No plymouth.
}

#
# logmessage <message>
# Usage: log a message to console ( + syslog $USELOGGER is set )

logmessage() {
    # log to temporary file (which will go away when we reboot)
    # this is good for envs that have bad consoles
    LOG_LEVEL=$1
    shift
    local FILE=/tmp/si_monitor.log
    echo "$*" >> $FILE
    test -w /dev/console && echo "$*" > /dev/console

    # if syslog is running, log to it.  In order to avoid hangs we have to 
    # add the "sis: " part in case $@ is ""
    if [ ! -z "$USELOGGER" ] ;
        then logger -p user.${LOG_LEVEL} "sis: $*"
    fi
}

# Read varaibles.txt if present.
test -f /tmp/variables.txt && logdebug "Reading /tmp/variables.txt" && . /tmp/variables.txt

# If protocol is set, we load its dedicated API.
test -n "${DL_PROTOCOL}" && test -r /lib/systemimager-xmit-${DL_PROTOCOL}.sh && . /lib/systemimager-xmit-${DL_PROTOCOL}.sh

################################################################################
#
# Tells systemimager to display debug message
# This enables plymouth system messages as well
# Default: don't display debug messages
sis_enable_debug_msg() {
    DEBUG="y"
    write_variables
    logdebug "Debug messages enabled."
}

################################################################################
#
# Tells plymouth theme to display system messages (not only SystemImager ones))
# (sets parameter "sys" to Y)
# Default: sys=N
sis_enable_system_msg() {
	plymouth --ping && plymouth update --status="conf:sys:Y"
}

################################################################################
#
# Convert value to MB
# $1: value
# $2: value unit (MB, MiB, GB, GiB, B)
# output: value in MB
convert2MB() {
	case $2 in
		B)
			echo $(( $1 / 1000000 ))
			;;
		KB)
			echo $(( $1 / 1000 )) # should be ($1+500)/1000 for propper rounding. Do we need this?
			;;
		MB)
			echo $1
			;;
		GB)
			echo $(( $1 * 1000 ))
			;;
		TB)
			echo $(( $1 * 1000000 ))
			;;
		KiB|MiB|GiB|TiB)
			# BUG: TODO
			shellout "$2 unit not yet supported"
			;;
		*)
			shellout "Unknown unit $2"
	esac
}

################################################################################
#
# sis_dialog_box type "message"
# type can be:
#      - "yes": => Green checkmark
#      - "no":  => Red cross
#      - "zzz": => wait gear wheel
#      - "off": => Close the doalog box
sis_dialog_box() {
	TYPE=$1
	[ ${TYPE} == "no" ] && TYPE=" no" # TYPE must be 3 letters.
	shift
	case "${TYPE}" in
		"yes"|" no"|"zzz")
			if test -z "$1" # $1 is the 1st word of the message.
			then
				logwarn "sis_dialog_box(): empty message"
				return # Ignore empty messages
			fi
			;;
		"off")
			;;
		*)
			logwarn "sis_dialog_box(): unknown dialog type: [${TYPE}]"
			;;
	esac
	plymouth --ping && plymouth update --status="dlgb:${TYPE}:$*"

}

sis_plymouth_wait_keypress() {
	plymouth --ping && lognotice "Press any key to continue...." && plymouth watch-keystroke
}

################################################################################
#
# sis_update_step step val max
# - step: step name
#         where step is one of:
#         - init (small letters)
#         - part (small letters)
#         - frmt (small letters)
#         - prei (small letters) (VAL=script being run; MAX=number of scripts to run)
#         - imag (small letters) (VAL=percent progress; MAX=100)
#         - boot (small letters)
#         - post (small letters) (VAL=script being run; MAX=number of scripts to run)#
# - val: completion (0-max) (integer part must be 3 digits maximum. Floats are rounded)
# - max: max value | 0 (0 = do not display bar) (integer must be 3 digits maximum. No float)
#  Note: val and max can be ommited. Default to "000".
#
# Tells plymouth which step icon to highlight and if the percentage is defined,
#               what the progressbar should display. (max="000" hides the progress bar)
sis_update_step() {
    if test -n "`echo $1 |sed -E 's/init|part|frmt|prei|imag|boot|post//g'`"
    then
        logwarn "sis_update_step called with invalid step"
	return
    fi
    # convert val from float to integer if needed
    VAL=`LC_NUMERIC="C" printf "%3.0f" "$2"`
    # set output format to 3 digits
    VAL=`LC_NUMERIC="C" printf "%.3d" "${VAL}"`
    MAX=`LC_NUMERIC="C" printf "%.3d" "$3"`

    if test \( ${#VAL} -gt 3 \) -o \( ${#MAX} -gt 3 \)
    then
	logwarn "sis_update_step called with invalid values: ${VAL}/${MAX} (> 3 digits)"
	return
    fi

    plymouth --ping && plymouth update --status="$1:${VAL}:${MAX}"
    return 0 # Hide plymouth return code. If plymouth is not active of fails, not dramatic.
}

#
################################################################################
#
#  adjust_arch
#
#  based on info in /proc adjust the ARCH variable.  This needs to run
#  after proc is mounted.
#  TODO: Is it still needed?
#
adjust_arch() {
    if [ "ppc64" = "$ARCH" ] ; then
        # This takes a little bit of futzing with due to all the PPC platforms that exist.
        if [ -d /proc/iSeries ] ; then
            ARCH=ppc64-iSeries
            loginfo "Detected ppc64 is really an iSeries partition..."
        fi
        if grep -qs PS3 /proc/cpuinfo; then
            ARCH=ppc64-ps3
            loginfo "Detected ppc64 in a PS3..."
        fi
    fi
    loginfo "Adjusting arch if needed ARCH=$ARCH"
    write_variables # Save ARCH
}
#
################################################################################
#
#  write_variables
#
# Usage: write_variables
write_variables() {
    logdebug "Saving variables to /tmp/variables.txt"

    touch /tmp/variables.txt
    mv -f /tmp/variables.txt /tmp/variables.txt~

cat > /tmp/variables.txt <<EOF || shellout "Failed to write /tmp/variables.txt"
HOSTNAME="$HOSTNAME"
DOMAINNAME="$DOMAINNAME"

DEVICE="$DEVICE"
IPADDR="$IPADDR"
NETMASK="$NETMASK"
NETWORK="$NETWORK"
BROADCAST="$BROADCAST"

GATEWAY="$GATEWAY"
GATEWAYDEV="$GATEWAYDEV"

IMAGESERVER="$IMAGESERVER"			# rd.sis.image-server
IMAGENAME="$IMAGENAME"
SCRIPTNAME="$SCRIPTNAME"
GROUPNAMES="$GROUPNAMES"			# /scripts/cluster.txt
GROUP_OVERRIDES="$GROUP_OVERRIDES"
SIS_CONFIG="$SIS_CONFIG"			# rd.sis.config
DISKS_LAYOUT="$DISKS_LAYOUT"			# rd.sis.disks-layout

DL_PROTOCOL="$DL_PROTOCOL"			# rd.sis.dl-protocol

LOG_SERVER="$LOG_SERVER"
LOG_SERVER_PORT="$LOG_SERVER_PORT"		# rd.sis.log-server-port
USELOGGER="$USELOGGER"

IP_ASSIGNMENT_METHOD="$IP_ASSIGNMENT_METHOD"
TMPFS_STAGING="$TMPFS_STAGING"			# rd.sis.tmpfs-staging
STAGING_DIR="$STAGING_DIR"		
IMAGESIZE="$IMAGESIZE"
DISKS=( ${DISKS[@]} )

ARCH="$ARCH"
SSH="$SSH"
SSHD="$SSHD"
SSH_USER="$SSH_USER"
SSH_DOWNLOAD_URL="$SSH_DOWNLOAD_URL"		# rd.sis.ssh-download-url"

FLAMETHROWER_DIRECTORY_PORTBASE="$FLAMETHROWER_DIRECTORY_PORTBASE" # rd.sis.flamethrower-directory-portbase

MONITOR_SERVER="$MONITOR_SERVER"		# rd.sis.monitor-server
MONITOR_PORT="$MONITOR_PORT"			# rd.sis.monitor-port
MONITOR_CONSOLE="$MONITOR_CONSOLE"		# rd.sis.monitor-console
SKIP_LOCAL_CFG="$SKIP_LOCAL_CFG"		# rd.sis.skip-local-cfg

BITTORRENT="$BITTORRENT"
BITTORRENT_STAGING="$BITTORRENT_STAGING"
BITTORRENT_POLLING_TIME="$BITTORRENT_POLLING_TIME"
BITTORRENT_SEED_WAIT="$BITTORRENT_SEED_WAIT"
BITTORRENT_UPLOAD_MIN="$BITTORRENT_UPLOAD_MIN"

SEL_RELABEL="$SEL_RELABEL"			# rd.sis.selinux-relabel

SIS_POST_ACTION="$SIS_POST_ACTION"		# rd.sis.post-action

DEBUG="${DEBUG}"					# rd.sis.debug
SIS_SYSMSG_ENABLED="$SIS_SYSMSG_ENABLED"
export TERM="${TERM}"

EOF

rm -f /tmp/variables.txt~
}

################################################################################
#
# update_dracut_root_infos(): will save root= in /dracut-state.sh or /tmp/root.info
# depending on dracut version (systemd based or not)
update_dracut_root_infos() {
	if test -f /dracut-state.sh
	then
		loginfo "Updating /dracut-state.sh with new root=$root informations"
		export -p > /dracut-state.sh
	elif test -f /tmp/root.info
	then
		loginfo "Updating /tmp/root.info with new root=$root informations"
		{
		    echo "root='$root'"
		    echo "rflags='$rflags'"
		    echo "fstype='$fstype'"
		    echo "netroot='$netroot'"
		    echo "NEWROOT='$NEWROOT'"
		} > /tmp/root.info
	else
		logwarn "Can't save root= informations."
		return 1
	fi
	# Now that root= is saved at the propper place, we need to remove the
	# /etc/conf.d/systemimager.conf file that set dummy values.
	# This file is sourced at the beginning of each dracut hook
	# Thus it is sourced at the mount stage which we don't want anymore
	# as we have now correct values stored in /dracut-state.sh (or /tmp/root.info)
	# and we don't want them to be overridden by dummy values.
	test -f /etc/conf.d/systemimager.conf && rm -f /etc/conf.d/systemimager.conf && logdebug "Removed dummy root infos file /etc/conf.d/systemimager.conf"
	test -f /etc/cmdline.d/systemimager.conf && sed -i -e '/root/d' /etc/cmdline.d/systemimager.conf && logdebug "Removed dummy root infos from /etc/cmdline.d/systemimager.conf so getarg root won't return none"

	# On systemd systems, the root is mounted by systemd.
	# the sysroot.mount entry is created by /usr/lib/systemd/system-generators/dracut-rootfs-generator
	# This scrits uses getarg() for /lib/dracut-lib.sh
	# We need to put information in cmdline.d/systemimager-rootfs-infos.conf
	cat > /etc/cmdline.d/systemimager-rootfs-infos.conf <<EOF
root=${root#block:}
EOF
}

################################################################################
#
#   Description:
#   return the free space in bytes in directory (filesystems) given as argument
#
#   Usage: get_free_space /sysroot
#   BUG: doesn't take into account sub filesystems.
#        example: /sysrout + /sysroot/boot => only returns top filesystem free space.
#                 if /sysroot/boot is too small, problem will not raise untile parts of the image is written to /boot
#        => When using this function, error should only issue a warning, not a shellout().
#
get_free_space() {
	df $1 2>/dev/null | sed '1d' | sed 's/[[:space:]]\+/ /g' | cut -d' ' -f4 | sed -ne '$p'
}
#
################################################################################
#
#   Description:
#   watches the tmpfs filesystem (/) and gives warnings and/or does a shellout
#
#   Usage: tmpfs_watcher
#
tmpfs_watcher() {

    loginfo "Starting tmpfs watcher..."

    # Note: Transfer to staging area can fail if tmpfs runs out of inodes.
    {
        while :; do
            DF=`df -k / | egrep ' /$' | sed -e 's/  */ /g' -e 's/.*[0-9] //' -e 's/%.*//'`
            [ $DF -ge 95 ] && logwarn "WARNING: Your tmpfs filesystem is ${DF}% full!"
            [ $DF -ge 99 ] && logwarn "         Search the FAQ for tmpfs to learn about sizing options."
            [ $DF -ge 99 ] && shellout "tmpfs filesystem is ${DF}% full!"
            sleep 1
        done
        unset DF
    }&

    TMPFS_WATCHER_PID=$!
    disown # Remove this task from shell job list so no debug output will be written when killed.
    logdetail "tmpfs watcher PID: $TMPFS_WATCHER_PID"
    echo $TMPFS_WATCHER_PID > /run/systemimager/tmpfs_watcher.pid
}
#
################################################################################
#
#   Description:
#   Exit with the message stored in /etc/issue.
#
#   Usage: sis_postimaging reboot|halt|poweroff|shell|emergency|kexec
#   - reboot will reboot the host
#   - halt will halt the host without powering it off
#   - shell will leave the host whith an interactive shell (for debugging purposes)
#   - kexec will directly load the imaged kernel and boot the host without going thru
#     the bios enumeration (very usefull sometimes to avoid counting 2TB of RAM)
#
sis_postimaging() {
	ACTION=$1

	# Fix /etc/issue and /etc/motd with background coloring (at this point we have a valid TERM)
	# this cannot be done in initrd itself as it depends on TERM (which may depend of si.term)
	sed -i -e "1i${BG_BLUE}" -e "\$a${BG_BLACK}" /etc/motd
	sed -i -e "1i${BG_RED}" -e "\$a${BG_BLACK}" /etc/issue

	# directboot requires few things:
	# root= must be set to block:/dev/the/correct/root/device
	# /etc/fstab.empty must exists and /etc/fstab must be removed
	# rflags must be set to ro
	# then we return 0 (not exit!!) si dracut mainloop can continue. 
	if test "${ACTION}" = "directboot"
	then
		# Read root= updated values
		if test -f /dracut-state.sh; then
			loginfo "Reading root= updated values from /dracut-state.sh"
			. /dracut-state.sh 2> /dev/null
		elif test -f /tmp/root.info; then # Old dracut (CentOS-6 / non systemd)
			loginfo "Reading root= updated values from /tmp/root.info"
			. /tmp/root.info 2> /dev/null
		else
			logwarn "No root= info available (/dracut-state.sh or /tmp/root.info missing)"
		fi
		loginfo "Using root=$root"

		# Make sure $root points to a block device at least.
		test -b "${root#block:}" || shellout "\$root is not a block device! [root=${root}]"
		# Make sure $root points to correct root in ou temporary /etc/fstab
		test -n "`grep -E \"^${root#block:}\\s+/sysroot[/]{0,1}\\s+.*$\" /etc/fstab`" || shellout "\$root not used for / in our fstab: [root=${root}]"
		touch /etc/fstab.emtpy # make sure it exists
		rm -f /etc/fstab       # cleanup our stuff!
		# Make sure installed modules match ou kernel version.
		RUNNING_KERNEL_VER=`uname -r`
		if test -z "`echo ${IMAGED_MODULES}|grep ${RUNNING_KERNEL_VER}`"
		then
			logerror "Can't boot directly."
			logerror "Running kernel [${RUNNING_KERNEL_VER}] has no modules on imaged system."
			logerror "Installed modules: ${IMAGED_MODULES}"
			logwarn  "Rebooting instead."
			ACTION="reboot"
		else
			loginfo "Imaged system has matching modules available."
			loginfo "Continuing as normal boot using kernel [${RUNNING_KERNEL_VER}]."
			return 0
		fi
	fi

	# If kexec action is chosen, we load the new kernel.
	# OL: BUG: at this point, /sysroot is unmounted.....
	if test "$ACTION" = "kexec"
	then
	    # OL: Not tested; need many improvement!
	    KERNEL=/sysroot/boot/vmlinuz* # Need to get the real kernel: no place for guess here
	    INITRD=/sysroot/boot/init*img # Same as above (must match version).
	    ROOTFSDEV=`mount | grep sysroot | cut -d' ' -f3` # Same as above. We have the info elsewhere.
	    if test -f /sysroot/boot/vmlinuz* && test -f /sysroot/boot/init*img && test -n "$ROOTFSDEV"
	    then
	        kexec -l $KERNEL --append=root=$ROOTDEV --initrd=$INITRD
	    else
	        ACTION="reboot" # Force reboot going thru bios+grub as we are unable to boot directyl
	    fi
	fi

	if [ -n "$DRACUT_SYSTEMD" ]
	then
	    case "$ACTION" in
	        reboot|poweroff|halt|kexec)
		    sis_dialog_box yes "Installation successfull."
		    sis_dialog_box yes " "
		    sis_dialog_box yes "Now going to ${ACTION}"
		    sleep 5
	            systemctl --no-block --force $ACTION
	            logwarn "$ACTION failed!"
	            ;;
	        shell)
		    sis_dialog_box yes "Installation successfull."
		    sis_dialog_box yes " "
		    sis_dialog_box yes "Press any key to get a debug shell."
		    sis_plymouth_wait_keypress
		    ln -sf /etc/motd /tmp/message.txt
		    ;;    
	        emergency)
		    sis_dialog_box no "INSTALLATION FAILED!"
		    sis_dialog_box no " "
		    sis_dialog_box no "Can not proceed!  (Scottish accent"
		    sis_dialog_box no "    -- think Groundskeeper Willie)"
		    sis_dialog_box no " "
		    sis_dialog_box no "Press any key to get a debug shell."
		    sis_plymouth_wait_keypress
		    ln -sf /etc/issue /tmp/message.txt
		    ;;
	        *)
		    sis_dialog_box yes "sis_postimaging called with invalid"
		    sis_dialog_box yes "argument '$ACTION'. Rebooting!"
		    sis_dialog_box yes " "
	            logwarn "sis_postimaging called with invalid argument '$ACTION'. Rebooting!"
		    sleep 10 # leave time to read.
	            systemctl --no-block --force reboot
	            ;;
	    esac
	    interactive_shell
	    sis_postimaging poweroff # Upon exit (from shell), we poweroff.
	else
	    case "$ACTION" in
	        reboot|poweroff|halt)
		    sis_dialog_box yes "Installation successfull."
		    sis_dialog_box yes " "
		    sis_dialog_box yes "Now going to ${ACTION}"
		    sleep 5
	            $ACTION -f -d -n
	            logwarn "$ACTION failed!"
	            ;;
	        kexec)
		    sis_dialog_box yes "Installation successfull."
		    sis_dialog_box yes " "
		    sis_dialog_box yes "Now going to ${ACTION}"
		    sleep 5
	            kexec -e # Will load kernel+initrd.img specified by above kexec -l ...
	            logwarn "$ACTION failed!"
	            reboot -f -d -n # If kexec fails, reboot using bios as failover.
	            ;;
	        shell)
		    sis_dialog_box yes "Installation successfull."
		    sis_dialog_box yes " "
		    sis_dialog_box yes "Press any key to get a debug shell."
		    sis_plymouth_wait_keypress
	            ln -sf /etc/motd /tmp/message.txt
		    ;;
		emergency)
		    sis_dialog_box no "INSTALLATION FAILED!"
		    sis_dialog_box no " "
		    sis_dialog_box no "Can not proceed!  (Scottish accent"
		    sis_dialog_box no "    -- think Groundskeeper Willie)"
		    sis_dialog_box no " "
		    sis_dialog_box no "Press any key to get a debug shell."
		    sis_plymouth_wait_keypress
		    ln -sf /etc/issue /tmp/message.txt
		    ;;
	        *)
		    sis_dialog_box yes "sis_postimaging called with invalid"
		    sis_dialog_box yes "argument '$ACTION'. Rebooting!"
		    sis_dialog_box yes " "
	            logwarn "sis_postimaging called with invalid argument '$ACTION'. Rebooting!"
	            reboot -f -d -n
	            ;;
	    esac
	    interactive_shell
	    sis_postimaging poweroff # Upon exit (from shell), we poweroff.
	fi
}

#
################################################################################
#
#   Description:
#   Exit with the message stored in /etc/issue.
#
#   Usage: $COMMAND
#
interactive_shell() {
    # 1st, we need to make sure HOSTNAME has a value. In some circumstances,
    # We are called while variables.txt have been read long ago.
    # e.g.: systemimager-wait-imaging.sh loads systemimager-lib.sh early which
    # in turns has loaded /tmp/variables.txt and this was done before HOSTNAME=
    # was set in network init.
    [ -z "${HOSTNAME}" ] && HOSTNAME=`hostname`

    # Then, if the /tmp/message.txt exists (it should always be the case)
    # Update /.profile so the message is displayed when shell is run.
    if test -f /tmp/message.txt
    then
	    sed -i -e "s/##HOSTNAME##/${HOSTNAME}/g" /etc/motd /etc/issue
	    cat >> /.profile <<EOF
cat /tmp/message.txt
tput setab 0
tput setaf 7
PS1="${FG_GREEN}SIS:\${PWD}#${FG_WHITE} "
alias reboot="reboot -f"
alias shutdown="shutdown -f"
EOF
    fi
    if type emergency_shell >/dev/null 2>&1
    then
        emergency_shell -n "SIS"
    else
        type plymouth >/dev/null 2>&1 && plymouth --hide-splash
        echo "exec 0<>/dev/console 1<>/dev/console 2<>/dev/console" >> /.profile
        sh -i -l
    fi
}
#
################################################################################
#
#   Description:
#   Exit with the message stored in /etc/issue.
#
#   Usage: $COMMAND || shellout "Error message"
#
shellout() {

    # Display error code if relevant.
    LAST_ERR=$?

    test -s /run/systemimager/report_task.pid && echo > /dev/console # if report task is running, go to next line.
    # Print error message if any.
    test -n "$1" && logerror "$@"

    test "$LAST_ERR" -ne 0 && logerror "Last command exited with $LAST_ERR"

    logerror "Installation failed!                                             "
    logerror "Can not proceed!  (Scottish accent -- think Groundskeeper Willie)"

    # Kill the text progress bar ASAP to avoid it to reappear below itself
    # In therory, race condition may exists between the "go to next line" above and now.
    if [ ! -z "$MONITOR_SERVER" ]; then
    	logerror "Installation failed!! Stopping report task."
        stop_report_task -1
    fi

    if test -s /run/systemimager/tmpfs_watcher.pid; then
	$TMPFS_WATCHER_PID=`cat /run/systemimager/tmpfs_watcher.pid`
        # BUG: make sure it's a PID
        if [ -n "$TMPFS_WATCHER_PID" ]; then
            logwarn "Killing off tmpfs watcher [pid:$TMPFS_WATCHER_PID]."
            kill -9 $TMPFS_WATCHER_PID  >/dev/null 2>/dev/null
            rm -f /run/systemimager/tmpfs_watcher.pid
        fi
    fi
    logwarn "Killing off any udp-receiver and rsync processes."
    killall -9 udp-receiver rsync  >/dev/null 2>/dev/null
    write_variables
    if [ ! -z "$USELOGGER" ] ;
        then cat /etc/issue | logger
    fi
   # Need to trigger emergency shell
    echo emergency > /tmp/SIS_action
    sis_postimaging emergency # Set the correct link for /tmp/message.txt and call interactive_shell
}
#
################################################################################
#
# Description: remove duplicated elements from a list, preserving the order.
#
unique() {
    ret=
    for i in $*; do
        flag=0
        for j in $ret; do
            [ "$i" = "$j" ] && flag=1 && break
        done
        [ $flag -eq 0 ] && ret="$ret $i"
    done
    echo $ret
    unset i j flag ret
}
#
################################################################################
#
# Description: reverse a list
#
reverse() {
    ret=
    for i in $*; do
        ret="$i $ret"
    done
    echo $ret
    unset i
}

################################################################################
#
# Description: remove leading and trailing spaces from a shell variable.
# Source: https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable#answer-3352015
#
trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

#
################################################################################
#
# Usage: get_flamethrower_directory
#
get_flamethrower_directory() {
    loginfo "Using multicast..."
    loginfo "get_flamethrower_directory"

    MODULE_NAME=flamethrower_directory
    DIR=${FLAMETHROWER_DIRECTORY_DIR}
    RETRY=7
    PORTBASE=9000
    flamethrower_client
}
#
################################################################################
#
# Usage: 
#
#   MODULE_NAME=my_module   # Required
#   DIR=/my/destination/dir # Required
#   [RETRY=7]               # Optional
#   [PORTBASE=9000]         # Required if a sourceable file called $MODULE_NAME
#                           #   doesn't exist
#   [FLAMETHROWER_TARPIPE]  # If not empty, untar received data directly,
#                           # without storing it to a temporary file
#
#   flamethrower_client
#
flamethrower_client() {

    if [ ! -z $FLAMETHROWER_TARPIPE ]; then
	FLAMETHROWER_TARPIPE=tarpipe
    fi
    logmsg
    logmsg "flamethrower_client(${MODULE_NAME}) $FLAMETHROWER_TARPIPE "
    logmsg ---------------------------------------------------------------------

    # validate
    if [ -z $PORTBASE ]; then
        if [ -f ${FLAMETHROWER_DIRECTORY_DIR}/${MODULE_NAME} ]; then
	    . ${FLAMETHROWER_DIRECTORY_DIR}/${MODULE_NAME}
	else
	    logmsg WARNING WARNING WARNING WARNING WARNING
            logmsg You must either set PORTBASE, or have a sourceable file called
            logmsg ${FLAMETHROWER_DIRECTORY_DIR}/MODULE_NAME
	    # allow for now to continue until overrides get their modules
	    return
            #shellout
        fi
    fi
    if [ -z $DIR ]; then
        logerror "Must set DIR !!!"
	shellout
    else
        mkdir -p $DIR
    fi

    # build command
    UDP_RECEIVER_OPTIONS="--interface ${DEVICE} --portbase $PORTBASE --nokbd"
    if [ ! -z $TTL ]; then
        UDP_RECEIVER_OPTIONS="$UDP_RECEIVER_OPTIONS --ttl $TTL"
    fi
    if [ "$NOSYNC" = "on" ]; then
        UDP_RECEIVER_OPTIONS="$UDP_RECEIVER_OPTIONS --nosync"
    fi
    if [ "$ASYNC" = "on" ]; then
        UDP_RECEIVER_OPTIONS="$UDP_RECEIVER_OPTIONS --async"
    fi
    if [ ! -z $MCAST_ALL_ADDR ]; then
        UDP_RECEIVER_OPTIONS="$UDP_RECEIVER_OPTIONS --mcast-all-addr $MCAST_ALL_ADDR"
    fi

    # Which tar opts should we use?  If our tar has --overwrite capability, use it.
    #   Summary: busybox tar doesn't (boel_binaries and prior).
    #            Debian patched gnu tar does (image and on).
    #            We want this option enabled for the image to ensure proper directory
    #            permissions. -BEF-
    tar --help 2>&1 | grep -q overwrite && TAR_OPTS='--overwrite -xp' || TAR_OPTS='-x'

    # set vars
    [ -z $RETRY ] && RETRY=0
    COUNT=0
    FLAMETHROWER_CLIENT_SLEEP=3

    # it's the new new style (loop)
    SUCCESS="Not Yet"
    until [ "$SUCCESS" = "yes" ]
    do
        # receive cast
        #   example udp-receiver command:
        #   udp-receiver --interface lo --portbase 9002 --nokbd --nosync --file /tmp/multicast.tar

        if [ ! -z $FLAMETHROWER_TARPIPE ]; then
	    TAR_OPTS="$TAR_OPTS -f -"
	    logmsg "udp-receiver $UDP_RECEIVER_OPTIONS | tar $TAR_OPTS -C $DIR"
	    udp-receiver $UDP_RECEIVER_OPTIONS | tar $TAR_OPTS -C $DIR
	    TAR_EXIT_STATUS=$?
	    UDP_RECEIVER_EXIT_STATUS=0
	else
	    logmsg udp-receiver $UDP_RECEIVER_OPTIONS --file /tmp/multicast.tar
	    udp-receiver $UDP_RECEIVER_OPTIONS --file /tmp/multicast.tar
	    UDP_RECEIVER_EXIT_STATUS=$?

            # untar it
	    if [ "$UDP_RECEIVER_EXIT_STATUS" = "0" ]; then
		logmsg tar ${TAR_OPTS} -f /tmp/multicast.tar -C ${DIR}
		tar ${TAR_OPTS} -f /tmp/multicast.tar -C ${DIR}
		TAR_EXIT_STATUS=$?
	    fi
            # discard used tarball like an old sock (recommended by: Ramon Bastiaans <bastiaans@sara.nl>)
	    rm -f /tmp/multicast.tar
	fi

        # did everything work properly
        if [ $UDP_RECEIVER_EXIT_STATUS -eq 0 ] && [ $TAR_EXIT_STATUS -eq 0 ]; then
            SUCCESS=yes
        else
            if [ $COUNT -lt $RETRY ]; then
                COUNT=$(( $COUNT + 1 ))
                logmsg "flamethrower_client: Proceeding with retry $COUNT of $RETRY"
            else
                logmsg
                logmsg "flamethrower_client: FATAL: Initial attempt and $RETRY retries failed!"
                shellout
            fi
        fi

        # sleep apnea
        sleep_loop $FLAMETHROWER_CLIENT_SLEEP
    done

    # done
    logmsg 'finished!'
    logmsg 

    # Unset vars, so next module (which may not have them set) won't use then unintentially
    unset TTL
    unset NOSYNC
    unset ASYNC
    unset MCAST_ALL_ADDR
    unset RETRY
    unset COUNT
    unset DIR
    unset PORTBASE
    unset UDP_RECEIVER_EXIT_STATUS
    unset UDP_RECEIVER_OPTIONS
    unset TAR_EXIT_STATUS
    unset TAR_OPTS
    unset SUCCESS
    unset FLAMETHROWER_TARPIPE
}

################################################################################
#
#   Get other binaries, kernel module tree, and miscellaneous other stuff that
#   got put in the binaries tarball. -BEF-
#
get_boel_binaries_tarball() {

    logmsg
    logmsg get_boel_binaries_tarball
#    mkdir -p ${BOEL_BINARIES_DIR}
#
#    if [ ! -z $SSH_DOWNLOAD_URL ]; then
#        # If we're using SSH, get the boel_binaries from a web server.
#        logmsg "SSH_DOWNLOAD_URL variable is set, so we will install over SSH!"
#
#        if [ ! -z $FLAMETHROWER_DIRECTORY_PORTBASE ]; then
#            logmsg "FLAMETHROWER_DIRECTORY_PORTBASE is also set, but I will be conservative and proceed with SSH."
#        fi
#
#        # Remove possible trailing / from URL
#        SSH_DOWNLOAD_URL=`echo $SSH_DOWNLOAD_URL | sed 's/\/$//'`
#
#        cd ${BOEL_BINARIES_DIR}
#        CMD="wget ${SSH_DOWNLOAD_URL}/${ARCH}/${FLAVOR}/boel_binaries.tar.gz"
#        logmsg "$CMD"
#        $CMD || shellout
#
#    elif [ "x$BITTORRENT" = "xy" ]; then
#
#        # Download BOEL binaries from peers
#        bittorrent_tarball="boel_binaries.tar.gz"
#        logmsg "Start downloading ${bittorrent_tarball} (${ARCH}) using bittorrent"
#        logmsg ""
#        logmsg "--> INFO: remember to start /etc/init.d/systemimager-server-bittorrent on the image server!"
#        logmsg ""
#        bittorrent_get_file ${TORRENTS_DIR}/${ARCH}-${bittorrent_tarball}.torrent ${BOEL_BINARIES_DIR}
#        cd ${BOEL_BINARIES_DIR} && mv ${ARCH}-${bittorrent_tarball} ${bittorrent_tarball}
#        unset bittorrent_tarball
#
#    elif [ ! -z $FLAMETHROWER_DIRECTORY_PORTBASE ]; then
#
#        MODULE_NAME="boot-${ARCH}-${FLAVOR}"
#        DIR="${BOEL_BINARIES_DIR}"
#        RETRY=7
#        flamethrower_client
#
#    else
#        # Use rsync
#        CMD="rsync -av ${IMAGESERVER}::boot/${ARCH}/${FLAVOR}/boel_binaries.tar.gz ${BOEL_BINARIES_DIR}"
#        logmsg "$CMD"
#        $CMD || shellout
#    fi
#
#    # Untar the tarball
#    tar -C / -xzf ${BOEL_BINARIES_DIR}/boel_binaries.tar.gz || shellout
#    chown -R 0.0 /lib/modules || shellout
}
#
################################################################################
#
monitor_save_dmesg() {
#    if [ -z $MONITOR_SERVER ]; then
#        return
#    fi
# OL: Note: this function ins called in the initqueue mainloop at each loop.
#     We just need to do that once.
# OL: In fact this is deprecated on systemd systems as journalctl can dump everything.
if test ! -f /tmp/si_monitor.log
then
    loginfo "Saving dmesg to /tmp/si_monitor.log"
    dmesg -s 16392 > /tmp/si_monitor.log
fi
}
#
################################################################################
#
# Load any modules that were placed in the my_modules directory prior to
# running "make initrd.gz".  -BEF-
load_my_modules() {
    loginfo "Trying to load my_modules..."
    cd /my_modules || shellout
    sh ./INSMOD_COMMANDS
}

################################################################################
#
show_loaded_modules() {
    # Show loaded modules
    loginfo "Loaded kernel modules:"
    loginfo `cut -d' ' -f1 /proc/modules|sort|tr '\n' ' '`
}
#
################################################################################
#
get_hostname_by_hosts_file() {

    loginfo get_hostname_by_hosts_file

    #
    # Look in $FILE for that magic joy.
    #
    FILE=${SCRIPTS_DIR}/hosts
    if [ -e $FILE ]; then

        loginfo "Hosts file exists..."

        # add escape characters to IPADDR so that it can be used to find HOSTNAME below
        IPADDR_ESCAPED=`echo "$IPADDR" | sed -e 's/\./\\\./g'`
        
        # get HOSTNAME by parsing hosts file
        loginfo "Searching for this machine's hostname in $FILE by IP: $IPADDR"
        
        # Command summary by line:
        # 1: convert tabs to spaces -- contains a literal tab: <ctrl>+<v> then <tab>
        # 2: remove comments
        # 3: add a space at the beginning of every line
        # 4: get line with IP address (no more no less)
        # 5: strip out ip address
        # 6: strip out space(s) before first hostname on line
        # 7: remove any aliases on line
        # 8: remove domain name, leaving naught but the hostname, naked as the day it were born
        
        HOSTNAME=`
            sed 's/[[:space:]]/ /g' $FILE | \
            grep -v '^ *#' | \
            sed 's/^/ /' | \
            grep " $IPADDR_ESCAPED " | \
            sed 's/ [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*//' | \
            sed 's/ *//' | \
            sed 's/ .*//' | \
            sed 's/\..*$//g'
        `
    else
        loginfo "No hosts file."
    fi
}
#
################################################################################
#
get_hostname_by_dns() {

    loginfo "Trying to get hostname using DNS..."

    # Get base hostname.  For example, www7.domain.com will become www7. -BEF-
    HOSTNAME=`LC_ALL=C host $IPADDR|sed -E -ne 's/.*pointer[[:space:]]+(([a-z][a-z0-9]+\.)+)$/\1/p'`
    # We need non FQDN name ( We need ${HOSTNAME%%.*} but dash is poor in variable substitution
    HOSTNAME=`echo $HOSTNAME|cut -d'.' -f1`
    loginfo "Got hostname: [$HOSTNAME]"
}
#
################################################################################
#
get_base_hostname() {
    BASE_HOSTNAME=`echo $HOSTNAME | sed "s/[.0-9].*$//"` 
}
#
################################################################################
#
get_group_name() {
    if [ -f ${SCRIPTS_DIR}/cluster.txt ]; then
        [ -z "$GROUPNAMES" ] && \
            GROUPNAMES=`unique $(grep "^${HOSTNAME}:" ${SCRIPTS_DIR}/cluster.txt | cut -d: -f2 | tr "\n" ' ')`
        [ -z "$IMAGENAME" ] && \
            IMAGENAME=`grep "^${HOSTNAME}:" ${SCRIPTS_DIR}/cluster.txt | cut -d: -f3 | grep -v '^[[:space:]]*$' | sed -ne '1p'`
        if [ -z "$GROUP_OVERRIDES" ]; then
            GROUP_OVERRIDES=`reverse $(unique $(grep "^${HOSTNAME}:" ${SCRIPTS_DIR}/cluster.txt | cut -d: -f4 | tr "\n" ' '))`
            # Add the global override on top (least important).
            GROUP_OVERRIDES="`sed -ne 's/^# global_override=:\([^:]*\):$/\1/p' ${SCRIPTS_DIR}/cluster.txt` $GROUP_OVERRIDES"
        fi
    fi
    write_variables # Save GROUPNAMES and GROUP_OVERRIDES to variables.txt
}

################################################################################
#
# choose_filename()
# $1: PATH to search for
# $*: extentions to search for
#
# Choose one file, in order of preference.  First hit wins.
# Order of preference is:
#   HOSTNAME                (i.e. node001.<ext>)
#   GROUPNAMES              (i.e. Login.<ext>) - see /etc/systemimager/cluster.xml on the image server
#   BASE_HOSTNAME           (i.e. node.<ext>)
#   IMAGENAME               (i.e. ubuntu7_04.<ext>)
#   "default"               (i.e. default.<ext>)
#
# return: full path of 1st occurence found.
#
# example: choose_filename /scripts/main-install "" ".sh" ".master"
#
choose_filename() {
	logdebug "choose_filename $*"
	get_base_hostname
	DIR=$1
	shift
	for FILE in ${HOSTNAME} ${GROUPNAMES} ${BASE_HOSTNAME} ${IMAGENAME} default
	do
		for EXT in $*
		do
			FOUND=${DIR}/${FILE}${EXT}
			logdebug "Trying ${FOUND}"
			test -e ${FOUND} && break 2
		done
	done
	# Check we went out thru break.
	if test -e "${FOUND}"
	then
		logdebug "Got: [${FOUND}]"
		echo "${FOUND}"
	else
		logdebug "No matching file found. in [$DIR]"
		echo ""
	fi
}

################################################################################
#
choose_autoinstall_script() {

    loginfo "Choosing autoinstall script..."

    # If SCRIPTNAME is specified as a kernel append, or via local.cfg, then use that script.
    #
    if [ -n "${SCRIPTNAME}" ]; then
        #
        # SCRIPTNAME was specified, but let's be flexible.  Try explicit first, then .master, .sh. -BEF-
        #
        SCRIPTNAMES="${SCRIPTS_DIR}/${SCRIPTNAME} ${SCRIPTS_DIR}/${SCRIPTNAME}.sh ${SCRIPTS_DIR}/${SCRIPTNAME}.master"

	# Script name was specified, so it MUST be available. If not, we must fail.
        [ ! -e ${SCRIPTS_DIR}/${SCRIPTNAME} -a ! -e ${SCRIPTS_DIR}/${SCRIPTNAME}.sh -a !-e ${SCRIPTS_DIR}/${SCRIPTNAME}.master ] || shellout "Can't find requested main autoinstall script: ${SCRIPTNAME}{,.sh,.master}"
    else
            SCRIPTNAMES=`choose_filename /scripts/main-install "" ".sh" ".master"`
    fi

    #
    # Choose a winner!
    #
    for SCRIPTNAME in $SCRIPTNAMES
    do
        [ -e $SCRIPTNAME ] && break
    done

    # Did we really find one, or just exit the loop without a 'break'
    if [ ! -e "${SCRIPTNAME}" ]; then
        logwarn "No main autoinstall script defined. Looked for:"
        logwarn "${SCRIPTNAMES}"
        logwarn "If you need a main install script, check that one of the above scipts"
        logwarn "exists in the autoinstall scripts directory on your image server."
        logwarn "See also: si_mkautoinstallscript(8)."
	SCRIPTNAME=""
    else
        # check that script version is sufficient.
        SCRIPT_VERSION=`grep -E '#\s*script_version:[0-9]+\s*$' ${SCRIPTNAME}|cut -d: -f2`
        [ -z "${SCRIPT_VERSION}" ] && SCRIPT_VERSION=1
        [ ${SCRIPT_VERSION} -lt 2 ] && shellout "Script ${SCRIPTNAME} is too old and incompatible with this version of systemimager. Please uptate is with si_mkautoinstallscript"
        loginfo "Using autoinstall script: ${SCRIPTNAME}"
    fi
    write_variables # Save selected SCRIPTNAME
}

################################################################################
#
run_pre_install_scripts() {

    loginfo "Running pre-install scripts"

    sis_update_step prei # Plymouth: Light on PreInstall icon
    get_base_hostname

    # Get group name (defined in /etc/systemimager/cluster.xml on the image
    # server). -AR-
    get_group_name

    if [ -e "${SCRIPTS_DIR}/pre-install/" ]; then

        cd ${SCRIPTS_DIR}/pre-install/

        PRE_INSTALL_SCRIPTS="$PRE_INSTALL_SCRIPTS `ls | grep "^[0-9][0-9]all\..*"`"
        PRE_INSTALL_SCRIPTS="$PRE_INSTALL_SCRIPTS `ls | grep "^[0-9][0-9]${IMAGENAME}\..*"`"
        PRE_INSTALL_SCRIPTS="$PRE_INSTALL_SCRIPTS `ls | grep "^[0-9][0-9]${BASE_HOSTNAME}\..*"`"
        for GROUPNAME in ${GROUPNAMES}; do
            PRE_INSTALL_SCRIPTS="$PRE_INSTALL_SCRIPTS `ls | grep "^[0-9][0-9]${GROUPNAME}\..*"`"
        done
        unset GROUPNAME
        PRE_INSTALL_SCRIPTS="$PRE_INSTALL_SCRIPTS `ls | grep "^[0-9][0-9]${HOSTNAME}\..*"`"


        # Now, to get rid of those pesky newlines. -BEF-
	# BUG: assuming no script has a space in its name. -OL-
        PRE_INSTALL_SCRIPTS=`echo $PRE_INSTALL_SCRIPTS | tr '\n' ' '`
        if [ ! -z "`echo ${PRE_INSTALL_SCRIPTS}|sed 's/ //'`" ]; then

	    PRE_SCRIPTS=`unique "$PRE_INSTALL_SCRIPTS"`
	    NUM_SCRIPTS=`echo "$PRE_SCRIPTS"|wc -w`
            SCRIPT_INDEX=1
            for PRE_INSTALL_SCRIPT in ${PRE_SCRIPTS}
            do
                sis_update_step prei ${SCRIPT_INDEX} ${NUM_SCRIPTS}
                loginfo "Running script ${SCRIPT_INDEX}/${NUM_SCRIPTS}: $PRE_INSTALL_SCRIPT"
		send_monitor_msg "status=108:speed=${SCRIPT_INDEX}" # 108=preinstall speed=script_num
                chmod +x $PRE_INSTALL_SCRIPT || shellout
                ./$PRE_INSTALL_SCRIPT || shellout
		SCRIPT_INDEX=$((${SCRIPT_INDEX} + 1))
            done
        else
            loginfo "No pre-install scripts found."
        fi

        if [ -e "/tmp/pre-install_variables.txt" ]; then
            . /tmp/pre-install_variables.txt
        fi

    fi
}
#
################################################################################
#
run_autoinstall_script() {

    # 1st, determine which script to run.
    choose_autoinstall_script

    if [ -n "${SCRIPTNAME}" ]
    then
        loginfo "Running autoinstall script $SCRIPTNAME"

        # Run the autoinstall script.
        chmod 755 $SCRIPTNAME || shellout "Can't chmod 755 $SCRIPTNAME"
        $SCRIPTNAME || shellout "Failed to run $SCRIPTNAME"
    else
	loginfo "Imaging without main install script."
    fi
}
#
################################################################################
#
run_post_install_scripts() {

    loginfo "Running post-install scripts"
    sis_update_step post

    get_base_hostname

    # Get group name (defined in /etc/systemimager/cluster.xml on the image
    # server). -AR-
    get_group_name

    if [ -e "${SCRIPTS_DIR}/post-install/" ]; then

        # make a copy of variables.txt available to post-install scripts -BEF-
        cp -f /tmp/variables.txt ${SCRIPTS_DIR}/post-install/

        cd ${SCRIPTS_DIR}/post-install/

        POST_INSTALL_SCRIPTS="$POST_INSTALL_SCRIPTS `ls | grep "^[0-9][0-9]all\..*" | grep -v "~$" `"
        POST_INSTALL_SCRIPTS="$POST_INSTALL_SCRIPTS `ls | grep "^[0-9][0-9]${IMAGENAME}\..*" | grep -v "~$" `"
        POST_INSTALL_SCRIPTS="$POST_INSTALL_SCRIPTS `ls | grep "^[0-9][0-9]${BASE_HOSTNAME}\..*" | grep -v "~$" `"
        for GROUPNAME in ${GROUPNAMES}; do
            POST_INSTALL_SCRIPTS="$POST_INSTALL_SCRIPTS `ls | grep "^[0-9][0-9]${GROUPNAME}\..*" | grep -v "~$" `"
        done
        POST_INSTALL_SCRIPTS="$POST_INSTALL_SCRIPTS `ls | grep "^[0-9][0-9]${HOSTNAME}\..*" | grep -v "~$" `"

        # Now, to get rid of those pesky newlines. -BEF-
        POST_INSTALL_SCRIPTS=`echo $POST_INSTALL_SCRIPTS | tr '\n' ' '`
        
        if [ ! -z "`echo ${POST_INSTALL_SCRIPTS}|sed 's/ //'`" ]; then

            mkdir -p /sysroot/tmp/post-install/ || shellout

            CMD="rsync -a ${SCRIPTS_DIR}/post-install/ /sysroot/tmp/post-install/"
	    logdetail "$CMD"
	    $CMD > /dev/null 2>&1 || logwarn "Failed to retrieve ${SCRIPTS_DIR}/post-install directory..."

	    POST_SCRIPTS=`unique "$POST_INSTALL_SCRIPTS"`
	    NUM_SCRIPTS=`echo "$POST_SCRIPTS"|wc -w`
            SCRIPT_INDEX=1

            for POST_INSTALL_SCRIPT in ${POST_SCRIPTS}
            do
                if [ -e "$POST_INSTALL_SCRIPT" ]; then
                    sis_update_step post ${SCRIPT_INDEX} ${NUM_SCRIPTS}
                    loginfo "Running script ${SCRIPT_INDEX}/${NUM_SCRIPTS}: $POST_INSTALL_SCRIPT"
		    send_monitor_msg "status=109:speed=${SCRIPT_INDEX}" # 109=postinstall speed=script_num
                    chmod +x /sysroot/tmp/post-install/$POST_INSTALL_SCRIPT || shellout
                    chroot /sysroot/ /tmp/post-install/$POST_INSTALL_SCRIPT || shellout
		    SCRIPT_INDEX=$(( ${SCRIPT_INDEX} + 1))
                fi
            done
        else
            loginfo "No post-install scripts found."
        fi

        # Clean up post-install script directory.
        rm -rf /sysroot/tmp/post-install/ || shellout
    fi
}
#
################################################################################
#
#   Stuff for SSH installs
#

start_sshd() {
    export HOME=/root # We're running as root.
    mkdir -p /root/.ssh/ || shellout "Failed to create /root/.ssh/"
    chmod 700 /root/.ssh || shellout "Failed to set permissions on /root/.ssh/"

    # Download ssh authorized_keys if it's not present into the initrd.
    if [ ! -f /root/.ssh/authorized_keys ]; then
        if [ -z $SSH_DOWNLOAD_URL ]; then
            logerror "authorized_keys not found and SSH_DOWNLOAD_URL not defined in the installation parameters!"
            shellout "sshd can't be started!"
        fi
        CMD="wget ${SSH_DOWNLOAD_URL}/${ARCH}/ssh/authorized_keys"
        loginfo "$CMD"
	cd /root/.ssh/
        $CMD || shellout "Failed to download ${SSH_DOWNLOAD_URL}/${ARCH}/ssh/authorized_keys"
	cd /tmp
    fi

    # set permissions to 600 -- otherwise, sshd will refuse to use it
    loginfo "Setting correct permissions for /root/.ssh/authorized_keys"
    chmod 600 /root/.ssh/authorized_keys || shellout "Failed to chmod 600 authorized_keys"

    # must be owned by root
    loginfo "Setting correct ownership for /root/*"
    chown -R 0.0 /root/
        
    # create a private host key for this autoinstall client
    loginfo "Using ssh-keygen to create this host private keys"
    mkdir -p /var/empty/sshd || shellout "Failed to create ssh privilege separation directory (/var/empty/sshd)"

    # Now generate hosts keys required in /etc/ssh/sshd_config
    for key in `grep '^HostKey' /etc/ssh/sshd_config|cut -d' ' -f2`
    do
	    if [ ! -f $key ]; then
		    key_type=`echo $key|sed -r 's/^.*host_([0-9a-z]+)_key/\1/i'`
		    loginfo "Generating $key_type key $key"
		    ssh-keygen -t $key_type -N "" -f $key || shellout "Failed to create $key_type key"
	    else
		    loginfo "$key_type key $key already exists. Keeping it."
	    fi
    done

    # fire up sshd
    mkdir -p /var/run/sshd || shellout "Failed to create /var/run/sshd/"
    chmod 0755 /var/run/sshd || shellout "Failed to set permissions on /var/run/sshd"
    /usr/sbin/sshd || shellout "Failed to start ssh daemon."
    loginfo "ssh daemon started"
    touch /tmp/sshd_started
}
#
################################################################################
#
start_ssh() {
    export HOME=/root # We're running as root.
    # create root's ssh dir
    mkdir -p /root/.ssh/ || shellout "Failed to create /root/.ssh/"
    chmod 700 /root/.ssh || shellout "Failed to set permissions on /root/.ssh/"

    ############################################################################
    #
    # If a private key exists, put it in the right place so this autoinstall
    # client can use it to authenticate itself to the imageserver.
    #
    if [ -e /root/.ssh/id_dsa ]; then
        # (ssh2 dsa style user private key)
        PRIVATE_KEY=/root/.ssh/id_dsa
        chmod 600 $PRIVATE_KEY         || shellout "Failed to chmod 600 $PRIVATE_KEY"
    elif [ -e /root/.ssh/id_rsa ]; then
        # (ssh2 rsa style user private key)
        PRIVATE_KEY=/root/.ssh/id_rsa
        chmod 600 $PRIVATE_KEY         || shellout "Failed to chmod 600 $PRIVATE_KEY"
    elif [ -e /floppy/id_dsa ]; then
        # (ssh2 dsa style user private key) from floppy
        PRIVATE_KEY=/root/.ssh/id_dsa
        cp /floppy/id_dsa $PRIVATE_KEY || shellout "Failed to cp /floppy/id_dsa $PRIVATE_KEY"
        chmod 600 $PRIVATE_KEY         || shellout "Failed to chmod 600 $PRIVATE_KEY"
    elif [ -e /floppy/id_rsa ]; then
        #
        # (ssh2 rsa style user private key) from floppy
        PRIVATE_KEY=/root/.ssh/id_rsa
        cp /floppy/id_rsa $PRIVATE_KEY || shellout "Failed to cp /floppy/id_rsa $PRIVATE_KEY"
        chmod 600 $PRIVATE_KEY         || shellout "Failed to chmod 600 $PRIVATE_KEY"
    fi
    #
    ############################################################################

    # If we have a private key from the media above, go ahead and open secure tunnel
    # to the imageserver and continue with the autoinstall like normal.
    if [ ! -z "$PRIVATE_KEY" ]; then

	loginfo "We have a private key. Trying to open a tunnel to the imaging server."
        # With the prep ready, start the ssh tunnel connection.
        #
        # Determine if we should run interactive and set redirection options appropriately.
        # So if the key is blank, go interactive. (Suggested by Don Stocks <don_stocks@leaseloan.com>)
        if [ -s "$PRIVATE_KEY" ]; then
            # key is *not* blank
            REDIRECTION_OPTIONS="> /dev/null 2>&1"
        else
            # key is blank - go interactive
            REDIRECTION_OPTIONS=""
        fi

	# OL: Obsolete => SSH_USER has always a value (defaults to root in parse-sis-options*.sh)
        # Default ssh user is root.
        # [ -z $SSH_USER ] && SSH_USER=root

        CMD="ssh -N -l $SSH_USER -n -f -L873:127.0.0.1:873 $IMAGESERVER $REDIRECTION_OPTIONS"
        loginfo "Starting: $CMD"
        $CMD || shellout "Failed to start ssh tunnel".
        
        # Since we're using SSH, change the $IMAGESERVER variable to reflect
        # the forwarded connection.
        IMAGESERVER=127.0.0.1
        write_variables # Make IMAGESERVER change persistent.
    else
        ########################################################################
        #
        # Looks like we didn't get a private key so let's just fire up
        # sshd and wait for someone to connect to us to initiate the
        # next step of the autoinstall.
        #
	loginfo "No private key available. Trying to start a ssh server..."
        if [ -z $HOSTNAME ]; then
            loginfo "Trying to get hostname via DNS..."
            get_hostname_by_dns
        fi
        
        if [ -z $HOSTNAME ]; then
            HOST_OR_IP=$IPADDR
        else
            HOST_OR_IP=$HOSTNAME
        fi

        if [ ! -f /tmp/sshd_started ]; then
            start_sshd
            # Give sshd time to initialize before we yank the parent process
            # rug out from underneath it.
            sleep 5
        fi
	loginfo "Started sshd."
	cat > /dev/console <<EOF
${BG_BLUE}================================================================================
      You must now go to your imageserver and issue the following command:
          "${FG_AMBER}si_pushinstall --hosts ${HOST_OR_IP}"${FG_WHITE}
================================================================================${BG_BLACK}
EOF
	loginfo "Wainting for si_pushupdate to complete..."
	# Now the plymouth equivalent.
        sis_dialog_box zzz "You must now go to your imageserver"
        sis_dialog_box zzz "and issue the following command:"
	sis_dialog_box zzz " "
	sis_dialog_box zzz "si_pushinstall --hosts ${HOST_OR_IP}"
	sis_dialog_box zzz " "
	sis_dialog_box zzz "(Wainting for si_pushupdate to complete...)"
        # Since we're using SSH, change the $IMAGESERVER variable to reflect
        # the forwarded connection.
        IMAGESERVER=127.0.0.1
        write_variables # Keep track of IMAGESERVER

        while [ ! -f /tmp/si_pushupdate.completed ]; do
		for spin in '/' '-' '\\' '|'
		do
			/bin/echo -ne "$spin\r" > /dev/console
			sleep 0.5
		done
        done
	sis_dialog_box off # Close the plymouth dialog box
    fi
}
#
################################################################################
#
#  send_monitor_msg
#
#   Description:
#   Redirect a message to the monitor server.
#
#   Usage: send_monitor_msg "var=$msg"
#

send_monitor_msg() {
    if test -z "${MONITOR_SERVER}"; then
	logdebug "Trying to send monitor msg with unset MONITOR_SERVER variable. Ignoring..."
        return
    fi
    if test -z "${MONITOR_PORT}" ; then
        MONITOR_PORT=8181
    fi

    # Message to send.
    msg=`echo "$@"`

    # Get the client mac address.
    if [ -z "$mac" ]; then
        #mac=`ifconfig $DEVICE 2>/dev/null | sed -ne "s/.*HWaddr //p" | sed "s/ //g" | sed s/:/./g`
        mac=`ip -o link show $DEVICE 2>/dev/null | grep -o -E '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' -m 1|grep -vi 'FF:FF:FF:FF:FF:FF' | sed -e 's/:/./g' -e 's/\(.*\)/\U\1/'`
    fi

    # Collect some special info only after proc file system is mounted.
    if [ `mount 2>/dev/null | grep proc > /dev/null; echo $?` -eq 0 ]; then
        # Collect the CPU info.
        if [ -z "$cpu" ]; then
            cpu=$(echo `cat /proc/cpuinfo | grep "cpu\|clock\|model name\|cpu MHz" | grep -v "cpu family" | sed -ne '1,2p' | sed "s/.*: //" | sed "s/^\([0-9\.]*\)MHz$/(\1 MHz)/" | sed "s/^\([0-9\.]*\)$/(\1 MHz)/"` | sed "s/\(MHz)\)/\1 |/g" | sed "s/ |$//")
        fi

        # Collect the number of CPUs.     
        if [ -z "$ncpus" ]; then
            ncpus=$((`cat /proc/cpuinfo | grep "^processor" | sed -n '$p' | sed "s/.*: \([0-9]\)*$/\1/"` + 1))
        fi

        # Collect the kernel information.
        if [ -z "$kernel_name" ]; then
            kernel_name=`uname -r`
        fi

        # Collect the amount of phyisical memory.
        if [ -z "$mem" ]; then
            mem=`cat /proc/meminfo | sed -ne "s/MemTotal: *//p" | sed "s/ kB//"`
        fi

        # Evaluate the amount of available RAM.
        tmpfs=`df | grep tmpfs | grep "/$" | sed "s/.* \([0-9]*%\) .*/\1/"`

        # Evaluate the uptime of the client.
        time=`cat /proc/uptime | sed "s/\..*//"`
    fi

    # Report the message to the monitor server.
    send_msg=`echo "mac=$mac:ip=$IPADDR:host=$HOSTNAME:cpu=$cpu:ncpus=$ncpus:kernel=$kernel_name:mem=$mem:os=$IMAGENAME:tmpfs=$tmpfs:time=$time:$msg"`

    # Send data to monitor server.
    echo "$send_msg" | ncat $MONITOR_SERVER $MONITOR_PORT
}
#
################################################################################
#
#  send_monitor_stdout
#
#   Description:
#   Redirect a stdout of a command to the monitor console.
#
#   Usage: <cmd> | send_monitor_stdout
#

send_monitor_stdout() {
    while read l; do
        # echo to the console -AR-
        echo "$l"
        # Send the message to the monitor daemon.
        if [ "x$MONITOR_CONSOLE" = "xy" ]; then
            MONITOR_CONSOLE=yes
        fi
        if [ "x$MONITOR_CONSOLE" = "xyes" ]; then
            # Log message into the global monitor log.
            echo "$l" >> /tmp/si_monitor.log
        fi
    done
}
#
################################################################################
#
#   Report installation progress in the console and to the monitor server
#

start_report_task() {
    # Reporting interval (in sec).
    REPORT_INTERVAL=10

    # Check that IMAGESIZE is not empty (rsync or torrentinfo-console could have failed)
    test -z "${IMAGESIZE}" && shellout "BUG? IMAGESIZE not initialized. init_transfer() not ran?"

    loginfo "  --> Image size = `expr $IMAGESIZE / 1024`MiB"

    # Evaluate disks size.
    LIST=`df 2>/dev/null | grep "/" | sed "s/  */ /g" | cut -d' ' -f3 | sed -ne 's/^\([0-9]*\)$/\1+/p'`0
    DISKSIZE=`echo $LIST | bc`

    # Spawn the report task -AR-
    {

    sleep 1s # Give time for caller to print its messages before we start refreshing the progressbar.

    TOT=0; CURR_SIZE=0
    while :; do
        LIST=`df 2>/dev/null | grep "/" | sed "s/  */ /g" | cut -d' ' -f3 | sed -ne 's/^\([0-9]*\)$/\1+/p'`0
        TOT=`echo $LIST | bc`

        # Evaluate bandwidth.
        speed=`echo "scale=2; (($TOT - $DISKSIZE) - $CURR_SIZE) / $REPORT_INTERVAL" | bc`
        speed=`echo "scale=2; if ($speed >= 0) { print $speed; } else { print 0; }" | bc`

        # Evaluate status.
        CURR_SIZE=$(($TOT - $DISKSIZE))
        status=`echo "scale=2; $CURR_SIZE * 100 / $IMAGESIZE" | bc`
        if [ `echo "scale=2; $status <= 0" | bc` -eq 1 ]; then 
            status=1
        elif [ `echo "scale=2; $status >= 100" | bc` -eq 1 ]; then
            status=99
        fi

	# Update text progress bar.
	ProgressBar ${status}

	# Update Plymouth progress bar.
	sis_update_step imag ${status} 100

	if [ ! -z "$MONITOR_SERVER" ]; then
            # Send status and bandwidth to the monitor server.
            send_monitor_msg "status=$status:speed=$speed"
	fi
        
        # Wait $REPORT_INTERVAL sec between each report.
        sleep ${REPORT_INTERVAL}s
    done
    }&

    REPORT_PID=$!
    disown # Remove this task from shell job list so no debug output will be written when killed.
    loginfo "Progress report task started."
    logdetail "PID=$REPORT_PID"
    echo $REPORT_PID > /run/systemimager/report_task.pid
}

################################################################################
#
#   Stop to report installation progress/status in the console and to the monitor server
#

stop_report_task() {
    # Try to report the error to the monitor server.
    if [ ! -z "$MONITOR_SERVER" ]; then
        send_monitor_msg "status=$1:speed=0"
    fi

    if test -s /run/systemimager/report_task.pid; then
	[ "$1" -eq 101 ] && ProgressBar 100 # Fake 100% if status = "Finalizing"
	#echo "  " > /dev/console # Make sure we're on a new line (and clean glitches)
        loginfo "Stopping progress report task."
        REPORT_PID=`cat /run/systemimager/report_task.pid`
	rm -f /run/systemimager/report_task.pid
        # Making sure it is an integer.
	test -n "`echo ${REPORT_PID}|sed -r 's/[0-9]*//g'`" && shellout "Can't kill report task: /run/systemimager/report_task.pid is not a pid."
        if [ ! -z "$REPORT_PID" ]; then
            kill -9 $REPORT_PID
	    wait $REPORT_PID # Make sure process is killed before continuing.
	    #test -w /dev/console && echo "${BG_BLACK}" > /dev/console
            loginfo "Progress report task stopped"
        fi
    fi
}

################################################################################
#
#   Beep incessantly
#
beep_incessantly() {
    send_monitor_msg "status=103:speed=0" # 103: beeping
    modprobe pcspkr # Make sure pcspkr module is loaded
    local SECONDS=1
    local MINUTES
    local MINUTES_X_SIXTY
    { while :;
        do
            /bin/echo -ne '\a' > /dev/console
            if [ $SECONDS -lt 60 ]; then 
                logmsg "I have been done for $SECONDS seconds.  Reboot me already!"
            else
                MINUTES=`echo "$SECONDS / 60"|bc`
                MINUTES_X_SIXTY=`echo "$MINUTES * 60"|bc`
                if [ "$MINUTES_X_SIXTY" = "$SECONDS" ]; then 
                    logmsg "I have been done for $MINUTES minutes now.  Reboot me already!"
                fi  
            fi
            sleep 1
            SECONDS=`echo "$SECONDS + 1"|bc`
        done
    }
}
#
################################################################################
#
#   Beep incessantly
#
# Usage: beep [$COUNT [$INTERVAL]]
# Usage: beep
beep() {
    modprobe pcspkr # Make sure pcspkr module is loaded
    local COUNT=$1
    local INTERVAL=$2

    [ -z $COUNT ] && COUNT=1
    [ -z $INTERVAL ] && INTERVAL=1

    local COUNTED=0
    until [ "$COUNTED" = "$COUNT" ]
    do
        /bin/echo -ne '\a' > /dev/console
        sleep $INTERVAL
        COUNTED=$(( $COUNTED + 1 ))
    done
}
#
################################################################################
#
#   Print out dots while sleeping
#
# Usage: sleep_loop [[$COUNT [$INTERVAL]] $CHARACTER]
# Usage: sleep_loop
sleep_loop() {
    local COUNT=$1
    local INTERVAL=$2
    local CHARACTER=$3
    local COUNTED

    [ -z $COUNT ] && COUNT=1
    [ -z $INTERVAL ] && INTERVAL=1
    [ -z $CHARACTER ] && CHARACTER=.

    COUNTED=0
    until [ "$COUNTED" = "$COUNT" ]
    do
        echo -n "$CHARACTER"
        sleep $INTERVAL
        COUNTED=$(( $COUNTED + 1 ))
    done
}
#
#################################################################################
# Try to guess which iface to use.
# Will use $DEVICE if it was set before. This allows for cmdline parameters to
# set a specific device to use.
#
get_1st_iface_with_link() {
    if test -n "$DEVICE"
    then # DEVICE= already setup by system. keep this choice.
        echo $DEVICE
        return 0
    fi
    if test -d /sys/class/net/
    then
        for IFACE in /sys/class/net/*
        do
            DETAIL=`ls -l $IFACE 2>/dev/null |grep -v virtual`
            if test -n "$DETAIL"
            then # We found an interface that is not virtual.
                LINK=`cat $IFACE/carrier 2>/dev/null`
                if test -n "$LINK"
                then
                    DEVICE="${IFACE##*/}"
                    echo "${DEVICE}"
                    return 0 # Found!
                fi
            fi
        done
        echo "" # No physiscal interface found that has a link
        return 1
    else
        echo "" # No way to check interface.
        return 1
    fi
}
#
#################################################################################
# Inspired from progress bar from Teddy Skarin
# Available here: https://github.com/fearside/ProgressBar/
# Modified for /bin/dash compatibility and systemimager needs.
#
# USAGE: ProgressBar <progress percentage>
#
ProgressBar() {
    #_console_width=`tput cols`
    _console_width=`stty -F /dev/console size|cut -d' ' -f2`
    [ "${_console_width}" -lt 80 ] && _console_width=80
    _bar_width=$((${_console_width}-21))
    _ipart=`printf "%.0f" "${1}"`
    _done=$(((${_ipart}*$_bar_width)/100))
    _left=$((${_bar_width}-$_done))
    # Build progressbar string lengths
    _fill=$(printf "%${_done}s"|tr ' ' '#')
    _empty=$(printf "%${_left}s"|tr ' ' '-')

    # Build progressbar strings and print the ProgressBar line
    printf "\rProgress : ${BG_BLUE}[${_fill}${_empty}]${BG_BLACK} ${1}%%" > /dev/console
}

#################################################################################
# Handle SE_Linux files.
#
# USAGE: SEL_Fixfiles
#
SEL_FixFiles() {
if [ "x$SEL_RELABEL" = "xy" ]
then
    loginfo "Making sure files have correct selinux label"
    if [ -x /sysroot/sbin/getenforce -o -x /sysroot/usr/sbin/getenforce ]
    then
	    SE_POLICY=`/sysroot/sbin/getenforce`
    fi
    if [ "$SE_POLICY" != "Permissive" ] # Disabled  or Enforcing
    then
	    logwarn "Cannot fix SE Linux file label. (need SELINUX=permissive)"
	    logwarn "current SELinux status: ${SE_POLICY}"
	    logwarn "Setting autorelabel for next reboot."
	    logaction "touch /.autorelabel"
	    touch /sysroot/.autorelabel
	    return
    fi
    # SE_POLICY is set to Permissive, so we should be able to relabel now.
    if [ -x /sysroot/sbin/fixfiles -o -x /sysroot/usr/sbin/fixfiles] ; then
	    logaction "/sbin/fixfiles -f relabel"
	    chroot /sysroot /sbin/fixfiles -f relabel
    else
	    logwarn "no fixfiles binary found. Telling the OS to do that at next boot"
	    logaction "touch /.autorelabel"
	    touch /sysroot/.autorelabel
    fi
fi
}

#################################################################################
# Install bootloader on all disk specified as argument.
# (Only supports grub2 and grub)
#
# USAGE: install_boot_loader <disk device> [<disk device> <disk device> ... ]

install_boot_loader() {
	sis_update_step boot 0 0
	IFS=" "
	test -z "$*" && shellout "No disks to install bootloader to!"
	loginfo "Now trying to install a boot loader on"
        loginfo "the following disk(s): [$*]..."

	loginfo "Detecting bootloader flavor..."
	[ -x /sysroot/usr/sbin/grub2-install ] || [ -x /sysroot/sbin/grub2-install ] && BOOT_LOADER="grub2"
	[ -x /sysroot/sbin/grub-install ] && BOOT_LOADER="grub"
	[ -x /tmp/EFI.conf ] && BOOT_LOADER="EFI"

	if test -z "${BOOT_LOADER}"
	then
		logwarn "Can't find a supported bootloader technology. Assuming post install"
		logwarn "scripts will do the job!"
		return
	else
		loginfo "Using the following boot loader: ${BOOT_LOADER}"
	fi

	case "${BOOT_LOADER}" in
		"EFI")
			[ -z "`findmnt -o target,fstype --raw|grep -e '/boot/efi\svfat'`" ] && shellout "No EFI filesystem mounted (/sysroot/boot/efi not a vfat partition)."
			[ ! -d /sysroot/boot/efi/EFI/BOOT ] && shellout "Missing /boot/efi/EFI/BOOT (EFI BOOT directory)."
			# TODO: configure boot manager (either grub2-efi or any other)
			. /tmp/EFI.conf # read requested EFI configuration (boot manager, kernel name, ...)
			shellout "Not yet supported. Sorry"
			;;
		"grub2")
			# if a grub2 specific config exists, we need to install it before generating grub.cfg
			# Typically, this file is used to force raid reassembly in initramfs
			if test -f /tmp/grub_default.cfg
			then
				# Make sure /etc/default exists in /sysroot
				mkdir -p /sysroot/etc/default || shellout "Cannot create /etc/default on imaged system."
				cp -f /tmp/grub_default.cfg /sysroot/etc/default/grub || shellout "Cannot install /etc/default/grub"
			fi

			# Generate grub2 config file from OS already installed 10_linux cfg.
			logaction "Creating /boot/grub2/grub.cfg"
			chroot /sysroot /sbin/grub2-mkconfig --output=/boot/grub2/grub.cfg

			# Install bootloader
			for disk in $@
			do
				[ ! -b "$disk" ] && shellout "Can't install bootloader: [$disk] is not a block device!"
				logaction "chroot /sysroot /sbin/grub2-install --force $disk"
				chroot /sysroot /sbin/grub2-install --force $disk || shellout "Failed to install grub2 bootloader on ${disk}"
			done
			;;
		"grub")
			ROOT=`mount |grep " / "|cut -d" " -f1`
			OS_NAME=`cat /etc/system-release`
			# BUG: (hd0,0) is hardcoded: need to fix that.
			logaction "Creating /boot/grub/menu.lst"
			cat > /sysroot/boot/grub/menu.lst <<EOF
default=0
timeout=5
title ${OS_NAME}
	root (hd0,0)
	kernel /$(cd /boot; ls -rS vmli*|grep -v debug|tail -1) ro root=$ROOT rhgb quiet
	initrd /$(cd /boot; ls -rS init*|grep -v debug|tail -1)
EOF
			# Install bootloader
			for disk in $@
			do
				[ ! -b "$disk" ] && shellout "Can't install bootloader: [$disk] is not a block device!"
				logaction "chroot /sysroot /sbin/grub-install $disk"
				chroot /sysroot /sbin/grub-install $1 || shellout "Failed to install grub1 bootloader on ${disk}"
			done
			;;
		*)
			logwarn "Unsupported bootloader"
			;;
	esac
}

################################################################################
#
#  get_arch
#
# Usage: get_arch; echo $ARCH
#get_arch() {
#    ARCH=`uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/`
#    loginfo "Detected ARCH=$ARCH"
#}

# END
