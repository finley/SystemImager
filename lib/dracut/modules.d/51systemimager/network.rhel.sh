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

	# Compute full connection name.
	test -z "${IF_NAME}" && IF_NAME=${IF_DEV}
	if test -n "${IF_ID}"
	then
		IF_FULL_NAME="${IF_NAME}:${IF_ID}"
		IF_DEV_FULL_NAME="${IF_DEV}:${IF_ID}"
	else
		IF_FULL_NAME="${IF_NAME}"
		IF_DEV_FULL_NAME="${IF_DEV}"
	fi

	# Check IP syntaxt (IPADDR, PREFIX, NETMASK)
	if test "${IF_IPADDR//[0-9.]/}"="/" -a -n "${IF_PREFIX}"
	then
		logerror "IP prefix specified in both ipaddr= and prefix= parameters for device ${IF_FULL_NAME}"
		logerror "Ignoring PREFIX; using ipaddr= with its prefix"
		PREFIX=""
	fi
	if test "${IF_IPADDR//[0-9.]/}"="/" -a -n "${IF_NETMASK}"
	then
		logerror "IP prefix specified in both ipaddr= and netmask= parameters for device ${IF_FULL_NAME}"
		logerror "Ignoring NETMASK; using ipaddr= with its prefix"
		NETMASK=""
	fi
	if test -n "${IF_PREFIX}" -a -n "${IF_NETMASK}"
	then
		logerror "IP prefix specified in both prefix= and netmask= parameters for device ${IF_FULL_NAME}"
		logerror "Ignoring NETMASK; using ipaddr= with its prefix"
		NETMASK=""
	fi

	test -z "${IF_UUID}" && IF_UUID=$(uuidgen)

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
	test -f /sysroot/etc/sysconfig/network-scripts/ifcfg-${IF_NAME} && logwarn "Overwriting /sysroot/etc/sysconfig/network-scripts/${IF_NAME}"

	# TODO: check that IF_MASTER exists and is of type bond.
	# TODO: check that all slaves of IF_MASTER have the same type= whatever it is (except Bond)

	test -z "${IF_UUID}" && IF_UUID=$(uuidgen)

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
