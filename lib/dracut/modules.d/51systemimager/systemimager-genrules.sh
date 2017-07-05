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
# This file is part of the old systemimager dracut module (version that lack
# online hook). It creates the systemimager udev rules to be triggered when
# network interface becomes online.

. /lib/dracut-lib.sh

logdebug "==== systemimager-genrules ===="

if [ -e "/sbin/systemimager-start" ]; then
        printf 'ACTION=="online", SUBSYSTEM=="net", RUN+="/sbin/initqueue --onetime /sbin/systemimager-start $env{INTERFACE}"\n' > /etc/udev/rules.d/70-systemimager.rules
else
        warn "systemimager-genrules: Could not find script to start systemimager. systemimager will not be started."
fi
