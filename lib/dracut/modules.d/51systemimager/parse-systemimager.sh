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
#      This file is the cmdline option parser hook. It stores the parsed options ini
#      /tmp/variables.txt for systemimager dracut module logic use.

# Tells bash we need bashisms (I/O redirection to subshell) by disabling stric
# posix mode.
set +o posix

# Redirect stdout and stderr to system log (that is later processed by log dispatcher)
exec 6>&1 7>&2      # Save file descriptors 1 and 2.
exec 2> >(logger -p local2.err -t systemimager)
exec > >(logger -p local2.info -t systemimager)

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type write_variables >/dev/null 2>&1 || . /lib/systemimager-lib.sh

################################################################################
#
# Read cmdline SIS relevant parameters

#########################
# si.debug (defaults:N)
DEBUG="n"
getargbool 0 si.debug && DEBUG="y" && logdebug "Got DEBUG=y"

logstep "parse-sis-options: parse cmdline parameters."
loginfo "Reading SIS relevants parameters from cmdline and store them in /tmp/variables.txt"

#####################################
# imaging config file (retreived using rync) Will overwrite cmdline variables.
# si.config="imagename.conf"
test -z "$SIS_CONFIG" && SIS_CONFIG=$(getarg si.config) && logdebug "Got SIS_CONFIG=${SIS_CONFIG}"

#####################################
# Name of image.
# si.image-name="imagename|imagename.sh|imagename.master"
test -z "$IMAGENAME" && IMAGENAME=$(getarg si.image-name -d IMAGENAME) && logdebug "Got IMAGENAME=${IMAGENAME}"

#####################################
# si.script-name="scriptname|scriptname.sh|scriptname.master"
test -z "$SCRIPTNAME" && SCRIPTNAME=$(getarg si.script-name -d SCRIPTNAME) && logdebug "Got SCRIPTNAME=${SCRIPTNAME}"

#####################################
# si.disks-layout="disklayout|disklayout.xml"
test -z "$DISKS_LAYOUT" && DISKS_LAYOUT=$(getarg si.disks-layout -d DISKS_LAYOUT) && logdebug "Got DISKS_LAYOUT=${DISKS_LAYOUT}"

#####################################
# si.network-config="netconfig|netconfig.xml"
test -z "$NETWORK_CONFIG" && NETWORK_CONFIG=$(getarg si.network-config -d NETWORK_CONFIG) && logdebug "Got NETWORK_CONFIG=${NETWORK_CONFIG}"

#####################################
# si.install-iface="eno2"
test -z "$INSTALL_IFACE" && INSTALL_IFACE=$(getarg si.install-iface -d INSTALL_IFACE) && logdebug "Got INSTALL_IFACE=${INSTALL_IFACE}"

#####################################
# si.dl-protocol="torrent|rsync|ssh|..."
test -z "$DL_PROTOCOL" && DL_PROTOCOL=$(getarg si.dl-protocol) && logdebug "Got DL_PROTOCOL=${DL_PROTOCOL}"

#####################################
# si.monitor-server=<hostname|ip>
test -z "$MONITOR_SERVER" && MONITOR_SERVER=$(getarg si.monitor-server -d MONITOR_SERVER) && logdebug "Got MONITOR_SERVER=${MONITOR_SERVER}"

###############################
# si.monitor-port=<portnum>
test -z "$MONITOR_PORT" && MONITOR_PORT=$(getargnum 8181 100 32000 si.monitor-port) && logdebug "Got MONITOR_PORT=${MONITOR_PORT}"

############################################
# si.monitor-console=(bolean 0|1|yes|no)
MONITOR_CONSOLE="n"
getargbool 0 MONITOR_CONSOLE && MONITOR_CONSOLE="y"
getargbool 0 si.monitor-console && MONITOR_CONSOLE="y" && logdebug "Got MONITOR_CONSOLE=${MONITOR_CONSOLE}"

###########################################
# si.skip-local-cfg=(bolean 0|1|yes|no)
SKIP_LOCAL_CFG="n"
getargbool 0 SKIP_LOCAL_CFG && SKIP_LOCAL_CFG="y"
getargbool 0 si.skip-local-cfg && SKIP_LOCAL_CFG="y" && logdebug "Got SKIP_LOCAL_CFG=${SKIP_LOCAL_CFG}"

###################################
# si.image-server=<hostname|ip>
test -z "$IMAGESERVER" && IMAGESERVER=$(getarg si.image-server -d IMAGESERVER) && logdebug "Got IMAGESERVER=${IMAGESERVER}"

