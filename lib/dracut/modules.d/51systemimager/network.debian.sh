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
#      This file hosts functions realted to debian specific network configuration.
#

_check_network_config() {
	mkdir -p /tmp/ifcfg	# Make sure this directory exists before writing to it.
				# /tmp/ifcfg is scanned by 45ifcfg dracut module. All interfaces present in this
				# directory won't be taken into account by this module.
	case "${IF_CONTROL}" in
		legacy)
			#test ! -d /sysroot/etc/sysconfig/network-scripts && logwarn "/etc/sysconfig/network-scripts not present in image."
			#mkdir -p  /sysroot/etc/sysconfig/network-scripts # Make sure this path exists.
			;;
		NetworkManager)
			test ! -x /sysroot/usr/sbin/NetworkManager && shellout "/usr/sbin/NetworkManager unavailable in client. Network may not start!"
			#test ! -d /sysroot/etc/sysconfig/network-scripts && logwarn "/etc/sysconfig/network-scripts not present in image."
			#mkdir -p  /sysroot/etc/sysconfig/network-scripts # Make sure this path exists.
			;;
		systemd)
			test ! -x /sysroot/usr/bin/networkctl && shellout "/usr/bin/networkctl unavailable in client. Network may not start!"
			test ! -d /sysroot/etc/systemd/network/ && logwarn "/etc/systemd/network/ missing in client"
			;;
		*)
			shellout "BUG: xsd allows [${IF_CONTROL}] as network management mechanism but it is not handled by code. Please report!"
	esac
}

_write_primary() {
	_check_interface
	case "${IF_CONTROL}" in
		legacy|NetworkManager)
			;;
		systemd)
			;;
		*)
	esac
}

_write_alias() {
	_check_interface
	case "${IF_CONTROL}" in
		legacy) # Create specifi alias config file (ifcfg-<device>:<id>)
			;;
		NetworkManager)
			;;
		systemd)
			;;
		*)
	esac
}

_write_slave() {
	_check_interface
	case "${IF_CONTROL}" in
		legacy|NetworkManager)
			;;
		systemd)
			;;
		*)
	esac
}

_add_defroute() {
	test -z "$1" && shellout "You've hit a bug. _add_defroute must be called with ifname as argument."
	#test ! -f /sysroot/etc/sysconfig/network/ifcfg-${1} && shellout "You've hit a bug. Configuration file for $1 does not exists!"
	#if test -z "$(grep '^DEFROUTE=' /sysroot/etc/sysconfig/network/ifcfg-$1)"
	#then
	#	echo "DEFROUTE=yes" >> /sysroot/etc/sysconfig/network/ifcfg-${1}
	#else
	#	sed -i -e 's/^DEFROUTE=.*$/DEFROUTE=yes' /sysroot/etc/sysconfig/network/ifcfg-${1}
	#fi
}

