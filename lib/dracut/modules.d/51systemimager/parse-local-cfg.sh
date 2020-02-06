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
#      This file reads settings from local.cfg if required and store config in
#      cmdline.d before network is setup by dracut initqueue logic.
#      It must be run after udev is started in order to have access to filesystems
#      that are lying on lvm or software raid devices. (udev will bring to life those
#      lvm and software raid devices).
# 

# Tells bash we need bashisms (I/O redirection to subshell) by disabling stric
# posix mode.
set +o posix

# Redirect stdout and stderr to system log (that is later processed by log dispatcher)
exec 6>&1 7>&2      # Save file descriptors 1 and 2.
exec 2> >( while read LINE; do logger -p local2.err -t systemimager -- "$LINE"; done )
exec > >( while read LINE; do logger -p local2.info -t systemimager -- "$LINE"; done )

type write_variables >/dev/null 2>&1 || . /lib/systemimager-lib.sh

# Look for local.cfg file
#   This code inspired by Ian McLeod <ian@valinux.com>

logstep "parse-local-cfg"

# Systemimager possible breakpoint
getarg 'si.break=parse-localcfg' && logwarn "Break parse-localcfg" && interactive_shell

if [ "${SKIP_LOCAL_CFG}" = "y" ]; then
    loginfo "Skipping local.cfg: option SKIP_LOCAL_CFG=y has been specified"
    return
fi

# Try with local.cfg directly from initrd.
if [ -f /local.cfg ]; then
    cp -f /local.cfg /tmp/local.cfg
fi

#
# BEGIN try hard drive
#
if [ ! -z "${LAST_ROOT}" ]; then
    loginfo "Checking for /local.cfg file on hard drive [${LAST_ROOT}]..."
    mkdir /last_root
    loginfo "Mounting hard drive [$LAST_ROOT] ..."
    mount $LAST_ROOT /last_root -o ro > /dev/null 2>&1
    if [ $? != 0 ]; then
        logwarn "FATAL: Couldn't mount hard drive!"
        logwarn "Your kernel must have all necessary block and filesystem drivers compiled in"
        logwarn "statically (not modules) in order to use a local.cfg on your hard drive.  The"
        logwarn "standard SystemImager kernel is modular, so you will need to compile your own"
        logwarn "kernel.  See the SystemImager documentation for details.  To proceed at this"
        logwarn "point, you will need to unset the LAST_ROOT append parameter by typing"
        logwarn "systemimager LAST_ROOT=, or similar, at your boot prompt.  This will not use"
        logwarn "the local.cfg file on your hard drive, but will still use one on a floppy."
        shellout "Can't access /last_root/local.cfg"
    fi

    if [ -f /last_root/local.cfg ]; then
        loginfo "Found /local.cfg on hard drive."
        loginfo "Copying /local.cfg settings to /tmp/local.cfg."
        cat /last_root/local.cfg >> /tmp/local.cfg || shellout "Can't save /last_root/local.cfg as /tmp/local.cfg"
    else
        loginfo "No /local.cfg on hard drive."
    fi
    loginfo "Unmounting hard drive..."
    umount /last_root || shellout "Failed to umount /last_root"
fi
# END try hard drive

### BEGIN try floppy ###
loginfo "Checking for floppy diskette."
loginfo 'YOU MAY SEE SOME "wrong magic" ERRORS HERE, AND THAT IS NORMAL.'
mkdir -p /run/media/floppy
mount /dev/fd0 /run/media/floppy -o ro > /dev/null 2>&1
if [ $? = 0 ]; then
    loginfo "Found floppy diskette."
    if [ -f /run/media/floppy/local.cfg ]; then
        loginfo "Found /local.cfg on floppy."
        loginfo "Copying /local.cfg settings to /tmp/local.cfg."
        loginfo "NOTE: local.cfg settings from a floppy will override settings from"
        loginfo "      a local.cfg file on your hard drive and DHCP."
        # We use cat instead of copy, so that floppy settings can
        # override hard disk settings. -BEF-
        cat /run/media/floppy/local.cfg >> /tmp/local.cfg || shellout
    else
        loginfo "No /local.cfg on floppy diskette."
    fi
else
    loginfo "No floppy diskette in drive."
fi
### END try floppy ###

### BEGIN try USB Key ###
# OL: BUG: Need to implement that for modernity. Who still use floppies?
### END try USB Key ###

# /tmp/local.cfg may be created from a local.cfg file on the hard drive, or a
# floppy an USB Key or directly in initrd. If more than one are used, settings
# priority is:
# USB key then floppy, then hard drive then initrd
if [ -f /tmp/local.cfg ]; then
    loginfo "Reading configuration from /tmp/local.cfg"
    . /tmp/local.cfg || shellout "Failed to read /tmp/local.cfg"
    if test -n "$IPADDR$GATEWAY$NETMASK$HOSTNAME$DEVICE"
    then # We have some IP settings to inject for 40network dracut module
        # Comvert /tmp/local.cfg to /etc/cmdline.d/00-network.conf
        CMDLINECONF=/etc/cmdline.d/00-network.conf
        if test ! -d /etc/cmdline.d
        then
            CMDLINECONF=/etc/cmdline
        fi
        loginfo "Adding following content to ${CMDLINECONF}"
        loginfo "ip=$IPADDR::$GATEWAY:$NETMASK:$HOSTNAME:$DEVICE:on"
        cat >> $CMDLINECONF <<EOF
ip=$IPADDR::$GATEWAY:$NETMASK:$HOSTNAME:$DEVICE:on
EOF
    fi
    write_variables # Update infos in /tmp/variables.txt
fi

# restore file descriptors so log subprocesses are stopped (read returns fail)
exec 1>&6 6>&- 2>&7 7>&-

# -- END --
