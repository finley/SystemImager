#!/bin/bash

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type write_variables >/dev/null 2>&1 || . /lib/systemimager-lib.sh

################################################################################
#
# Save cmdline SIS relevant parameters

logdebug "==== parse-sis-options ===="
loginfo "Reading SIS relevants parameters from cmdline and store them in /tmp/variables.txt"

#####################################
# rd.sis.image-name="imagename|imagename.sh|imagename.master"
test -z "$IMAGENAME" && IMAGENAME=$(getarg -d IMAGENAME -n rd.sis.image-name)

#####################################
# rd.sis.script-name="scriptname|scriptname.sh|scriptname.master"
test -z "$SCRIPTNAME" && SCRIPTNAME=$(getarg -d SCRIPTNAME -n rd.sis.script-name)

#####################################
# rd.sis.monitor-server=<hostname|ip>
test -z "$MONITOR_SERVER" && MONITOR_SERVER=$(getarg -d MONITOR_SERVER -n rd.sis.monitor-server)

###############################
# rd.sis.monitor-port=<portnum>
test -z "$MONITOR_PORT" && MONITOR_PORT=$(getargnum 8181 100 32000 rd.sis.monitor-port)

############################################
# rd.sis.monitor-console=(bolean 0|1|yes|no)
MONITOR_CONSOLE="n"
getargbool 0 MONITOR_CONSOLE && MONITOR_CONSOLE="y"
getargbool 0 rd.sis.monitor-console && MONITOR_CONSOLE="y"

###########################################
# rd.sis.skip-local-cfg=(bolean 0|1|yes|no)
SKIP_LOCAL_CFG="n"
getargbool 0 SKIP_LOCAL_CFG && SKIP_LOCAL_CFG="y"
getargbool 0 rd.sis.skip-local-cfg && SKIP_LOCAL_CFG="y"

###################################
# rd.sis.image-server=<hostname|ip>
test -z "$IMAGESERVER" && IMAGESERVER=$(getarg -d IMAGESERVER -n rd.sis.image-server)

#####################################################
# rd.sis.log-server-port=(port number) # default 8181
test -z "$LOG_SERVER_PORT" && LOG_SERVER_PORT=$(getargnum 514 100 32000 rd.sis.log-server-port)

###############################
# rd.sis.ssh-client=(bolean 0|1|yes|no|not present) Defaults to "n"
SSH="n"
getargbool 0 SSH && SSH="y"
getargbool 0 rd.sis.ssh-client && SSH="y"

###############################
# rd.sis.ssh-download-url="URL"
test -z "$SSH_DOWNLOAD_URL" && SSH_DOWNLOAD_URL=$(getarg -d SSH_DOWNLOAD_URL -n rd.sis.ssh-download-url)
test -n "$SSH_DOWNLOAD_URL" && SSH="y" # SSH=y if we have a download url.

###############################
# rd.sis.ssh-server=(bolean 0|1|yes|no|not present) => defaults to no
test -z "$SSHD" && SSHD=$(getarg -d SSHD -n rd.sis.ssh-server)

###############################
# rd.sis.ssh-user=<user used to initiate tunner on server>
test -z "$SSH_USER" && SSH_USER=$(getarg -d SSH_USER -n rd.sis.ssh-user)
[ "$SSH" = "y" ] && [ -z "$SSH_USER" ] && SSH_USER="root"

###############################################
# rd.sis.flamethrower-directory-portbase="path"
test -z "$FLAMETHROWER_DIRECTORY_PORTBASE" && FLAMETHROWER_DIRECTORY_PORTBASE=$(getarg rd.sis.flamethrower-directory-portbase)

#########################
# rd.sis.tmpfs-staging=""
test -z "$TMPFS_STAGING" && TMPFS_STAGING=$(getarg rd.sis.tmpfs-staging)

#########################
# rd.sis.term (Defaults to what system has defined or "linux" at last)
# priority: rd.sis.term then system-default then "linux"
OLD_TERM=${TERM}
TERM=$(getarg rd.sis.term)
test -z "${TERM}" && TERM=${OLD_TERM}
test -z "${TERM}" -o "${TERM}" = "dumb" && TERM=linux

#########################
# rd.sis.selinux-relabel=(bolean 0|1|yes|no|y|n) => default to yes
SEL_RELABEL="y"
getargbool 1 rd.sis.selinux-relabel && SEL_RELABEL="y"

#########################
# rd.sis.post-action=(shell, reboot, shutdown) => default to reboot
SIS_POST_ACTION=$(getarg rd.sis.post-action)
test -z "${SIS_POST_ACTION}" && SIS_POST_ACTION="reboot"

# Register what we read.
write_variables
