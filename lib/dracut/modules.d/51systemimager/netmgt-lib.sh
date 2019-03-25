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
# This file hosts functions realted to network configuration.

# Load API and variables.txt (HOSTNAME, IMAGENAME, ..., including detected disks array: $DISKS)
type logmessage >/dev/null 2>&1 || . /lib/systemimager-lib.sh

################################################################################
#
# sis_configure_network()
#               Main function. Processes networkconfig.conf xml file to
#               configure client network.
################################################################################
#               
sis_configure_network() {
        if test -z "${NETWORK_CONF}"
        then
                NETWORK_CONF_FILE=`choose_filename /scripts/network-configs "" ".xml"`
        else
                NETWORK_CONF_FILE=/scripts/network-configs/${NETWORK_CONF}
                test ! -f "${NETWORK_CONF_FILE}" && NETWORK_CONF_FILE=/scripts/network-configs/${NETWORK_CONF}.xml
        fi
        if test ! -f "${NETWORK_CONF_FILE}"
        then
                logwarn "Could not get a valid network configuration file"
                test -n "${NETWORK_CONF_FILE}" && logerror "Tryed ${NETWORK_CONF_FILE}"
                logerror "Neiter NETWORK_CONFIG, HOSTNAME, IMAGENAME is set or"
                logerror "No group, group_override, base_hostname matches a network configuration file"
                logerror "Please read networkconfig.conf manual and create a network configuration file"
                logerror "Store it on image server in /var/lib/systemimager/scripts/network-conigs/"
                logerror "Use the one of possible names: {\$NETWORK_CONFIG,\$HOSTNAME,\$GROUPNAME,\$BASE_HOSTNAME,\$IMAGENAME,default}{,.xml}"
                logwarn "Can't configure client network. No network configuration file found."
        fi
	# BUG/TODO: default.xml is for disk layout and network layout: => conflict
        loginfo "Using network configuration file: ${NETWORK_CONIG_FILE}"
        write_variables # Save NETWORK_CONFIG_FILE variable for future use.

        # 1st, we need to validdate the network configuration file.
        loginfo "Validating network configuration: ${NETWORK_CONFIG_FILE}"
        xmlstarlet val --err --xsd /lib/systemimager/network-config.xsd ${NETWORK_CONFIG_FILE} || shellout "Network config file is invalid. Check error logs and fix problem."
        loginfo "Network configuration seems valid; continuing..."

	# 2nd, process bonding

	# 3rd, process network devices

}
