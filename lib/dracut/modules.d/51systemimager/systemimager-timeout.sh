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
#      This file is run by initqueue/timeout hook from dracut-initqueue service
#      if a timeout occures in initqueue mainloop.
#      One possible reason is that DHCP failed to get an IP address.

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