#####################################################
# si.log-server-port=(port number) # default 8181
test -z "$LOG_SERVER_PORT" && LOG_SERVER_PORT=$(getargnum 514 100 32000 si.log-server-port) && logdebug "Got LOG_SERVER_PORT=${LOG_SERVER_PORT}"

###############################
# si.ssh-client=(bolean 0|1|yes|no|not present) Defaults to "n"
SSH="n"
getargbool 0 SSH && SSH="y"
getargbool 0 si.ssh-client && SSH="y" && logdebug "Got SSH=${SSH}"

###############################
# si.ssh-download-url="URL"
test -z "$SSH_DOWNLOAD_URL" && SSH_DOWNLOAD_URL=$(getarg si.ssh-download-url -d SSH_DOWNLOAD_URL) && logdebug "Got SSH_DOWNLOAD_URL=${SSH_DOWNLOAD_URL}"
test -n "$SSH_DOWNLOAD_URL" && SSH="y" && loginfo "Forced SSH=y becasue SSH_DOWNLOAD_URL is set" # SSH=y if we have a download url.
test -n "${SSH_DOWNLOAD_URL}" && test -z "${DL_PROTOCOL}" && DL_PROTOCOL="ssh" && loginfo "DL_PROTOCOL is empty. Default to 'ssh' beacause SSH_DOWNLOAD_URL is set."

###############################
# si.ssh-server=(bolean 0|1|yes|no|not present) => defaults to no
test -z "$SSHD" && SSHD=$(getarg si.ssh-server -d SSHD) && logdebug "Got SSHD=${SSHD}"

###############################
# si.ssh-user=<user used to initiate tunner on server>
test -z "$SSH_USER" && SSH_USER=$(getarg si.ssh-user -d SSH_USER) && logdebug "Got SSH_USER=${SSH_USER}"
[ "$SSH" = "y" ] && [ -z "$SSH_USER" ] && SSH_USER="root" && loginfo "SSH_USER in empty. Default to 'root'"

###############################################
# si.flamethrower-directory-portbase="path"
test -z "$FLAMETHROWER_DIRECTORY_PORTBASE" && FLAMETHROWER_DIRECTORY_PORTBASE=$(getarg si.flamethrower-directory-portbase) && logdebug "Got FLAMETHROWER_DIRECTORY_PORTBASE=${FLAMETHROWER_DIRECTORY_PORTBASE}"
test -n "$FLAMETHROWER_DIRECTORY_PORTBASE" && test -z "${DL_PROTOCOL}" && DL_PROTOCOL="flamethrower" && loginfo "DL_PROTOCOL is empty. Default to 'flamethrower' beacause FLAMETHROWER_DIRECTORY_PORTBSE is set."

#########################
# si.tmpfs-staging=""
test -z "$TMPFS_STAGING" && TMPFS_STAGING=$(getarg si.tmpfs-staging) && logdebug "Got TMPFS_STAGING=${TMPFS_STAGING}"

#########################
# si.term (Defaults to what system has defined or "linux" at last)
# priority: si.term then system-default then "linux"
OLD_TERM=${TERM}
TERM=$(getarg si.term) && logdebug "Got TERM=${TERM}"
test -z "${TERM}" && TERM=${OLD_TERM} && loginfo "si.term is empty or not set. Using default value [$OLD_TERM]."
test -z "${TERM}" -o "${TERM}" = "dumb" && TERM=linux && loginfo "No suitable TERM value. Using TERM=linux"

#########################
# si.selinux-relabel=(bolean 0|1|yes|no|y|n) => default to yes
SEL_RELABEL="y"
getargbool 1 si.selinux-relabel && SEL_RELABEL="y" && logdebug "Got SEL_RELABEL=y"

#########################
# si.post-action=(shell, reboot, shutdown) => default to reboot
SI_POST_ACTION=$(getarg si.post-action) && logdebug "Got SI_POST_ACTION=${SI_POST_ACTION}"
test -z "${SI_POST_ACTION}" && SI_POST_ACTION="reboot" && loginfo "SI_POST_ACTION is empty. Default to 'reboot'"

# Set a default value for protocol if it's still empty at this time.
test -z "${DL_PROTOCOL}" && DL_PROTOCOL="rsync" && loginfo "DL_PROTOCOL is empty. Default to 'rsync'"
# OL: Nothing about bittorrent?!?!

# Register what we read.
write_variables

# restore file descriptors so log subprocesses are stopped (read returns fail)
exec 1>&6 6>&- 2>&7 7>&-

# -- END --
