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
#      This file is part of the old systemimager dracut module (version that lack
#      online hook). It creates the systemimager udev rules to be triggered when
#      network interface becomes online.

. /lib/systemimager-lib.sh

logstep "systemimager-genrules: initqueue/online hook creation."
logdebug "Adding udev rule for missing initqueue/online hook."
if [ -e "/sbin/systemimager-start" ]; then
        printf 'ACTION=="online", SUBSYSTEM=="net", RUN+="/sbin/initqueue --onetime /sbin/systemimager-start $env{INTERFACE}"\n' > /etc/udev/rules.d/70-systemimager.rules
else
        shellout "systemimager-genrules: Could not find script to start systemimager. systemimager will not be started."
fi
