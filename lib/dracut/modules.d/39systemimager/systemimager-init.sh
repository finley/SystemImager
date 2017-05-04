#!/bin/sh

# Make sure we're not called multiple time (even if it's harmless)
[ -e "$job" ] && rm "$job"

. /lib/systemimager-lib.sh
lognotice "==== systemimager-init ===="
# Init /run/systemimager directory
test ! -d /run/systemimager && mkdir -p /run/systemimager

# make /sbin/netroot happy when called by /lib/dracut/hooks/initqueue/setup_net_<iface>.sh
# If /sysroot/proc is present, it quits with exit status "ok" (sort of rootok)
test ! -d /sysroot/proc && mkdir -p /sysroot/proc

ARCH=`uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/`
loginfo "Detected ARCH=$ARCH"

# Keep track of ARCH
write_variables
