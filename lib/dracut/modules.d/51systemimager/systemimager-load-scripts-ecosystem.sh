#!/bin/bash
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
# This file is responsible to load optional config file from rsync

# Tells bash we need bashisms (I/O redirection to subshell) by disabling stric
# posix mode.
set +o posix

# Redirect stdout and stderr to system log (that is later processed by log dispatcher)
exec 6>&1 7>&2      # Save file descriptors 1 and 2.
exec 2> >( while read LINE; do logger -p local2.err -t systemimager "$LINE"; done )
exec > >( while read LINE; do logger -p local2.info -t systemimager "$LINE"; done )

. /lib/systemimager-lib.sh


logstep "systemimager-load-scripts-ecosystem: setup and download ${SCRIPTS_DIR}"

# Systemimager possible breakpoint
getarg 'si.break=download-scripts' && logwarn "Break download-scripts" && interactive_shell

if test -z "${IMAGESERVER}"
then
    logerror "Dont't know where to download scripts logic from."
    logerror "Either set IMAGESERVER in in cmdline (man systemimager.cmdline)"
    logerror "Or use DHCP option-140"
    shellout "IMAGESERVER not set"
fi

# systemimager-lib.sh will load appropriate download protocol that was setup in systemimager-parse-cmdline.sh
# the chosen protocol will implement the get_scripts_directory() function.
get_scripts_directory

# Make sure HOSTNAME is set (may be used to guess main-install script name or disk layout file name".
# HOSTNAME may already be set via cmdline, dhcp or local.cfg
# If not, then try to get it from /scripts/hosts or DNS
if [ "$HOSTNAME" = '(none)' ]; then
    HOSTNAME=""
fi
if [ -z "$HOSTNAME" ]; then
    get_hostname_by_hosts_file # From ${SCRIPTS_DIR}/hosts
fi

if [ -z "$HOSTNAME" ]; then
    get_hostname_by_dns
fi

if [ -z "$HOSTNAME" ]; then
    logwarn "Unable to guess HOSTNAME (looked for ip= cmdline parameter, DHCP, /scripts/hosts file, DNS)".
    HOSTNAME="localhost"
fi
loginfo "This hostname is: $HOSTNAME"

# Now that we have /scripts, look for /scripts/cluster.txt and
# initialize GROUPNAMES (can contain multiple groups) if cluster.txt exists.
get_group_name

# Now try to load apropriate config if present using the following priority (1 = most important):
# 1: ${SIS_CONFIG}
# 2: hostname
# 3: groupname
# 4: base_hostname
# 5: imagename (if defined outside config file)
# 6: default.cfg

OLD_POST_ACTION=$SI_POST_ACTION

SI_CONFIG_TO_LOAD=""

loginfo "Looking for imager configuration."
if test -n "${SIS_CONFIG}" -a -f "${SCRIPTS_DIR}/configs/${SIS_CONFIG}"
then
	loginfo "Using ${SCRIPTS_DIR}/configs/${SIS_CONFIG} as stated by si.config="
	SI_CONFIG_TO_LOAD="${SCRIPTS_DIR}/configs/${SIS_CONFIG}"
else
	loginfo "si.config= is not defined (see systemimager.cmdline(7) manual"
	loginfo "Trying to find a matching configuration."
	ALT_CONFIG=`choose_filename ${SCRIPTS_DIR}/configs .conf`
	if test -n "${ALT_CONFIG}"
	then
		loginfo "Found ${ALT_CONFIG}"
		SI_CONFIG_TO_LOAD="${ALT_CONFIG}"
	fi
fi

if test -n "$SI_CONFIG_TO_LOAD"
then
	loginfo "Loading $SI_CONFIG_TO_LOAD"
	. $SI_CONFIG_TO_LOAD
else
	loginfo "No config available, using defaults"
fi

[ "$OLD_POST_ACTION" != "$SI_POST_ACTION" ] && loginfo "New SI_POST_ACTION read from config ${SIS_CONFIG}. New action after imaging: $SI_POST_ACTION."

# Save values
write_variables

# restore file descriptors so log subprocesses are stopped (read returns fail)
exec 1>&6 6>&- 2>&7 7>&-

# -- END --
