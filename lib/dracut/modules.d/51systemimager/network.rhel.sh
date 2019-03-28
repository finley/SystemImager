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
# This file hosts functions realted to rhel specific network configuration.
# Variable explanation here: /usr/share/doc/initscripts-*/sysconfig.txt
# TODO: DNS
# TODO: USERCTRL
# Vérifier default route variable nalme

_write_interface() {
	test ! -d /sysroot/etc/sysconfig/network-scripts && shellout "/etc/sysconfig/network-scripts not present in image."

	# Create the config file, removing all lines ending with "=" sign or empty value (="") (parameter not set don't need to be set)
	test -f /sysroot/etc/sysconfig/network-scripts/ifcfg-${IF_FULL_NAME} && logwarn "Overwriting /sysroot/etc/sysconfig/network-scripts/ifcfg-${IF_FULL_NAME}"
	sed -E '/.*=(|"")$/d' > /sysroot/etc/sysconfig/network-scripts/ifcfg-${IF_FULL_NAME} <<EOF
DEVICE=${IF_DEV_FULL_NAME}
HWADDR=${IF_HWADDR}
TYPE=${IF_TYPE}
ONBOOT=${IF_ONBOOT}
ONPARENT=${IF_ONPARENT}
BOOTPROTO=${IF_BOOTPROTO}
BONDING_MASTER=$(test "${IF_TYPE}" = "Bond" && echo "yes")
DEFROUTE=${IF_DEFROUTE}
IPV4_FAILURE_FATAL=${IF_IPV4_FAILURE_FATAL}
IPADDR=${IF_IPADDR}
NETMASK=${IF_NETMASK}
PREFIX=${IF_PREFIX}
BROADCAST=${IF_BROADCAST}
GATEWAY=${IF_GATEWAY}
IPV4_ROUTE_METRIC=
MTU=
PEERDNS=
DNS1=${IF_DNS1}
DNS2=${IF_DNS2}
DNS3=${IF_DNS3}
DOMAIN=${IF_DNS_SEARCH}
IPV6INIT=${IF_IPV6_INIT}
IPV6_FAILURE_FATAL=${IF_IPV6_FAILURE_FATAL}
IPV6_AUTOCONF=
IPV6ADDR=
IPV6_DEFAULTGW=
IPV6_DEFROUTE=
IPV6_MTU=
IPV6_PEERDNS=
NAME=${IF_FULL_NAME}
BONDING_OPTS="${IF_BONDING_OPTS}"
UUID=${IF_UUID}
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
