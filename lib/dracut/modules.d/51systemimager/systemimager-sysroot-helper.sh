#!/bin/bash
#
# "SystemImager"
#
#  Copyright (C) 1999-2018 Brian Elliott Finley <brian@thefinleys.com>
#  Copyright (C) 2018-2018 Olivier Lahaye <olivier.lahaye@cea.fr>
#
#  $Id$
#  vi: set filetype=sh et ts=4:
#
#  Code written by Olivier LAHAYE.
#
# This file is run by /init (old dracut)
# It'll help init to find root filesystem to mount

type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

logdebug "==== systemimager-sysroot-helper ===="

test -r /tmp/root.info && . /tmp/root.info
test -z "$NEWROOT" && NEWROOT=/sysroot
unset netroot

logdebug "Root filesysterm informations:"
logdebug "NEWROOT=$NEWROOT"
logdebug "root=$root"
logdebug "rflags=$rflags"
logdebug "fstype=$fstype"
