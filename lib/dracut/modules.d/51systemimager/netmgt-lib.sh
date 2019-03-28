#!/bin/bash
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

# Now load the distro specific lib that is aware on how to write
# The desired network configuration.
logdebug "Loading distro specific network configuration generator"
case "$(get_distro_vendor /sysroot)" in
	redhat|centos|fedora)
		logdebug "Using rhel generator."
		. /lib/network.rhel.sh
		;;
	debian|ubuntu)
		logdebug "Using debian generator."
		. /lib/network.debian.sh
		;;
	opensuse|suse)
		logdebug "Using suse generator."
		. /lib/network.suse.sh
		;;
	*)
		logwarn "Image has no /etc/os-release or similar identification file"
		logwarn "Can't determine distribution, thus:"
		logwarn "Don't know how to configure network for distro"
		;;
esac

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

	# Process network devices one by one
	local IFS=';'
	xmlstarlet sel -t -m 'config/if' -v "concat(@dev,';',@type)" -n ${NETWORK_CONFIG_FILE}  | sed '/^\s*$/d' |\
                while read IF_DEV IF_TYPE
		do
			# 1st, clear all variables from previous <if> processing.
			unset IF_NAME IF_ID IF_ONBOOT IF_ONPARENT IF_USERCTL IF_MASTER IF_NAME IF_ONBOOT IF_USERCTL IF_MASTER IF_BOOTPROTO IF_IPADDR IF_NETMASK IF_PREFIX IF_BROADCAST IF_GATEWAY IF_DEFROUTE IF_IP6_INIT IF_HWADDR IF_BONDING_OPTS IF_DNS_SERVERS IF_DNS_SEARCH IF_ID IF_ALIAS_NAME IF_UUID
			
			# Process primary for this interface (only one primary, so no while loop)

			# 2 steps: 1st we parse the XML, then we load the result in shell variables.
			# We need 2 steps because the here line will not honor IFS in right argument (sub process)
		        # except if we export it, which we don't want.
			# (<<< $() fails while <<< "$var" works)

			CNX=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/primary" -v "concat(@name,';',@onboot,';',@bootproto,';',@userctl,';',@master)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
			# Read ip parameters
			CNX_IP=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/primary/ip" -v "concat(@ipaddr,';',@netmask,';',@prefix,';',@broadcast,';',@gateway,';',@def_route)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
			# read ip6 parameters
			CNX_IP6=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/primary/ip6" -v "concat(@ip6init)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
			# read options
			CNX_OPTIONS=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/primary/options" -v "concat(@hwaddr,';',@bonding_opts)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
			# read dns infos
			CNX_DNS=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/primary/dns" -v "concat(@servers,';',@search)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')

			# We use hereline <<< bash feature to load variables.
			read IF_NAME IF_ONBOOT IF_BOOTPROTO IF_USERCTL IF_MASTER <<< "$CNX"
			read IF_IPADDR IF_NETMASK IF_PREFIX IF_BROADCAST IF_GATEWAY IF_DEFROUTE <<< "$CNX_IP"
			read IF_IP6_INIT <<< "$CNX_IP6"
			read IF_HWADDR IF_BONDING_OPTS <<< "$CNX_OPTIONS"
			read IF_DNS_SERVERS IF_DNS_SEARCH <<< "$CNX_DNS"

			_fix_if_parameters # Compute IF_FULL_NAME, IF_DEV_FULL_NAME, UUID, Simplify IPADDR/PREFIX/NETMASK

			if test -n "${IF_MASTER}"
			then
				_write_slave
			else
				_write_interface
			fi
			# Process aliases for this interface
			xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/alias" -v "concat(@id,';',@onparent,';',@bootproto,';',@userctl,';',@master)" -n ${NETWORK_CONFIG_FILE}  | sed '/^\s*$/d' |\
				while read IF_ID IF_ONPARENT IF_BOOTPROTO IF_USERCTL IF_MASTER
				do
					# 1st, clear all previous variables except those all aliases inherit (IF_NAME)
					unset IF_ONBOOT IF_BOOTPROTO IF_IPADDR IF_NETMASK IF_PREFIX IF_BROADCAST IF_GATEWAY IF_DEFROUTE IF_IP6_INIT IF_HWADDR IF_BONDING_OPTS IF_DNS_SERVERS IF_DNS_SEARCH IF_ALIAS_NAME IF_UUID
					test -z "${IF_NAME}" && shellout "No primary defined for device [${IF_DEV}]"
					# Read ip parameters
					ALIAS_IP=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/alias[@id=\"${IF_ID}\"]/ip" -v "concat(@ipaddr,';',@netmask,';',@prefix,';',@broadcast,';',@gateway,';',@def_route)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
					# read ip6 parameters
					ALIAS_IP6=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/alias[@id=\"${IF_ID}\"]/ip6" -v "concat(@ip6init)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
					# read options
					ALIAS_OPTIONS=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/alias[@id=\"${IF_ID}\"]/options" -v "concat(@hwaddr,';',@bonding_opts)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
					# read dns infos
					ALIAS_DNS=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/alias[@id=\"${IF_ID}\"]/dns" -v "concat(@servers,';',@search)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')

					read IF_IPADDR IF_NETMASK IF_PREFIX IF_BROADCAST IF_GATEWAY IF_DEFROUTE <<< "$ALIAS_IP"
					read IF_IP6_INIT <<< "$ALIAS_IP6"
					read IF_HWADDR IF_BONDING_OPTS <<< "$ALIAS_OPTIONS"
					read IF_DNS_SERVERS IF_DNS_SEARCH <<< "$ALIAS_DNS"

					_fix_if_parameters # Compute IF_FULL_NAME, IF_DEV_FULL_NAME, UUID, Simplify IPADDR/PREFIX/NETMASK

					if test -n "${IF_MASTER}"
					then
						_write_slave
					else
						_write_interface
					fi
				done
			# Process slaves for this interface
			xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/slave" -v "@name" -n ${NETWORK_CONFIG_FILE}  | sed '/^\s*$/d' |\
				while read IF_SLAVE_NAME
				do
					test "${IF_TYPE}" != "Bond" && shellout "Slave interface, but parent is not of type 'Bond'!"

					_fix_if_parameters # Compute IF_FULL_NAME, IF_DEV_FULL_NAME, UUID, Simplify IPADDR/PREFIX/NETMASK
					
					# check that if exists (using xmlstarlet)
					MY_MASTER=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_SLAVE_NAME}\"]/primary" -v "@master" -n ${NETWORK_CONFIG_FILE})
					test "${MY_MASTER}" != "${IF_FULL_NAME}" && logerror "Slave [$IF_SLAVE_NAME] doesn't list me [$IF_FULL_NAME]  as master."
				done
		done
}

_fix_if_parameters() {

	# TODO: check that IF_MASTER exists and is of type bond.
	# TODO: check that all slaves of IF_MASTER have the same type= whatever it is (except Bond)

	# Compute full connection name.
	test -z "${IF_NAME}" && IF_NAME=${IF_DEV} && logdebug "Using device name ($IF_DEV) as connection name"
	if test -n "${IF_ID}"
	then
		IF_FULL_NAME="${IF_NAME}:${IF_ID}"
		IF_DEV_FULL_NAME="${IF_DEV}:${IF_ID}"
		logdebug "Interface alias: using ($IF_DEV_FULL_NAME) as connection name"
	else
		IF_FULL_NAME="${IF_NAME}"
		IF_DEV_FULL_NAME="${IF_DEV}"
	fi

	# Check IP syntaxt (IPADDR, PREFIX, NETMASK)
	if test "${IF_IPADDR//[0-9\.]/}" = "/" -a -n "${IF_PREFIX}"
	then
		logerror "IP prefix specified in both ipaddr= and prefix= parameters for device ${IF_FULL_NAME}"
		logerror "Ignoring PREFIX; using ipaddr= with its prefix"
		PREFIX=""
	fi
	if test "${IF_IPADDR//[0-9\.]/}" = "/" -a -n "${IF_NETMASK}"
	then
		logerror "IP prefix specified in both ipaddr= and netmask= parameters for device ${IF_FULL_NAME}"
		logerror "Ignoring NETMASK; using ipaddr= with its prefix"
		NETMASK=""
	fi
	if test -n "${IF_PREFIX}" -a -n "${IF_NETMASK}"
	then
		logerror "IP prefix specified in both prefix= and netmask= parameters for device ${IF_FULL_NAME}"
		logerror "Ignoring NETMASK; using ipaddr= with its prefix"
		NETMASK=""
	fi

	test -z "${IF_UUID}" && IF_UUID=$(uuidgen) && logdebug "No UUID; generating one: $IF_UUID"
	
}

