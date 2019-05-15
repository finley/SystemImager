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

# Systemimager possible breakpoint
getarg 'si.break=download-scripts' && logwarn "Break download-scripts" && interactive_shell

test -z "${IMAGESERVER}" && shellout "IMAGESERVER not set; don't know where to download scripts logic from."

# Create a ramfs filesystem for /scripts so we can bind mount it later in order to expose it to a chrooted environment in /sysroot
# (On CentOS-6, bind-mounting subtrees of the initrd.img fails)
# Bonus: we can umount /scripts when imaging is done, thus freeing some memory (initrd is not freed as it is used for shutdown)
# We use ramfs instead of tmpfs as it grows when needed. This avoid requiring a /script size computation before downloading its content.

logdebug "Creating ${SCRIPTS_DIR} mountpoint."
mkdir -p ${SCRIPTS_DIR} || shellout "Failed to create ${SCRIPTS_DIR}"

logdebug "Creating ${SCRIPTS_DIR} ramfs filesystem."
mount -t ramfs ramfs ${SCRIPTS_DIR} || shellout "Failed to create ramfs filesystem for ${SCRIPTS_DIR}"

# systemimager-lib.sh will load appropriate download protocol that was setup in systemimager-parse-cmdline.sh
# the chosen protocol will implement the get_scripts_directory() function.
get_scripts_directory

# Make sure HOSTNAME is set (may be used to guess main-install script name or disk layout file name".
# HOSTNAME may already be set via cmdline, dhcp or local.cfg
# If not, then try to get it from /scripts/hosts or DNS
if [ -z "$HOSTNAME" ]; then
    get_hostname_by_hosts_file # From ${SCRIPTS_DIR}/hosts
fi

if [ -z "$HOSTNAME" ]; then
    get_hostname_by_dns
fi

if [ -n "$HOSTNAME" ]; then
    loginfo "This hostname is: $HOSTNAME"
fi

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
ALT_CONFIG=`choose_filename ${SCRIPTS_DIR}/configs .conf`
if test -n "${SIS_CONFIG}" -a -f "${SCRIPTS_DIR}/configs/${SIS_CONFIG}"
then
	loginfo "Loading ${SCRIPTS_DIR}/configs/${SIS_CONFIG}"
	. ${SCRIPTS_DIR}/configs/${SIS_CONFIG}
elif test -n "${ALT_CONFIG}"
then
	loginfo "Loading ${ALT_CONFIG}"
	. ${ALT_CONFIG}
else
	loginfo "No config available, using defaults"
fi
[ "$OLD_POST_ACTION" != "$SI_POST_ACTION" ] && loginfo "New SI_POST_ACTION read from config ${SIS_CONFIG}. New action after imaging: $SI_POST_ACTION."

# Save values
write_variables
