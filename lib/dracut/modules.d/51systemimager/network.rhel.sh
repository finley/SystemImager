#!/bin/bash
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
# This file hosts functions realted to debian specific network configuration.


_write_interface() {
	test ! -d /sysroot/etc/sysconfig/network-scripts && shellout "/etc/sysconfig/network-scripts not present in image."

	# Create the config file, removing all lines ending with "=" sign or empty value (="") (parameter not set don't need to be set)
	test -f /sysroot/etc/sysconfig/network-scripts/ifcfg-${IF_FULL_NAME} && logwarn "Overwriting /sysroot/etc/sysconfig/network-scripts/ifcfg-${IF_FULL_NAME}"
	sed -E '/.*=(|"")$/d' > /sysroot/etc/sysconfig/network-scripts/ifcfg-${IF_FULL_NAME} <<EOF
DEVICE=${IF_DEV_FULL_NAME}
HWADDR=${IF_HWADDR}
TYPE=${IF_TYPE}
BONDING_MASTER=$(test "${IF_TYPE}" = "Bond" && echo "yes")
BOOTPROTO=${IF_BOOTPROTO}
DEFROUTE=${IF_DEFROUTE}
IPV4_FAILURE_FATAL=yes
IPV6INIT=${IF_IP6_INIT}
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
NAME=${IF_FULL_NAME}
UUID=${IF_UUID}
ONBOOT=${IF_ONBOOT}
BONDING_OPTS="${IF_BONDING_OPTS}"
IPADDR=${IF_IPADDR}
NETMASK=${IF_NETMASK}
PREFIX=${IF_PREFIX}
BROADCAST=${IF_BROADCAST}
GATEWAY=${IF_GATEWAY}
IPV6_PEERDNS=yes
IPV6_PEERROUTES=yes
EOF
}

_write_slave() {
	test ! -d /sysroot/etc/sysconfig/network-scripts && shellout "/etc/sysconfig/network-scripts not present in image."
	test -f /sysroot/etc/sysconfig/network-scripts/ifcfg-${IF_NAME} && logwarn "Overwriting /sysroot/etc/sysconfig/network-scripts/ifcfg-${IF_NAME}"

	test -n "${IF_BOOTPROTO/none/}" && logerror "bootproto must be none for a slave interface [${IF_NAME}]"
	sed -E '/.*=(|"")$/d' > /sysroot/etc/sysconfig/network-scripts/ifcfg-${IF_NAME} <<EOF
CONNECTED_MODE=no
BOOTPROTO=none
TYPE=${IF_TYPE}
NAME=${IF_NAME}
UUID=${IF_UUID}
DEVICE=${IF_DEV}
ONBOOT=yes
MASTER=${IF_MASTER}
SLAVE=yes
EOF
}
