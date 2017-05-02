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
test -z "$MONITOR_SERVER" && MONITOR_SERVER=`getarg -d MONITOR_SERVER -n rd.sis.monitor-server`

###############################
# rd.sis.monitor-port=<portnum>
test -z "$MONITOR_PORT" && MONITOR_PORT=`getarg rd.sis.monitor-port`
test -z "$MONITOR_PORT" && MONITOR_PORT=8181 # default value

############################################
# rd.sis.monitor-console=(bolean 0|1|yes|no)
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=`getarg MONITOR_CONSOLE`
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE=`getarg rd.sis.monitor-console`
test -z "$MONITOR_CONSOLE" && MONITOR_CONSOLE="n"

###########################################
# rd.sis.skip-local-cfg=(bolean 0|1|yes|no)
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=`getarg SKIP_LOCAL_CFG`
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG=`getarg rd.sis.skip-local-cfg`
test -z "$SKIP_LOCAL_CFG" && SKIP_LOCAL_CFG="n"

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
SEL_RELABEL=`echo $SEL_RELABEL | head -c 1 | tr 'Y' 'y'`
test -z "$SEL_RELABEL" && SEL_RELABEL="y" # default to true!
[ $SEL_RELABEL = '1' ] && SEL_RELABEL="y"

# Register what we read.
write_variables
