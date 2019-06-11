#!/bin/sh
# vi: set filetype=sh et ts=4:
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
# This file is the cmdline parser hook for old dracut. It parses the cmdline
# options and stores the result in /tmp/variables.txt

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type write_variables >/dev/null 2>&1 || . /lib/systemimager-lib.sh

################################################################################
#
# Save cmdline SIS relevant parameters

#########################
# si.debug (defaults:N)
test -z "$DEBUG" && DEBUG=`getarg si.debug`
[ $? -eq 0 ] && [ -z "${DEBUG}" ] && DEBUG="y" # true if parameter present with no value.
DEBUG=`echo $DEBUG | head -c 1| tr 'YN10' 'ynyn'` # Cleann up to end with one letter y/n
test -z "$DEBUG" && DEBUG="n" # Defaults to no.

logdebug "==== parse-sis-options-old ===="
loginfo "Reading SIS relevants parameters from cmdline"

#####################################
# imaging config file (retreived using rync) Will overwrite cmdline variables.
# si.config="imagename.conf"
test -z "$SIS_CONFIG" && SIS_CONFIG=`getarg si.config`

#####################################
# si.image-name="imagename|imagename.sh|imagename.master"
test -z "$IMAGENAME" && IMAGENAME=`getarg IMAGENAME`
test -z "$IMAGENAME" && IMAGENAME=`getarg si.image-name`

#####################################
# si.script-name="scriptname|scriptname.sh|scriptname.master"
test -z "$SCRIPTNAME" && SCRIPTNAME=`getarg SCRIPTNAME`
test -z "$SCRIPTNAME" && SCRIPTNAME=`getarg si.script-name`

#####################################
# si.disks-layout="diskslayout|diskslayout.xml"
test -z "$DISKS_LAYOUT" && DISKS_LAYOUT=`getarg DISKS_LAYOUT`
test -z "$DISKS_LAYOUT" && DISKS_LAYOUT=`getarg si.disks-layout`

#####################################
# si.network-config="netconfig|netconfig.xml"
test -z "$NETWORK_CONFIG" && NETWORK_CONFIG=`getarg NETWORK_CONFIG`
test -z "$NETWORK_CONFIG" && NETWORK_CONFIG=`getarg si.network-config`

#####################################
# si.dl-protocol="torrent|rsync|ssh|..."
test -z "$DL_PROTOCOL" && DL_PROTOCOL=`getarg si.dl-protocol`

#####################################
# si.monitor-server=<hostname|ip>
test -z "$MONITOR_SERVER" && MONITOR_SERVER=`getarg MONITOR_SERVER`
test -z "$MONITOR_SERVER" && MONITOR_SERVER=`getarg si.monitor-server`

###############################
# si.monitor-port=<portnum>
test -z "$MONITOR_PORT" && MONITOR_PORT=`getarg si.monitor-port`
test -z "$MONITOR_PORT" && MONITOR_PORT=8181 # default value

############################################
# si.monitor-console=(bolean 0|1|yes|no)
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=`getarg MONITOR_CONSOLE`
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=`getarg si.monitor-console`
[ $? -eq 0 ] && [ -z "${MONITOR_CONSOLE}" ] && MONITOR_CONSOLE="y" # true if parameter present with no value.
MONITOR_CONSOLE=`echo $MONITOR_CONSOLE | head -c 1| tr 'YN10' 'ynyn'` # Cleann up to end with one letter y/n
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE="n"

###########################################
# si.skip-local-cfg=(bolean 0|1|yes|no)
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=`getarg SKIP_LOCAL_CFG`
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=`getarg si.skip-local-cfg`
SKIP_LOCAL_CFG=`echo $SKIP_LOCAL_CFG | head -c 1| tr 'YN10' 'ynyn'` # Cleann up to end with one letter y/n
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG="n"

###################################
# si.image-server=<hostname|ip>
test -z "$IMAGESERVER" && IMAGESERVER=`getarg IMAGESERVER`
test -z "$IMAGESERVER" && IMAGESERVER=`getarg si.image-server`

