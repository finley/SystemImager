#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type write_variables >/dev/null 2>&1 || . /lib/systemimager-lib.sh

################################################################################
#
# Save cmdline SIS relevant parameters

loginfo "==== parse-sis-options-old ===="
loginfo "Reading SIS relevants parameters from cmdline"

#####################################
# rd.sis.monitor-server=<hostname|ip>
test -z "$MONITOR_SERVER" && MONITOR_SERVER=`getarg -d MONITOR_SERVER -n rd.sis.monitor-server`

###############################
# rd.sis.monitor-port=<portnum>
test -z "$MONITOR_PORT" && MONITOR_PORT=`getarg rd.sis.monitor-port`
test -z "$MONITOR_PORT" && MONITOR_PORT=8181 # default value

############################################
# rd.sis.monitor-console=(bolean 0|1|yes|no)
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=`getarg MONITOR_CONSOLE`
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=`getarg rd.sis.monitor-console`
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=0

###########################################
# rd.sis.skip-local-cfg=(bolean 0|1|yes|no)
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=`getarg SKIP_LOCAL_CFG`
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=`getarg rd.sis.skip-local-cfg`
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=0

###################################
# rd.sis.image-server=<hostname|ip>
test -z "$IMAGESERVER" && IMAGESERVER=`getarg IMAGESERVER`
test -z "$IMAGESERVER" && IMAGESERVER=`getarg rd.sis.image-server`

#####################################################
# rd.sis.log-server-port=(port number) # default 8181
test -z "$LOG_SERVER_PORT" && LOG_SERVER_PORT=`getarg rd.sis.log-server-port`
test -z "$LOG_SERVER_PORT" && LOG_SERVER_PORT=514

###############################
# rd.sis.ssh-download-url="URL"
test -z "$SSH_DOWNLOAD_URL" && SSH_DOWNLOAD_URL=`getarg rd.sis.ssh-download-url`

###############################################
# rd.sis.flamethrower-directory-portbase="path"
test -z "$FLAMETHROWER_DIRECTORY_PORTBASE" && FLAMETHROWER_DIRECTORY_PORTBASE=`getarg rd.sis.flamethrower-directory-portbase`

#########################
# rd.sis.tmpfs-staging=""
test -z "$TMPFS_STAGING" && TMPFS_STAGING=`getarg rd.sis.tmpfs-staging`

# Register what we read.
write_variables
