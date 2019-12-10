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
#      This file is run by mount hook from dracut-mount service
#      It'll mount /sysroot
#      It is required because $root can't be updated in parent dracut-initqueue.sh (or initqueue.sh)
#      /dracut-state.sh (or /root.info) is overwrittent with this script variables.
#      updating $root in initqueue/online (diffrent process) or initqueue/finished (sub process)
#      is futile. old fake $root value (set in cmdline hook) will always come back.
#

type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

logstep "systemimager-sysroot"

ROOT="$(getarg root=)"
ROOT="${ROOT#block:}" # Cleaup $ROOT from prepending block: keyword
ROOTFLAGS="$(getarg rootflags=),ro"
ROOTFLAGS="${ROOTFLAGS#,}"

test -n "${ROOT}" || shellout "\$ROOT is empty!"

# Get the real block device in case we have UUID= or LABEL= mountpoint type.
ROOT_BLKDEV=$(findfs "${ROOT}") || shellout "Can't find block device for [root=${ROOT}]"
logdebug "Using root real device: [$ROOT_BLKDEV]"

# Make sure $ROOT points to a block device at least.
test -b "${ROOT_BLKDEV}" || shellout "\$root is not a block device! [root=${ROOT}] [device=${ROOT_BLKDEV}]"

logdebug "Mounting [${ROOT}] on /sysroot"
mount -o ${ROOTFLAGS} ${ROOT} /sysroot || logwarn "Can't mount root=${ROOT} on /sysroot (error:$?)"