#####################################################
# si.log-server-port=(port number) # default 8181
test -z "$LOG_SERVER_PORT" && LOG_SERVER_PORT=`getarg si.log-server-port`
test -z "$LOG_SERVER_PORT" && LOG_SERVER_PORT=514

#####################################################
# si.ssh=(bolean 0|1|yes|no|not present) => defaults to "n"
test -z "$SSH" && SSH=`getarg SSH`
test -z "$SSH" && SSH=`getarg si.ssh-client`
[ $? -eq 0 ] && [ -z "${SSH}" ] && SSH="y" # true if parameter present with no value.
SSH=`echo $SSH | head -c 1| tr 'YN10' 'ynyn'` # Cleann up to end with one letter y/n
test -z "$SSH" && SSH="n" # Defaults to no.

###############################
# si.ssh-download-url="URL"
test -z "$SSH_DOWNLOAD_URL" && SSH_DOWNLOAD_URL=`getarg SSH_DOWNLOAD_URL`
test -z "$SSH_DOWNLOAD_URL" && SSH_DOWNLOAD_URL=`getarg si.ssh-download-url`
test -n "$SSH_DOWNLOAD_URL" && SSH="y" # SSH=y if we have a download url.
test -n "$SSH_DOWNLOAD_URL" && test -z "${DL_PROTOCOL}" && DL_PROTOCOL="ssh"

###############################
# si.ssh-server=(bolean 0|1|yes|no|not present) => defaults to no
test -z "$SSHD" && SSHD=`getarg SSHD`
test -z "$SSHD" && SSHD=`getarg si.ssh-server`
SSHD=`echo $SSHD | head -c 1| tr 'YN10' 'ynyn'` # Cleann up to end with one letter y/n
test -z "$SSHD" && SSHD="n" # Defaults to no.

###############################
# si.ssh-user=<user used to initiate tunner on server>
test -z "$SSH_USER" && SSH_USER=`getarg SSH_USER`
test -z "$SSH_USER" && SSH_USER=`getarg si.ssh-user`
[ "$SSH" = "y" ] && [ -z "$SSH_USER" ] && SSH_USER="root"

###############################################
# si.flamethrower-directory-portbase="path"
test -z "$FLAMETHROWER_DIRECTORY_PORTBASE" && FLAMETHROWER_DIRECTORY_PORTBASE=`getarg si.flamethrower-directory-portbase`
test -n "$FLAMETHROWER_DIRECTORY_PORTBASE" && test -z "${DL_PROTOCOL}" && DL_PROTOCOL="flamethrower"

#########################
# si.tmpfs-staging=""
test -z "$TMPFS_STAGING" && TMPFS_STAGING=`getarg si.tmpfs-staging`

#########################
# si.term (Defaults to what system has defined or "linux" at last)
# priority: si.term then system-default then "linux"
OLD_TERM=${TERM}
TERM=`getarg si.term`
test -z "${TERM}" && TERM=${OLD_TERM}
test -z "${TERM}" -o "${TERM}" = "dumb" && TERM=linux

#########################
# si.selinux-relabel=(bolean 0|1|yes|no) => default to yes
test -z "$SEL_RELABEL" && SEL_RELABEL=`getarg si.selinux-relabel`
SEL_RELABEL=`echo $SEL_RELABEL | head -c 1 | tr 'YN10' 'ynyn'`
test -z "$SEL_RELABEL" && SEL_RELABEL="y" # default to true!

#########################
# si.post-action=(shell, reboot, shutdown) => default to reboot
SI_POST_ACTION=`getarg si.post-action`
test -z "${SI_POST_ACTION}" && SI_POST_ACTION="reboot"

# Set a default value for protocol if it's still empty at this time.
test -z "${DL_PROTOCOL}" && DL_PROTOCOL="rsync" && loginfo "DL_PROTOCOL is empty. Default to 'rsync'"
# OL: Nothing about bittorrent?!?!

# Early stage: Make sure HOSTNAME is coherent.
test "$HOSTNAME" = "(none)" && HOSTNAME="localhost" # Make sure we have coherent hostname.

# Register what we read.
write_variables
