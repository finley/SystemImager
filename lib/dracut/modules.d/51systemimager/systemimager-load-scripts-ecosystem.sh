#!/bin/sh
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

. /lib/systemimager-lib.sh


logdebug "==== systemimager-get-scripts-ecosystem.sh ===="

test -z "${IMAGESERVER}" && shellout "IMAGESERVER not set; don't know where to download scripts logic from."

# systemimager-lib.sh will load appropriate download protocol that was setup in systemimager-parse-cmdline.sh
# the chosen protocol will implement the get_scripts_directory() function.
get_scripts_directory

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

ALT_CONFIG=`choose_filename /scripts/configs .conf`
if test -n "${SIS_CONFIG}" -a -f "/scripts/configs/${SIS_CONFIG}"
then
	loginfo "Loading /scripts/configs/${SIS_CONFIG}"
	. /scripts/configs/${SIS_CONFIG}
elif test -n "${ALT_CONFIG}"
then
	loginfo "Loading ${ALT_CONFIG}"
	. ${ALT_CONFIG}
else
	loginfo "No config available, using defaults"
fi

# Make sure HOSTNAME is set (may be used to guess main-install script name or disk layout file name".
# HOSTNAME may already be set via cmdline, dhcp or local.cfg
# If not, then try to get it from /scripts/hosts or DNS
if [ -z "$HOSTNAME" ]; then
    get_hostname_by_hosts_file
fi

if [ -z "$HOSTNAME" ]; then
    get_hostname_by_dns
fi

if [ -n "$HOSTNAME" ]; then
    loginfo "This hostname is: $HOSTNAME"
fi


# Save values
write_variables
