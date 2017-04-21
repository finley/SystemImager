#!/bin/bash

# Network environment (hostname, gateway, resolv.conf) is setup in /sbin/netroot script.
# As we don't have a netroot, we need to do that ourselves.
# We just handle the $netif=$1 interface.
# Code inspired from /sbin/netroot

. /lib/systemimager-lib.sh
lognotice "==== systemimager-netstart ===="

netif=$1

# Check that the interface is up.
[ -e "/tmp/net.$netif.up" ] || shellout "Net interface $netif not up."

# Setup Network environment.
[ -e "/tmp/net.$netif.gw" ]          && . /tmp/net.$netif.gw
[ -e "/tmp/net.$netif.hostname" ]    && . /tmp/net.$netif.hostname
[ -e "/tmp/net.$netif.resolv.conf" ] && cp -f /tmp/net.$netif.resolv.conf /etc/resolv.conf

# Load interface options
[ -e "/tmp/net.$netif.override" ] && . /tmp/net.$netif.override

