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

type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

logstep "systemimager-timeout"

# 1st: check if we got an IP address.

IFACE_WITH_LINK=`get_1st_iface_with_link`
if test -z "$IFACE_WITH_LINK"
then
    shellout "No physical network interface found. How did we get here????"
else
    DEVICE=$IFACE_WITH_LINK
    loginfo "Found physical network interface $DEVICE. Updating /tmp/variables.txt"
    write_variables
fi

CONFIGURED_IFACE=`ip -o -4 addr show ${IFACE_WITH_LINK}`
echo "$CONFIGURED_IFACE" > /tmp/configured.iface
if test -z "$CONFIGURED_IFACE"
then
	shellout "Failed to get an IP address for iface:${IFACE_WITH_LINK}"
fi

shellout "Unknown timeout. [$CONFIGURED_IFACE]"

