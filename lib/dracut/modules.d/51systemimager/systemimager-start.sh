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
#      This file is used in old dracut versions where initqueue/online hook doesn't exists.

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
