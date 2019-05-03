#!/bin/bash
#  vi: set filetype=sh et ts=4:
#
# "SystemImager" 
#
#  Copyright (C) 1999-2017 Brian Elliott Finley <brian@thefinleys.com>
#                     2017 Olivier Lahaye <olivier.lahaye@cea.fr>
#
#  $Id$
#
#  Code written by Olivier LAHAYE.
#
# This file is run by cmdline-setteled hook from dracut-initqueue service
# It is called early in mainloop when network is being initialized
# It checks that /net.iface contains an existing iface (and crosscheck ip= in cmdline

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
		logerror "Available network interface(s) unknown by kernel: $(cd /sys/class/net/; echo *|sed 's/ *lo//')"
		shellout "Check your cmdline parameters and/or add missing driver to imager using si_mkbootpackage(8)"
	else
		logdebug "All used network interfaces are known by kernel. Ok."
		exit 0
	fi
    done	
}

logdebug "==== systemimager-check-ifaces ===="

if test -f /tmp/net.ifaces
then
	check_ifaces
else
	logdebug "/tmp/net.ifaces not yet present"
	exit 1 # need to re-run.
fi
