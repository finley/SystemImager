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
#      This file is run by cmdline hook from dracut-cmdline service
#      This file is responsible to initialize the systemimager dracut environment.
#      It sets up systemimager work environment and also sets some values to 
#      make dracut-cmdline happy when it has finisshed processing cmdline hooks
#      dracut-cmdline hook expect root= and rootok= to be set after all scripts are run.
#      it also expects netroot to be set on old versions otherwise network is not initialized.
#      at last some cmdline.d values are also set.

# Tells bash we need bashisms (I/O redirection to subshell) by disabling stric
# posix mode.
set +o posix

# Redirect stdout and stderr to system log (that is later processed by log dispatcher)
exec 6>&1 7>&2      # Save file descriptors 1 and 2.
exec 2> >( while read LINE; do logger -p local2.err -t systemimager "$LINE"; done )
exec > >( while read LINE; do logger -p local2.info -t systemimager "$LINE"; done )

. /lib/systemimager-lib.sh
logstep "systemimager-init: imager environment initialisation."

# Init /run/systemimager directory
#test ! -d /run/systemimager && mkdir -p /run/systemimager && logdebug "Created /run/systemimager"

# Create a ramfs filesystem for /scripts so we can bind mount it later in order to expose it to a chrooted environment in /sysroot
# (On CentOS-6, bind-mounting subtrees of the initrd.img fails)
# Bonus: we can umount /scripts when imaging is done, thus freeing some memory (initrd is not freed as it is used for shutdown)
# We use ramfs instead of tmpfs as it grows when needed. This avoid requiring a /script size computation before downloading its content.

logdebug "Creating ${SCRIPTS_DIR} mountpoint."
mkdir -p ${SCRIPTS_DIR} || shellout "Failed to create ${SCRIPTS_DIR}"

logdebug "Creating ${SCRIPTS_DIR} ramfs filesystem."
mount -t ramfs ramfs ${SCRIPTS_DIR} || shellout "Failed to create ramfs filesystem for ${SCRIPTS_DIR}"

# make /sbin/netroot happy when called by /lib/dracut/hooks/initqueue/setup_net_<iface>.sh
# If /sysroot/proc is present, it quits with exit status "ok" (sort of rootok)
test ! -d /sysroot/proc && mkdir -p /sysroot/proc && logdebug "Created /sysroot/proc to make setup_net_<iface>.sh happy"

ARCH=`uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/`
loginfo "Detected ARCH=$ARCH"

# Keep track of ARCH
write_variables

# We don't know yet the device of the real root (will know that when disks layout will have been processed)
# For now, we just put some values that will make dracut happy.

test -z "$root" && export root="UNSET"
export rootok="1"

# Now sets some cmdline.d values that are needed for dracut logic in our situation.
loginfo "Enabling emergency shell in case of failure."
loginfo "Enforcing network initialization..."
if [ -n "$DRACUT_SYSTEMD" ]
then
	cat > /etc/cmdline.d/systemimager.conf <<EOF
rd.shell
rd.neednet=1
rd.hostonly=0
EOF
else # Old distro (CentOS-6)
	cat >> /etc/cmdline <<EOF
rdshell
EOF
test -z "$netroot" && export netroot="UNSET" # Force network init on non systemd initramfs.
fi

loginfo "Setting up text console..."
# read already configured FONTS if any (i18n is run before us)
test -r /etc/sysconfig/i18n && . /etc/sysconfig/i18n # Old distro (CentOS-6)
test -r /etc/default/console-setup && . /etc/default/console-setup
test -r /etc/vconsole.conf && . /etc/vconsole.conf

# If cmdline did not configure ant font, then use our t850b
if test -z "${FONT}${SYSFONT}${FONTFACE}"
then
	loginfo "No font set in cmdline. using t850b."
	export SYSFONT=t850b
	export FONT=t850b
	test -d /etc/sysconfig && echo "SYSFONT=t850b" >> /etc/sysconfig/i18n
	test -d /etc/default && echo "FONTFACE=t850b" >> /etc/default/console-setup # TODO: need testing
	echo "FONT=t850b" >> /etc/vconsole.conf
else
	loginfo "Using user defined font from cmdline."
fi

# restore file descriptors so log subprocesses are stopped (read returns fail)
exec 1>&6 6>&- 2>&7 7>&-

# -- END --
