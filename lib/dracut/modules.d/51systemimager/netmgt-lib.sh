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

        if test -z "${NETWORK_CONFIG}"
        then
		loginfo "si.network-conf not provided. Trying to find a matching network configuration"
                NETWORK_CONFIG_FILE=`choose_filename /scripts/network-configs "" ".xml"`
        else
                NETWORK_CONFIG_FILE=/scripts/network-configs/${NETWORK_CONFIG}
                test ! -f "${NETWORK_CONFIG_FILE}" && NETWORK_CONFIG_FILE=/scripts/network-configs/${NETWORK_CONFIG}.xml
        fi
        if test ! -f "${NETWORK_CONFIG_FILE}"
        then
                logwarn "Could not get a valid network configuration file"
                test -n "${NETWORK_CONFIG_FILE}" && logwarn "Tryed ${NETWORK_CONFIG_FILE}"
                logwarn "No group, group_override, base_hostname matches a network configuration file"
                logwarn "Please read networkconfig.conf manual and create a network configuration file"
                logwarn "Store it on image server in /var/lib/systemimager/scripts/network-configs/"
                logwarn "Use one of possible names: {$NETWORK_CONFIG${NETWORK_CONFIG:+,}$HOSTNAME${HOSTNAME:+,}$GROUPNAME${GROUPNAME:+,}${HOSTNAME//[0-9]/}${HOSTNAME:+,}$IMAGENAME${IMAGENAME:+,}default}{,.xml}"
		loginfo "Using current imager network informations (ifrom device: $DEVICE) as fallback."
		# 1st: check if NetworkManager is present in image.
		if test -x /sysroot/usr/sbin/NetworkManager -o -x /sysroot/sbin/NetworkManager
		then
			logdebug "NetworkManager detected in imaged client. Enabling it for $DEVICE"
			IF_NM_CONTROLLED="yes"
			IF_CONTROL="NetworkManager"
		elif test -x /sysroot/usr/bin/networkctl
			logdebug "networkctl detected in imaged client. Enabling it for $DEVICE"
			IF_NM_CONTROLLED="no"
			IF_CONTROL="systemd"
		else
			logdebug "NetworkManager, nor sytemd-networkd were found in imaged client. Using legacy config for $DEVICE"
			IF_NM_CONTROLLED="no"
			IF_CONTROL="legacy"
		fi

		if test "$BOOTPROTO" = "dhcp"
		then
			IF_DEV=$DEVICE
			IF_NAME=$DEVICE
			IF_DEV=$DEVICE
			IF_BOOTPROTO=$BOOTPROTO
			IF_TYPE=Ethernet # TODO: check with /sys/class/net/eth0/type
			IF_ONBOOT=yes
			IF_IPV4_FAILURE_FATAL=yes # TODO: be smarter. (maybe we booted thru ipv6)
			IF_PEERDNS=yes
			IF_UUID=$(uuidgen)
			_write_primary # from network.<distro>.sh

			return
		else
			IF_DEV=$DEVICE
			IF_NAME=$DEVICE
			IF_DEV=$DEVICE
			IF_BOOTPROTO=$BOOTPROTO
			IF_TYPE=Ethernet # check with /sys/class/net/eth0/type
			IF_ONBOOT=yes
			IF_IPV4_FAILURE_FATAL=yes # TODO: be smarter. (maybe we booted thru ipv6)
			IF_PEERDNS=yes
			IF_UUID=$(uuidgen)
			IF_IPADDR=$IPADDR
			IF_NETMASK=$NETMASK
			IF_BROADCAST=$BROADCAST
			IF_GATEWAY=$GATEWAY
			_write_primary # from network.<distro>.sh
			return
		fi
        fi
	# BUG/TODO: default.xml is for disk layout and network layout: => conflict
        loginfo "Using network configuration file: ${NETWORK_CONFIG_FILE}"
        write_variables # Save NETWORK_CONFIG_FILE variable for future use.

        # 1st, we need to validdate the network configuration file.
        loginfo "Validating network configuration: ${NETWORK_CONFIG_FILE}"
        xmlstarlet val --err --xsd /lib/systemimager/network-config.xsd ${NETWORK_CONFIG_FILE} || shellout "Network config file is invalid. Check error logs and fix problem."
        loginfo "Network configuration seems valid; continuing..."

	# Process network devices one by one
	local IFS=';'
	xmlstarlet sel -t -m 'config/if' -v "concat(@dev,';',@type,';',@control)" -n ${NETWORK_CONFIG_FILE}  | sed '/^\s*$/d' |\
                while read IF_DEV IF_TYPE IF_CONTROL
		do
			# 1st, clear all variables from previous <if> processing.
			unset IF_NAME IF_ID IF_ONBOOT IF_ONPARENT IF_USERCTL IF_MASTER IF_NAME IF_ONBOOT IF_USERCTL IF_MASTER IF_BOOTPROTO IF_IPADDR IF_NETMASK IF_PREFIX IF_BROADCAST IF_GATEWAY IF_DEFROUTE IF_IP6_INIT IF_HWADDR IF_BONDING_OPTS IF_DNS_SERVERS IF_DNS_SEARCH IF_ID IF_ALIAS_NAME IF_UUID
			
			# Process primary for this interface (only one primary, so no while loop)

			# 2 steps: 1st we parse the XML, then we load the result in shell variables.
			# We need 2 steps because the here line will not honor IFS in right argument (sub process)
			# except if we export it, which we don't want.
			# (<<< $() fails while <<< "$var" works)
			CNX=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/primary" -v "concat(@name,';',@uuid,';',@onboot,';',@bootproto,';',@userctl,';',@master)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
			read IF_NAME IF_UUID IF_ONBOOT IF_BOOTPROTO IF_USERCTL IF_MASTER <<< "$CNX"

			_read_ipv4 primary	# read ipv4 parameters
			_read_ipv6 primary	# read ipv6 parameters
			_read_options primary	# read options
			_read_dns primary	# read dns infos

			if test -n "${IF_MASTER}"
			then
				_write_slave # from network.<distro>.sh
			else
				_write_primary # from network.<distro>.sh
			fi
			# Process aliases for this interface
			xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/alias" -v "concat(@id,';',@uuid,';',@onparent,';',@bootproto,';',@userctl,';',@master)" -n ${NETWORK_CONFIG_FILE}  | sed '/^\s*$/d' |\
				while read IF_ID IF_UUID IF_ONPARENT IF_BOOTPROTO IF_USERCTL IF_MASTER
				do
					# 1st, clear all previous variables except those all aliases inherit (IF_NAME)
					unset IF_ONBOOT IF_BOOTPROTO IF_IPADDR IF_NETMASK IF_PREFIX IF_BROADCAST IF_GATEWAY IF_DEFROUTE IF_IP6_INIT IF_HWADDR IF_BONDING_OPTS IF_DNS_SERVERS IF_DNS_SEARCH IF_ALIAS_NAME IF_UUID
					test -z "${IF_NAME}" && shellout "No primary defined for device [${IF_DEV}]"

					_read_ipv4 "alias[@id=\"$IF_ID\"]"	# read ipv4 parameters
					_read_ipv6 "alias[@id=\"$IF_ID\"]"	# read ipv6 parameters
					#_read_options "alias[@id=\"$IF_ID\"]"	# read options
					#_read_dns "alias[@id=\"$IF_ID\"]"	# read dns infos

					if test -n "${IF_MASTER}"
					then
						_write_slave # from network.<distro>.sh
					else
						_write_alias # from network.<distro>.sh
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

