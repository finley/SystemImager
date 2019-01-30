#!/bin/sh
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
# This file is run by mount hook from dracut-mount service
# It'll mount /sysroot

type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

logdebug "==== systemimager-sysroot ===="

ROOT="$(getarg root=)"
ROOTFLAGS="$(getarg rootflags=),ro"
ROOTFLAGS="${ROOTFLAGS#,}"

test -n "${ROOT}" || shellout "\$ROOT is empty!"

# Get the real block device in case we have UUID= or LABEL= mountpoint type.
ROOT_BLKDEV=$(findfs "${ROOT}") || shellout "Can't find block device for [root=${ROOT}]"
logdebug "Using root real device: [$ROOT_BLKDEV]"

# Make sure $ROOT points to a block device at least.
test -b "${ROOT_BLKDEV}" || shellout "\$root is not a block device! [root=${ROOT}] [device=${ROOT_BLKDEV}]"

logdebug "Mounting [${ROOT}] on /sysroot
mount -o ${ROOTFLAGS} ${ROOT} /sysroot || warn "Can't mount root=${ROOT} on /sysroot (error:$?)"

