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
# This file is run by initqueue/timeout hook from dracut-initqueue service
# if a timeout occures in initqueue mainloop.
# One possible reason is that DHCP failed to get an IP address.

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type save_netinfo >/dev/null 2>&1 || . /lib/net-lib.sh
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

# 1st: check if we got an IP address.
# We check that find_iface_with_link form net-lib.sh which returns 1st ethernet device with link
# was able to get an IPv4.
# BUG: We should test that we can ping $IMAGESERVER <OL>

IFACE_WITH_LINK=`find_iface_with_link`

# 1st: try to gather all infos
for file in kernel_append_parameter_variables.txt dhcp_info.${IFACE_WITH_LINK} variables.txt
do
	test -r $file && . /tmp/$file
done

CONFIGURED_IFACE=`ip -o -4 addr show ${IFACE_WITH_LINK}`
echo "$CONFIGURED_IFACE" > /tmp/configured.iface
if test -z "$CONFIGURED_IFACE"
then
	logwarn "Failed to get an IP address"
	shellout
	exit 1
fi

logwarn "Unknown timeout. [$CONFIGURED_IFACE]"
shellout
exit 1
