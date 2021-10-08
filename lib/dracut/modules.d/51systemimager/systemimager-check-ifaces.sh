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
#      This file is run by cmdline-setteled hook from dracut-initqueue service
#      It is called early in mainloop when network is being initialized
#      It checks that /net.iface contains an existing iface (and crosscheck ip= in cmdline
#

type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

################################################################################
#
#  check_ifaces
#
check_ifaces() {
    UNKNOWN_IFACES=""
    loginfo "Checking network interfaces presence...."
    # check interfaces from /tmp/net.ifaces
    for iface in $(cat /tmp/net.ifaces)
    do
	# Does it exists from kernel point of view?
	if test ! -d /sys/class/net/$iface
	then
		logerror "Interface $iface is not seen by kernel"
		# Try to find why?
		for IP in $(getarg ip=)
		do
			if test -n "$(grep :${iface}: <<< \"$IP\")" # IF wrong iface present in ip= parameter
			then
				logerror "${iface} unknown by kernel while specified in ip=$IP cmdline"
				UNKNOWN_IFACES="${UNKNOWN_IFACES} ${iface}"
			fi
		done
	else
		logdebug "${iface} seen by kernel."
	fi
	if test -n "${UNKNOWN_IFACES}" # If there are ifaces specified in ip= parameters (thus present in /tmp/net.ifaces)
	then
		logerror "Requested network interface(s) unknown by kernel:${UNKNOWN_IFACES}"
		KERNEL_IFACES_LIST="$(cd /sys/class/net/; echo *|sed 's/ *lo//')"
		if test -z "$KERNEL_IFACES_LIST"
		then
			logerror "There is no network interface available! Missing or not loaded driver?"
		else

			logerror "Available network interface(s) known by kernel: $KERNEL_IFACES_LIST"
		fi
		logerror "Check your cmdline parameters and/or add missing driver to imager using si_mkbootpackage(8)"
		# Try to find network interfaces present on system
		loginfo "Available hardware network interfaces: (if any)"
		LC_ALL=C lshw -xml -class network|\
		xmlstarlet sel -t -m "/list/node" -v $'concat(product,";",serial,";",configuration/setting[@id="driver"]/@value,";",logicalname,"\n")'|\
		while IFS=';' read MODEL MAC DRIVER NAME
		do
			if test -n "$DRIVER"
			then
				HW_DRIVER="$DRIVER (not loaded)"
				if test -n "$(lsmod|grep ^$DRIVER)"
				then
					HW_DRIVER="$DRIVER (loaded)"
				fi
			else
				HW_DRIVER="unknown"
			fi
			test -n "$MODEL" && loginfo "- $MODEL / Driver:$HW_DRIVER / Name:${NAME:-?} / MAC:(${MAC:-?})"
		done
		shellout "Make sure you only use known interfaces (field Name: above) in ip= parameter."
	else
		loginfo "All used network interfaces are known by kernel. Ok."
		if test -e "$job"
		then
			logdebug "Preventing ourself to be run later (useless)."
			logdebug "rm -f $job"
			# Make sure we're not called multiple time (even if it's harmless)
			[ -e "$job" ] && rm -f "$job"
		fi
		return 0
	fi
    done	
}

logstep "systemimager-check-ifaces: Check ip= cmdline network interfaces"
loginfo "Checking that interfaces sets in ip= cmdline parameter are seen by kernel"

if test -f /tmp/net.ifaces
then
	check_ifaces
else
	logdebug "/tmp/net.ifaces not yet present"
	return 1 # need to re-run.
fi

