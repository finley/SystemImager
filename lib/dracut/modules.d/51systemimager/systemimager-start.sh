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

logdebug "==== systemimager-start ===="

DEVICE=$1

/sbin/systemimager-netstart $DEVICE       # finish network configuration (gateway, hostname, resolv.conf)
/sbin/systemimager-load-dhcpopts $DEVICE  # read /tmp/dhclient.$DEVICE.dhcpopts and updates /tmp/variables.txt
/sbin/systemimager-pingtest $DEVICE       # do a ping_test()
/sbin/systemimager-load-scripts-ecosystem $DEVICE    # read $SIS_CONFIG from image server.
/sbin/systemimager-monitor-server $DEVICE # Start the log monitor server
/sbin/systemimager-deploy-client $DEVICE  # Imaging occures here