_read_ipv4() {
	local IFS=';'
	# Read ip tag
	CNX_IP=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/$1/ip" -v "concat(@ipv4_failure_fatal,';',@ipaddr,';',@prefix,';',@netmask,';',@broadcast,';',@gateway,';',@def_route,';',@peerdns,';',@mtu,';',@ipv4_route_metric)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
	read IPV4_FAILURE_FATAL IF_IPADDR IF_PREFIX IF_NETMASK IF_BROADCAST IF_GATEWAY IF_DEFROUTE IF_PEERDNS IF_MTU IF_IPV4_ROUTE_METRIC <<< "$CNX_IP"
}

_read_ipv6() {
	local IFS=';'
	# Read ip6 tag
	CNX_IP6=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/$1/ip6" -v "concat(@ipv6_failure_fatal,';',@ipv6_init,';',@ipv6_autoconf,';',@ipv6_addr,';',@ipv6_defaultgw,';',@ipv6_defroute,';',@ipv6_peerdns,';',@ipv6_mtu,';',@ipv6_route_metric)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
	read IF_IPV6_FAILURE_FATAL IF_IPV6_INIT IF_IPV6_AUTOCONF IF_IPV6_ADDR IF_IPV6_DEFAULTGW IF_IPV6_DEFROUTE IF_IPV6_PEERDNS IF_IPV6_ROUTE_METRIC <<< "$CNX_IP6"
}

_read_options() {
	local IFS=';'
	# Read options tag
	CNX_OPTIONS=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/$1/options" -v "concat(@hwaddr,';',@macaddr,';',@bonding_opts)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
	read IF_HWADDR IF_MACADDR IF_BONDING_OPTS <<< "$CNX_OPTIONS"
}

