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
	test ! -d /sysroot/etc/network/interfaces && shellout "/etc/network/interfaces not present in image."

# ${IF_DEV_FULL_NAME} ${IF_HWADDR} ${IF_TYPE} ${IF_ONBOOT} ${IF_ONPARENT} ${IF_BOOTPROTO} BONDING_MASTER=$(test "${IF_TYPE}" = "Bond" && echo "yes") ${IF_DEFROUTE} ${IF_IPV4_FAILURE_FATAL} ${IF_IPADDR} ${IF_NETMASK} ${IF_PREFIX} ${IF_BROADCAST} ${IF_GATEWAY} ${IF_IPV4_ROUTE_METRIC} ${IF_PEERDNS} ${IF_MTU} ${IF_DNS1} ${IF_DNS2} ${IF_DNS3} ${IF_DOMAIN} ${IF_IPV6_INIT} ${IF_IPV6_FAILURE_FATAL} ${IF_IPV6_AUTOCONF} ${IF_IPV6_ADDR} ${IF_IPV6_DEFAULTGW} ${IF_IPV6_DEFROUTE} ${IF_IPV6_PEERDNS} ${IF_IPV6_MTU} ${IF_IPV6_ROUTE_METRIC} ${IF_FULL_NAME} "${IF_BONDING_OPTS}" ${IF_UUID} ${IF_MASTER}

}
_write_slave() {
        test -n "${IF_BOOTPROTO/none/}" && logerror "bootproto must be none for a slave interface [${IF_NAME}]"
}

