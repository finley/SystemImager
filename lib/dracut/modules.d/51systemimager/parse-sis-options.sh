#!/bin/sh
# vi: set filetype=sh et ts=4:

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type write_variables >/dev/null 2>&1 || . /lib/systemimager-lib.sh

################################################################################
#
# Read cmdline SIS relevant parameters

#########################
# rd.sis.debug (defaults:N)
DEBUG="n"
getargbool 0 rd.sis.debug && DEBUG="y" && logdebug "Got DEBUG=y"

logdebug "==== parse-sis-options ===="
loginfo "Reading SIS relevants parameters from cmdline and store them in /tmp/variables.txt"

#####################################
# rd.sis.image-name="imagename|imagename.sh|imagename.master"
test -z "$IMAGENAME" && IMAGENAME=$(getarg rd.sis.image-name -d IMAGENAME) && logdebug "Got IMAGENAME=${IMAGENAME}"

#####################################
# rd.sis.script-name="scriptname|scriptname.sh|scriptname.master"
test -z "$SCRIPTNAME" && SCRIPTNAME=$(getarg rd.sis.script-name -d SCRIPTNAME) && logdebug "Got SCRIPTNAME=${SCRIPTNAME}"

#####################################
# rd.sis.monitor-server=<hostname|ip>
test -z "$MONITOR_SERVER" && MONITOR_SERVER=$(getarg rd.sis.monitor-server -d MONITOR_SERVER) && logdebug "Got MONITOR_SERVER=${MONITOR_SERVER}"

###############################
# rd.sis.monitor-port=<portnum>
test -z "$MONITOR_PORT" && MONITOR_PORT=$(getargnum 8181 100 32000 rd.sis.monitor-port) && logdebug "Got MONITOR_PORT=${MONITOR_PORT}"

############################################
# rd.sis.monitor-console=(bolean 0|1|yes|no)
MONITOR_CONSOLE="n"
getargbool 0 MONITOR_CONSOLE && MONITOR_CONSOLE="y"
getargbool 0 rd.sis.monitor-console && MONITOR_CONSOLE="y" && logdebug "Got MONITOR_CONSOLE=${MONITOR_CONSOLE}"

###########################################
# rd.sis.skip-local-cfg=(bolean 0|1|yes|no)
SKIP_LOCAL_CFG="n"
getargbool 0 SKIP_LOCAL_CFG && SKIP_LOCAL_CFG="y"
getargbool 0 rd.sis.skip-local-cfg && SKIP_LOCAL_CFG="y" && logdebug "Got SKIP_LOCAL_CFG=${SKIP_LOCAL_CFG}"

###################################
# rd.sis.image-server=<hostname|ip>
test -z "$IMAGESERVER" && IMAGESERVER=$(getarg rd.sis.image-server -d IMAGESERVER) && logdebug "Got IMAGESERVER=${IMAGESERVER}"

#####################################################
# rd.sis.log-server-port=(port number) # default 8181
test -z "$LOG_SERVER_PORT" && LOG_SERVER_PORT=$(getargnum 514 100 32000 rd.sis.log-server-port) && logdebug "Got LOG_SERVER_PORT=${LOG_SERVER_PORT}"

###############################
# rd.sis.ssh-client=(bolean 0|1|yes|no|not present) Defaults to "n"
SSH="n"
getargbool 0 SSH && SSH="y"
getargbool 0 rd.sis.ssh-client && SSH="y" && logdebug "Got SSH=${SSH}"

###############################
# rd.sis.ssh-download-url="URL"
test -z "$SSH_DOWNLOAD_URL" && SSH_DOWNLOAD_URL=$(getarg rd.sis.ssh-download-url -d SSH_DOWNLOAD_URL) logdebug "Got SSH_DOWNLOAD_URL=${SSH_DOWNLOAD_URL}"
test -n "$SSH_DOWNLOAD_URL" && SSH="y" && loginfo "Forced SSH=y becasue SSH_DOWNLOAD_URL is set" # SSH=y if we have a download url.

###############################
# rd.sis.ssh-server=(bolean 0|1|yes|no|not present) => defaults to no
test -z "$SSHD" && SSHD=$(getarg rd.sis.ssh-server -d SSHD) && logdebug "Got SSHD=${SSHD}"

###############################
# rd.sis.ssh-user=<user used to initiate tunner on server>
test -z "$SSH_USER" && SSH_USER=$(getarg rd.sis.ssh-user -d SSH_USER) && logdebug "Got SSH_USER=${SSH_USER}"
[ "$SSH" = "y" ] && [ -z "$SSH_USER" ] && SSH_USER="root" && loginfo "SSH_USER in empty. Default to 'root'"

###############################################
# rd.sis.flamethrower-directory-portbase="path"
test -z "$FLAMETHROWER_DIRECTORY_PORTBASE" && FLAMETHROWER_DIRECTORY_PORTBASE=$(getarg rd.sis.flamethrower-directory-portbase) && logdebug "Got FLAMETHROWER_DIRECTORY_PORTBASE=${FLAMETHROWER_DIRECTORY_PORTBASE}"

#########################
# rd.sis.tmpfs-staging=""
test -z "$TMPFS_STAGING" && TMPFS_STAGING=$(getarg rd.sis.tmpfs-staging) && logdebug "Got TMPFS_STAGING=${TMPFS_STAGING}"

#########################
# rd.sis.term (Defaults to what system has defined or "linux" at last)
# priority: rd.sis.term then system-default then "linux"
OLD_TERM=${TERM}
TERM=$(getarg rd.sis.term) && logdebug "Got TERM=${TERM}"
test -z "${TERM}" && TERM=${OLD_TERM} && loginfo "rd.sis.term is empty. Using default value ($OLD_TERM)"
test -z "${TERM}" -o "${TERM}" = "dumb" && TERM=linux && loginfo "No suitable TERM value. Using TERM=linux"

#########################
# rd.sis.selinux-relabel=(bolean 0|1|yes|no|y|n) => default to yes
SEL_RELABEL="y"
getargbool 1 rd.sis.selinux-relabel && SEL_RELABEL="y" && logdebug "Got SEL_RELABEL=y"

#########################
# rd.sis.post-action=(shell, reboot, shutdown) => default to reboot
SIS_POST_ACTION=$(getarg rd.sis.post-action) && logdebug "Got SIS_POST_ACTION=${SIS_POST_ACTION}"
test -z "${SIS_POST_ACTION}" && SIS_POST_ACTION="reboot" && loginfo "SIS_POST_ACTION is empty. Default to 'reboot'"

# Register what we read.
write_variables
