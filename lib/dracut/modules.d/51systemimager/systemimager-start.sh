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
#      This file is used in new dracut versions.
#      initqueue/online is called for all ifaces that are setup.
#      we want to be callec only once. (1st co figured interface wins)


# Tells bash we need bashisms (I/O redirection to subshell) by disabling stric
# posix mode.
set +o posix

. /lib/systemimager-lib.sh # Load /tmp/variables.txt and some macros
#
# At this step, /tmp/variables.txt is read.


# Redirect stdout and stderr to system log (that is later processed by log dispatcher)
exec 6>&1 7>&2      # Save file descriptors 1 and 2.
exec 2> >(logger -p local2.err -t systemimager)
exec > >(logger -p local2.info -t systemimager)
#exec 2> >( while read LINE; do logger -p local2.err -t systemimager -- "$LINE"; done )
#exec > >( while read LINE; do logger -p local2.info -t systemimager -- "$LINE"; done )

# 1st: read local.cfg (This needs to be here in case it includes INSTALL_IFACE=
# It will be called for each iface to setup, but it'll run only once (protected)
source /sbin/parse-local-cfg                     # Parse local cfg and overrides cmdline. udev is started, so /dev/md and lvm are up.

# Case 1: If INSALL_IFACE is set and not the correct one, then return.
# Case 2: Else (if INSTALL_IFACE is not set), if DEVICE is set and not the same as $1, give up (we already loaded another interface)

if test -n "$INSTALL_IFACE" -a "$INSTALL_IFACE" != "$1" # Case 1
then
	loginfo "Install interface set to [$INSTALL_IFACE]. Ignoring interface [$1] for imaging."
	# restore file descriptors so log subprocesses are stopped (read returns fail)

	# At this point, either INSTALL_IFACE is set and equal to $1 (and DEVICE is empty and need to be filled), OR it is not set at all and DEVICE may be already set.

elif test -n "$DEVICE"
then
	loginfo "Install interface already chosen: [$DEVICE]. Ignoring interface [$1] for imaging."
	# restore file descriptors so log subprocesses are stopped (read returns fail)
else

	# If we reach this point, this means that either INSTALL_IFACE is the correct one if it is set or (if it is not set), DEVICE is still empty and we need to load something.


	logstep "systemimager-start: online-hook"

	DEVICE=$1
	write_variables # Save this network device as the chosen one.

	source /sbin/systemimager-check-ifaces           # Check network interfaces concistency with cmdline ip=
	source /sbin/systemimager-load-network-infos $DEVICE  # read /tmp/dhclient.$DEVICE.dhcpopts or /tmp/net.$DEVICE.override and updates /tmp/variables.txt
	source /sbin/systemimager-pingtest $DEVICE       # do a ping_test()
	source /sbin/systemimager-load-scripts-ecosystem $DEVICE    # read $SIS_CONFIG from image server.
	source /sbin/systemimager-monitor-server $DEVICE # Start the log monitor server (after reading config retrieved above)
	source /sbin/systemimager-deploy-client $DEVICE  # Imaging occures here

fi

# restore file descriptors so log subprocesses are stopped (read returns fail)
exec 1>&6 6>&- 2>&7 7>&-

# -- END --