_read_dns() {
	local IFS=';'
	# Read the dns tag
	CNX_DNS=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/$1/dns" -v "concat(@servers,';',@search)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
	read IF_DNS_SERVERS IF_DNS_SEARCH <<< "$CNX_DNS"
	IFS=','
	read IF_DNS1 IF_DNS2 IF_DNS3 <<< "$IF_DNS_SERVERS"
	IF_DOMAIN=${IF_DNS_SEARCH//,/ } # The search list is a space separated list.
}

_fix_if_parameters() {

	# IF controle is empty, defaults to network manager
	test -z "${IF_CONTROL}" && IF_CONTROL="NetworkManager"

	# Check that client network setup filesystem hierarchy is in place
	_check_network_config # from network.<distro>.sh

	# TODO: check that IF_MASTER exists and is of type bond.
	# TODO: check that all slaves of IF_MASTER have the same type= whatever it is (except Bond)

	# Compute full connection name.
	test -z "${IF_NAME}" && IF_NAME=${IF_DEV} && logdebug "Using device name ($IF_DEV) as connection name"

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

	# Add an uuid is none is provided (only for legacy config).
	test -z "${IF_UUID}" -a "${IF_CONTROL}" = "legacy" && IF_UUID=$(uuidgen) && logdebug "No UUID; generating one: $IF_UUID"
	
	# Check that HWADDR match kernel point of view if provided
	if test -n "$IF_HWADDR"
	then
		if test -e /sys/class/net/$IF_DEV/address -o -n "$IF_MACADDR"
		then
			if test -n "$IF_MACADDR"
			then
				REAL_MAC="$IF_MACADDR"					# Compare withe the one we setup
			else
				REAL_MAC="$(cat /sys/class/net/$IF_DEV/address)"	# Compare with kernel info
			fi
			if test "$(echo $IF_HWADDR | tr '[:upper:]' '[:lower:]')" != "$REAL_MAC"
			then
				logerror "Device $IF_DEV kernel MAC is $REAL_MAC. Config differs: hwaddr=$IF_HWADDR."
				logerror "Please fix or your network won't setup at next boot."
			else
				logdebug "hwaddr=$IF_HWADDR Match device $IF_DEV"
			fi
		else
			logdebug "/sys/class/net/$IF_DEV/address doesn't exists. Can't check that hwaddr=$IF_HWADDR matches."
		fi
	fi
}

################################################################################
#
# _check_interface_type (uses ${IF_DEV} ${IF_TYPE})
#
#  => If interface is not virtual: check that requested type matches what kernel
#     sees (/sys/class/net/<$IF_DEV>/type)
#     Ethernet:		type=1 (Physical and WiFi)
#     Infiniband:	type=32
#     Firewire:		type=24
# More infos here: https://stackoverflow.com/questions/4475420/detect-network-connection-type-in-linux/4476014
#
_check_interface_type() {
	if test -r /sys/class/net/${IF_DEV}/type
	then
		local NET_CLASS_TYPE="$(cat /sys/class/net/${IF_DEV}/type)"
		case "${NET_CLASS_TYPE}" in
			1)
				if test -d /sys/class/net/${IF_DEV}/wireless -o -L /sys/class/net/${IF_DEV}/phy80211
				then
					DETECTED_TYPE=Wi-Fi
				else
					DETECTED_TYPE=Ethernet
				fi
				;;
			24)
				DETECTED_TYPE=Ethernet
				;;
			32)
				DETECTED_TYPE=Infiniband
				;;
			*)
				logwarn "Unknown device type ${NET_CLASS_TYPE} for device ${IF_DEV}"
				return
				;;
		esac
	else
		case "${IF_TYPE}" in
			Ethernet|Infiniband)
				logwarn "Network configuration list ${IF_DEV} of type ${IF_TYPE} to be configured,"
				logwarn "but it is not seen by kernel. Make sure it is the correct device name."
				logwarn "Assuming post install scripts will bring this device to life."
				;;
			*)
				logdebug "Virtual interface ${IF_DEV} not yet seen by kernel: not checking type."
				;;
		esac
		return
	fi
	if test "${DETECTED_TYPE}" != "${IF_TYPE}"
	then
		logwarn "Warning: Interface ${IF_DEV} is seen as ${DETECTED_TYPE}, but your want"
		logwarn "to configure it as ${IF_TYPE}. This may result in unexpected results."
	else
		logdebug "Device ${IF_DEV} is seen by kernel and of expected type: ${DETECTED_TYPE}."
	fi
}

_check_interface() {
	_fix_if_parameters # Compute IF_FULL_NAME, IF_DEV_FULL_NAME, UUID, Simplify IPADDR/PREFIX/NETMASK
	_check_interface_type
}	
