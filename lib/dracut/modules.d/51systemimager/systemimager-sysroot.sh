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

if test -n "${ROOT}" -a -b ${ROOT}
then
	mount -o ${ROOTFLAGS} ${ROOT} /sysroot || warn "Can't mount root=${ROOT} on /sysroot (error:$?)"
else
	warn "Can't mount root=${ROOT} on /sysroot . [${ROOT}] is not a block device!"
fi
