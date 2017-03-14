#!/bin/bash

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

################################################################################
#
# Variable-ize /proc/cmdline arguments
# Save cmdline SIS relevant parameters

loginfo "========================="
loginfo "Reading SIS relevants parameters from cmdline"

#####################################
# rd.sis.monitor-server=<hostname|ip>
test -z "$MONITOR_SERVER" && MONITOR_SERVER=$(getarg -d MONITOR_SERVER -n rd.sis.monitor-server)
test -n "$MONITOR_SERVER" && echo "MONITOR_SERVER=$MONITOR_SERVER         # rd.sis.monitor-server" >> $CMDLINE_VARIABLES

###############################
# rd.sis.monitor-port=<portnum>
test -z "$MONITOR_PORT" && MONITOR_PORT=$(getargnum 8181 100 32000 rd.sis.monitor-port)
test -n "$MONITOR_PORT" && echo "MONITOR_PORT=$MONITOR_PORT		# rd.sis.monitor-port" >> $CMDLINE_VARIABLES

############################################
# rd.sis.monotor-console=(bolean 0|1|yes|no)
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=$(getargbool 0 MONITOR_CONSOLE)
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=$(getargbool 0 rd.sis.monotor-console)
test -n "$MONITOR_CONSOLE" && echo "MONITOR_CONSOLE=$MONITOR_CONSOLE	# rd.sis.monotor-console" >> $CMDLINE_VARIABLES

###########################################
# rd.sis.skip-local-cfg=(bolean 0|1|yes|no)
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=$(getargbool 0 SKIP_LOCAL_CFG)
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=$(getargbool 0 rd.sis.skip-local-cfg)
test -n "$SKIP_LOCAL_CFG" && echo  "SKIP_LOCAL_CFG=$SKIP_LOCAL_CFG		# rd.sis.skip-local-cfg" >> $CMDLINE_VARIABLES
# read network settings from local.cfg if required and store config in cmdline.d before network is setup by dracut initqueue logic.
read_local_cfg

###################################
# rd.sis.image-server=<hostname|ip>
test -z "$IMAGESERVER" && IMAGESERVER=$(getarg -d IMAGESERVER -n rd.sis.image-server)
test -n "$IMAGESERVER" && echo "IMAGESERVER=$IMAGESERVER		# rd.sis.image-server" >> $CMDLINE_VARIABLES

#####################################################
# rd.sis.log-server-port=(port number) # default 8181
test -z "$LOG_SERVER_PORT" && LOG_SERVER_PORT=$(getargnum 514 100 32000 rd.sis.log-server-port)
test -n "$LOG_SERVER_PORT" && echo "LOG_SERVER_PORT=$LOG_SERVER_PORT	# rd.sis.log-server-port" >> $CMDLINE_VARIABLES

###############################
# rd.sis.ssh-download-url="URL"
test -z "$SSH_DOWNLOAD_URL" && SSH_DOWNLOAD_URL=$(getarg rd.sis.ssh-download-url)
test -n "$SSH_DOWNLOAD_URL" && echo "SSH_DOWNLOAD_URL=$SSH_DOWNLOAD_URL	# rd.sis.ssh-download-url" >> $CMDLINE_VARIABLES

###############################################
# rd.sis.flamethrower-directory-portbase="path"
test -z "$FLAMETHROWER_DIRECTORY_PORTBASE" && FLAMETHROWER_DIRECTORY_PORTBASE=$(getarg rd.sis.flamethrower-directory-portbase)
test -n "$FLAMETHROWER_DIRECTORY_PORTBASE" && echo "FLAMETHROWER_DIRECTORY_PORTBASE=$FLAMETHROWER_DIRECTORY_PORTBASE # rd.sis.flamethrower-directory-portbase" >> $CMDLINE_VARIABLES

#########################
# rd.sis.tmpfs-staging=""
test -z "$TMPFS_STAGING" && TMPFS_STAGING=$(getarg rd.sis.tmpfs-staging)
test -n "$TMPFS_STAGING" && echo "TMPFS_STAGING=$TMPFS_STAGING		# rd.sis.tmpfs-staging" >> $CMDLINE_VARIABLES

cat $CMDLINE_VARIABLES >&2

loginfo "$(cat $CMDLINE_VARIABLES)"

