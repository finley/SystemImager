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
# This file is part of the systemimager old dracut logic that lacks online hook.
# This file is called by udev rule when network is setup.

# Network environment (hostname, gateway, resolv.conf) is setup in /sbin/netroot script.
# As we don't have a netroot, we need to do that ourselves.
# We just handle the $netif=$1 interface.
# Code inspired from /sbin/netroot

. /lib/systemimager-lib.sh
logdebug "==== systemimager-netstart ===="

netif=$1

# Check that the interface is up.
[ -e "/tmp/net.$netif.up" ] || shellout "Net interface $netif not up."

# Setup Network environment.
[ -e "/tmp/net.$netif.gw" ]          && . /tmp/net.$netif.gw
[ -e "/tmp/net.$netif.hostname" ]    && . /tmp/net.$netif.hostname
[ -e "/tmp/net.$netif.resolv.conf" ] && cp -f /tmp/net.$netif.resolv.conf /etc/resolv.conf

# Load interface options
[ -e "/tmp/net.$netif.override" ] && . /tmp/net.$netif.override

