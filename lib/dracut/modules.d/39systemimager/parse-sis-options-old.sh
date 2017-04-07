#!/bin/bash

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

################################################################################
#
# Variable-ize /proc/cmdline arguments
# Save cmdline SIS relevant parameters

loginfo "==== parse-sis-options-old ===="
loginfo "Reading SIS relevants parameters from cmdline"

#####################################
# rd.sis.monitor-server=<hostname|ip>
test -z "$MONITOR_SERVER" && MONITOR_SERVER=$(getarg -d MONITOR_SERVER -n rd.sis.monitor-server)
test -n "$MONITOR_SERVER" && echo "MONITOR_SERVER=$MONITOR_SERVER         # rd.sis.monitor-server" >> $CMDLINE_VARIABLES

###############################
# rd.sis.monitor-port=<portnum>
test -z "$MONITOR_PORT" && MONITOR_PORT=$(getarg rd.sis.monitor-port)
test -z "$MONITOR_PORT" && MONITOR_PORT=8181 # default value
test -n "$MONITOR_PORT" && echo "MONITOR_PORT=$MONITOR_PORT		# rd.sis.monitor-port" >> $CMDLINE_VARIABLES

############################################
# rd.sis.monitor-console=(bolean 0|1|yes|no)
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=$(getarg MONITOR_CONSOLE)
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=$(getarg rd.sis.monitor-console)
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=0
test -n "$MONITOR_CONSOLE" && echo "MONITOR_CONSOLE=$MONITOR_CONSOLE	# rd.sis.monitor-console" >> $CMDLINE_VARIABLES

###########################################
# rd.sis.skip-local-cfg=(bolean 0|1|yes|no)
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=$(getarg SKIP_LOCAL_CFG)
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=$(getarg rd.sis.skip-local-cfg)
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=0
test -n "$SKIP_LOCAL_CFG" && echo  "SKIP_LOCAL_CFG=$SKIP_LOCAL_CFG		# rd.sis.skip-local-cfg" >> $CMDLINE_VARIABLES
# read network settings from local.cfg if required and store config in cmdline.d before network is setup by dracut initqueue logic.
read_local_cfg

# Force rootok=1
export netroot=none # Fake netroot
export rootok=1
export root=/dev/null

###################################
# rd.sis.image-server=<hostname|ip>
test -z "$IMAGESERVER" && IMAGESERVER=$(getarg IMAGESERVER)
test -z "$IMAGESERVER" && IMAGESERVER=$(getarg rd.sis.image-server)
test -n "$IMAGESERVER" && echo "IMAGESERVER=$IMAGESERVER		# rd.sis.image-server" >> $CMDLINE_VARIABLES

#####################################################
# rd.sis.log-server-port=(port number) # default 8181
test -z "$LOG_SERVER_PORT" && LOG_SERVER_PORT=$(getarg rd.sis.log-server-port)
test -z "$LOG_SERVER_PORT" && LOG_SERVER_PORT=514
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

