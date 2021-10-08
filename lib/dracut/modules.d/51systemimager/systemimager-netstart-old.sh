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
#      This file is part of the systemimager old dracut logic that lacks online hook.
#      This file is called by udev rule when network is setup.

# Network environment (hostname, gateway, resolv.conf) is setup in /sbin/netroot script.
# As we don't have a netroot, we need to do that ourselves.
# We just handle the $netif=$1 interface.
# Code inspired from /sbin/netroot

. /lib/systemimager-lib.sh
logstep "systemimager-netstart: load booted network informations."

netif=$1
loginfo "Loading network informations from [$netif] interface."

# Check that the interface is up.
[ -e "/tmp/net.$netif.up" ] || shellout "Net interface $netif not up."

# Setup Network environment.
[ -e "/tmp/net.$netif.gw" ]          && . /tmp/net.$netif.gw
[ -e "/tmp/net.$netif.hostname" ]    && . /tmp/net.$netif.hostname
[ -e "/tmp/net.$netif.resolv.conf" ] && cp -f /tmp/net.$netif.resolv.conf /etc/resolv.conf

# Load interface options
[ -e "/tmp/net.$netif.override" ] && . /tmp/net.$netif.override

