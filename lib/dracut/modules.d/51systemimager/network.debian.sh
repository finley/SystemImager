#!/bin/sh
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


# "${IF_DEV}" "${IF_TYPE}" "${IF_NAME}" "${IF_ONBOOT}" "${IF_USERCTL}" "${IF_BOOTPROTO}" "${IF_IPADDR}" "${IF_NETMASK}" "${IF_PREFIX}" "${IF_BROADCAST}" "${IF_GATEWAY}" "${IF_IP6_INIT}" "${IF_HWADDR}" "${IF_DNS_SERVERS}" "${IF_DNS_SERVERS}"
_write_interface() {
	test ! -d /sysroot/etc/network/interfaces && shellout "/etc/network/interfaces not present in image."

}
