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
# This file is used in old dracut versions where initqueue/online hook doesn't exists.

. /lib/systemimager-lib.sh

logstep "systemimager-start: online-hook"

DEVICE=$1

source /sbin/parse-local-cfg                     # Parse local cfg and overrides cmdline. udev is started, so /dev/md and lvm are up.
source /sbin/systemimager-check-ifaces           # Check network interfaces concistence with cmdline ip=
source /sbin/systemimager-netstart $DEVICE       # finish network configuration (gateway, hostname, resolv.conf)
source /sbin/systemimager-load-network-infos $DEVICE  # read /tmp/dhclient.$DEVICE.dhcpopts or /tmp/net.$DEVICE.override and updates /tmp/variables.txt
source /sbin/systemimager-pingtest $DEVICE       # do a ping_test()
source /sbin/systemimager-load-scripts-ecosystem $DEVICE    # read $SIS_CONFIG from image server.
source /sbin/systemimager-monitor-server $DEVICE # Start the log monitor server
source /sbin/systemimager-deploy-client $DEVICE  # Imaging occures here
