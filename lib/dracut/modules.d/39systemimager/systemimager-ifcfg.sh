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
# This file is run by initqueue/online hook from dracut-initqueue service
# if network was successfully set up.
# It will save network and SIS informations in /tmp/variables.txt
# It is called with net interface as $1 argument.

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type save_netinfo >/dev/null 2>&1 || test -f /lib/net-lib.sh && . /lib/net-lib.sh
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

loginfo "==== systemimager-ifcfg ===="

# initqueue/online hook passes interface name as $1
netif="$1"

# make sure we get ifcfg for every interface that comes up
type save_netinfo >/dev/null 2>&1 && save_netinfo $netif

loginfo "USING net interface: [$netif]"
if test -n "$netif"
then
    IF_CONFIG=`ip -o addr show $netif`
    loginfo "$IF_CONFIG"
fi

DHCLIENT_DIR="/tmp"

if [ ! -f ${DHCLIENT_DIR}/dhclient.${netif}.lease ]; then
    warn "${DHCLIENT_DIR}/dhclient.${netif}.lease not found"
    shellout
fi


# read dhcp info in as variables -- this file will be created by 
# the /etc/dhcp/dhclient-exit-hooks script that is run automatically by
# dhclient.

if [ ! -f /tmp/dhcp_info.${netif} ] ; then
    logwarn "/tmp/dhcp_info.${netif} does not exists. Can't continue"
    shellout
fi

# Read the DHCLIENT variables
. /tmp/dhcp_info.${netif} || shellout


# Re-read configuration information from local.cfg to over-ride
# DHCP settings, if necessary. -BEF-
if [ -f /tmp/local.cfg ]; then
    loginfo "Overriding any DHCP or cmdline settings with pre-boot local.cfg settings."
    . /tmp/local.cfg || shellout
fi

# Read the cmdline variables overriding any local.cfg or DHCP parameters
loginfo "Overriding any DHCP settings with pre-boot settings from kernel append parameters."
test -f "$CMDLINE_VARIABLES" && . $CMDLINE_VARIABLES

# Save all needed variables to /tmp/variables.txt
write_variables

