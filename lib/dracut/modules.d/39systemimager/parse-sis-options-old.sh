#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type write_variables >/dev/null 2>&1 || . /lib/systemimager-lib.sh

################################################################################
#
# Save cmdline SIS relevant parameters

lognotice "==== parse-sis-options-old ===="
loginfo "Reading SIS relevants parameters from cmdline"

#####################################
# rd.sis.monitor-server=<hostname|ip>
test -z "$MONITOR_SERVER" && MONITOR_SERVER=`getarg MONITOR_SERVER`
test -z "$MONITOR_SERVER" && MONITOR_SERVER=`getarg rd.sis.monitor-server`

###############################
# rd.sis.monitor-port=<portnum>
test -z "$MONITOR_PORT" && MONITOR_PORT=`getarg rd.sis.monitor-port`
test -z "$MONITOR_PORT" && MONITOR_PORT=8181 # default value

############################################
# rd.sis.monitor-console=(bolean 0|1|yes|no)
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=`getarg MONITOR_CONSOLE`
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=`getarg rd.sis.monitor-console`
MONITOR_CONSOLE=`echo $MONITOR_CONSOLE | head -c 1| tr 'YN10' 'ynyn'` # Cleann up to end with one letter y/n
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE="n"

###########################################
# rd.sis.skip-local-cfg=(bolean 0|1|yes|no)
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=`getarg SKIP_LOCAL_CFG`
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=`getarg rd.sis.skip-local-cfg`
SKIP_LOCAL_CFG=`echo $SKIP_LOCAL_CFG | head -c 1| tr 'YN10' 'ynyn'` # Cleann up to end with one letter y/n
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG="n"

###################################
# rd.sis.image-server=<hostname|ip>
test -z "$IMAGESERVER" && IMAGESERVER=`getarg IMAGESERVER`
test -z "$IMAGESERVER" && IMAGESERVER=`getarg rd.sis.image-server`

#####################################################
# rd.sis.log-server-port=(port number) # default 8181
test -z "$LOG_SERVER_PORT" && LOG_SERVER_PORT=`getarg rd.sis.log-server-port`
test -z "$LOG_SERVER_PORT" && LOG_SERVER_PORT=514

#####################################################
# rd.sis.ssh=(bolean 0|1|yes|no|not present) => defaults to "n"
test -z "$SSH" && SSH=`getarg SSH`
test -z "$SSH" && SSH=`getarg rd.sis.ssh-client`
SSH=`echo $SSH | head -c 1| tr 'YN10' 'ynyn'` # Cleann up to end with one letter y/n
test -z "$SSH" && SSH="n" # Defaults to no.

###############################
# rd.sis.ssh-download-url="URL"
test -z "$SSH_DOWNLOAD_URL" && SSH_DOWNLOAD_URL=`getarg SSH_DOWNLOAD_URL`
test -z "$SSH_DOWNLOAD_URL" && SSH_DOWNLOAD_URL=`getarg rd.sis.ssh-download-url`
test -n "$SSH_DOWNLOAD_URL" && SSH="y" # SSH=y if we have a download url.

###############################
# rd.sis.ssh-server=(bolean 0|1|yes|no|not present) => defaults to no
test -z "$SSHD" && SSHD=`getarg SSHD`
test -z "$SSHD" && SSHD=`getarg rd.sis.ssh-server`
SSHD=`echo $SSHD | head -c 1| tr 'YN10' 'ynyn'` # Cleann up to end with one letter y/n
test -z "$SSHD" && SSHD="n" # Defaults to no.

###############################
# rd.sis.ssh-user=<user used to initiate tunner on server>
test -z "$SSH_USER" && SSH_USER=`getarg SSH_USER`
test -z "$SSH_USER" && SSH_USER=`getarg rd.sis.ssh-user`
[ "$SSH" = "y" ] && [ -z "$SSH_USER" ] && SSH_USER="root"

###############################################
# rd.sis.flamethrower-directory-portbase="path"
test -z "$FLAMETHROWER_DIRECTORY_PORTBASE" && FLAMETHROWER_DIRECTORY_PORTBASE=`getarg rd.sis.flamethrower-directory-portbase`

#########################
# rd.sis.tmpfs-staging=""
test -z "$TMPFS_STAGING" && TMPFS_STAGING=`getarg rd.sis.tmpfs-staging`

#########################
# rd.sis.term (Defaults to what system has defined or "linux" at last)
# priority: rd.sis.term then system-default then "linux"
OLD_TERM=${TERM}
TERM=`getarg rd.sis.term`
test -z "${TERM}" && TERM=${OLD_TERM}
test -z "${TERM}" -o "${TERM}" = "dumb" && TERM=linux

#########################
# rd.sis.selinux-relabel=(bolean 0|1|yes|no) => default to yes
test -z "$SEL_RELABEL" && SEL_RELABEL=`getarg rd.sis.selinux-relabel`
SEL_RELABEL=`echo $SEL_RELABEL | head -c 1 | tr 'YN10' 'ynyn'`
test -z "$SEL_RELABEL" && SEL_RELABEL="y" # default to true!

# Register what we read.
write_variables
