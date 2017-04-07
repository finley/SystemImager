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
#type save_netinfo >/dev/null 2>&1 || . /lib/net-lib.sh
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

loginfo "==== systemimager-timeout ===="

# 1st: check if we got an IP address.
# We check that find_iface_with_link form net-lib.sh which returns 1st ethernet device with link
# was able to get an IPv4.
# BUG: We should test that we can ping $IMAGESERVER <OL>

IFACE_WITH_LINK=`get_1st_iface_with_link`
if test -z "$IFACE_WITH_LINK"
then
    logwarn "No physical network interface found. How did we get here????"
    shellout
else
    DEVICE=$IFACE_WITH_LINK
    loginfo "Found physical network interface $DEVICE. Updating /tmp/variables.txt"
    write_variables
fi

# 1st: try to gather all infos
for file in variables.txt cmdline.txt dhcp_info.${IFACE_WITH_LINK}
do
	test -r $file && . /tmp/$file
done

CONFIGURED_IFACE=`ip -o -4 addr show ${IFACE_WITH_LINK}`
echo "$CONFIGURED_IFACE" > /tmp/configured.iface
if test -z "$CONFIGURED_IFACE"
then
	logwarn "Failed to get an IP address for iface:${IFACE_WITH_LINK}"
	shellout
fi

logwarn "Unknown timeout. [$CONFIGURED_IFACE]"
shellout
