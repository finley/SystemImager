#!/bin/sh
#
# "SystemImager" 
#
#  Copyright (C) 1999-2017 Brian Elliott Finley <brian@thefinleys.com>
#                     2017 Olivier Lahaye <olivier.lahaye@cea.fr>
#
#  $Id$
#  vi: set filetype=sh et ts=4:
#
#  Code written by Olivier LAHAYE.
#
# This file is run by cmdline hook from dracut-initqueue service
# It is called before parsing SIS command line options
# It checks that current kernel car run within this initrd environment.

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
    loginfo "#     - Kernel version: $(cat /proc/version)"
    loginfo "#     - Details       : $PRETTY_NAME"
    loginfo "######################################################################"
}

imager_welcome

logstep "systemimager-check-kernel: Check for initrd and kernel concistency."
check_kernel

