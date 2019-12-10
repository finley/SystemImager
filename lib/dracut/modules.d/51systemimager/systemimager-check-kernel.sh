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
#      This file is run by cmdline hook from dracut-initqueue service
#      It is called before parsing SIS command line options
#      It checks that current kernel car run within this initrd environment.
#

type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

KERNEL_VERSION=`uname -r`

################################################################################
#
#  check_kernel
#
check_kernel() {
    loginfo "Checking Kernel version and initrd modules version compatibility...."
    # 1st, check if running kernel has been built with loadable kernel modules option.
    if test -f /proc/modules
    then # We have loadable kernel modules.
        loginfo "Checking that /lib/modules/$KERNEL_VERSION/modules.dep is available"
        if test -f /lib/modules/$KERNEL_VERSION/modules.dep
        then
            loginfo "Kernel built with loadable modules and modules available in initrd."
        else
	    shellout "FATAL: initrd lacks /lib/modules/$KERNEL_VERSION/modules.dep. initrd/kernel missmatch?"
        fi
    else # Monolitic kernel, we assume it has everything to handle hardware.
        logwarn "Kernel built without loadable modules support. Not recommanded within a dracut environment"
	logwarn "Continuing anyway...."
    fi
}

imager_welcome() {
    . /etc/systemimager-release
    loginfo "######################################################################"
    loginfo "# Systemimager starting..."
    loginfo "#     - Imager version: $VERSION"
    loginfo "#     - Kernel version: $(uname -r)"
    loginfo "#     - Details       : $PRETTY_NAME"
    loginfo "######################################################################"
}

imager_welcome

logstep "systemimager-check-kernel: Check for initrd and kernel concistency."
check_kernel

