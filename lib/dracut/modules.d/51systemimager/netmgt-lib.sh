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

_load_distro_network_config_generator() {
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
}

################################################################################
#
# sis_configure_network()
#               Main function. Processes networkconfig.conf xml file to
#               configure client network.
################################################################################
#               
sis_configure_network() {

	# Now load the distro specific lib that is aware on how to write
	# The desired network configuration.
	_load_distro_network_config_generator
        if test -z "${NETWORK_CONFIG}"
        then
		loginfo "si.network-conf not provided. Trying to find a matching network configuration"
                NETWORK_CONFIG_FILE=`choose_filename ${SCRIPTS_DIR}/network-configs ".xml"`
        else
                NETWORK_CONFIG_FILE=${SCRIPTS_DIR}/network-configs/${NETWORK_CONFIG}
                test ! -f "${NETWORK_CONFIG_FILE}" && NETWORK_CONFIG_FILE=${SCRIPTS_DIR}/network-configs/${NETWORK_CONFIG}.xml
        fi
        if test ! -f "${NETWORK_CONFIG_FILE}" # Ìf no network config file is provided, we take the network from which we booted from
        then
		local HNAME="$HOSTNAME"
		test "$HNAME" = "localhost" && HNAME=""
                logwarn "Could not get a valid network configuration file"
                test -n "${NETWORK_CONFIG_FILE}" && logwarn "Tryed ${NETWORK_CONFIG_FILE}"
                logwarn "No group, group_override, base_hostname matches a network configuration file"
		logwarn "Please read systemimager.network-config(7) manual and create a network configuration file"
                logwarn "Store it on image server in /var/lib/systemimager/scripts/network-configs/"
                logwarn "Use one of possible names: {$NETWORK_CONFIG${NETWORK_CONFIG:+,}$HNAME${HNAME:+,}$GROUPNAME${GROUPNAME:+,}${HNAME//[0-9]/}${HNAME:+,}$IMAGENAME${IMAGENAME:+,}default}{,.xml}"
		loginfo "Using current imager network informations (from device: $DEVICE) as fallback."
		_write_pxe_booted_interface_config
		return
       fi

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

			loginfo "Configuring $IF_DEV network device (type=$IF_TYPE)"
			
			# Process primary for this interface (only one primary, so no while loop)

			# 2 steps: 1st we parse the XML, then we load the result in shell variables.
			# We need 2 steps because the here line will not honor IFS in right argument (sub process)
			# except if we export it, which we don't want.
			# (<<< $() fails while <<< "$var" works)
			CNX=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/primary" -v "concat(@name,';',@uuid,';',@onboot,';',@bootproto,';',@userctl,';',@master)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
			read IF_NAME IF_UUID IF_ONBOOT IF_BOOTPROTO IF_USERCTL IF_MASTER <<< "$CNX"

			test "${IF_NAME}" = "${DEVICE}" && PXE_BOOTED_IF="${IF_NAME}" # keep track that we configured the PXE booted interface.

			_read_ipv4 primary	# read ipv4 parameters
			_read_ipv6 primary	# read ipv6 parameters
			_read_options primary	# read options
			_read_dns primary	# read dns infos

			if test -n "${IF_MASTER}"
			then
				_write_slave # from network.<distro>.sh
			else
				test -n "${IF_DEFROUTE}" && NETWORK_DEFROUTE_DEV="${IF_DEV}" # Keep track of defroute device.
				_write_primary # from network.<distro>.sh
			fi
			# Make sure /etc/resolv.conf exists in imaged system.
			touch /sysroot/etc/resolv.conf

			# Process aliases for this interface
			xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/alias" -v "concat(@id,';',@uuid,';',@onparent)" -n ${NETWORK_CONFIG_FILE}  | sed '/^\s*$/d' |\
				while read IF_ID IF_UUID IF_ONPARENT
				do
					loginfo "Configuring $IF_DEV alias #$IF_ID network device (type=$IF_TYPE)"
					# 1st, clear all previous variables except those all aliases inherit (IF_NAME)
					unset IF_ONBOOT IF_BOOTPROTO IF_IPADDR IF_NETMASK IF_PREFIX IF_BROADCAST IF_GATEWAY IF_DEFROUTE IF_IP6_INIT IF_HWADDR IF_BONDING_OPTS IF_DNS_SERVERS IF_DNS_SEARCH IF_ALIAS_NAME IF_UUID
					test -z "${IF_NAME}" && shellout "No primary defined for device [${IF_DEV}]"

					_read_ipv4 "alias[@id=\"$IF_ID\"]"	# read ipv4 parameters
					_read_ipv6 "alias[@id=\"$IF_ID\"]"	# read ipv6 parameters

					# No slave to write (slave can't be an alias interface)
					_write_alias # from network.<distro>.sh
				done
			# Process slaves for this interface
			xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/slave" -v "@name" -n ${NETWORK_CONFIG_FILE}  | sed '/^\s*$/d' |\
				while read IF_SLAVE_NAME
				do
					test "${IF_TYPE}" != "Bond" && shellout "Slave interface, but parent is not of type 'Bond'!"

					_fix_if_parameters # Compute IF_FULL_NAME, IF_DEV_FULL_NAME, UUID, Simplify IPADDR/PREFIX/NETMASK
					
					# check that if exists (using xmlstarlet)
					MY_MASTER=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_SLAVE_NAME}\"]/primary" -v "@master" -n ${NETWORK_CONFIG_FILE})
					loginfo "Configuring $IF_DEV slave network device for (master=$IF_MASTER))"
					test "${MY_MASTER}" != "${IF_FULL_NAME}" && logerror "Slave [$IF_SLAVE_NAME] doesn't list me [$IF_FULL_NAME]  as master."
				done
		# Now, make sure the interface we booted from has a configuration
		test -z "${PXE_BOOTED_IF}" && _write_pxe_booted_interface_config
		# Now, make sure DEFROUTE=yes is set
		# If NETWORK_DEFROUTE_DEV is empty, this means no default route is configured.
		# Use the interface we booted from as a fallback
		if test -z "${NETWORK_DEFROUTE_DEV}"
		then
			logwarn "No default route has been defined in network configuration file"
			logwarn "Using $DEVICE as default route interface."
			_add_defroute $DEVICE
		fi

		done
}

# This function will create a network configuration file for the interface we
# booted from if it is not decribed in any network configuration file.
#
_write_pxe_booted_interface_config() {
		# 1st: check if NetworkManager is present in image.
		if test -x /sysroot/usr/sbin/NetworkManager -o -x /sysroot/sbin/NetworkManager
		then
			logdebug "NetworkManager detected in imaged client. Enabling it for $DEVICE"
			IF_NM_CONTROLLED="yes"
			IF_CONTROL="NetworkManager"
		elif test -x /sysroot/usr/bin/networkctl
		then
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
			IF_UUID=$(cat /proc/sys/kernel/random/uuid)
			_write_primary # from network.<distro>.sh
		else
			IF_DEV=$DEVICE
			IF_NAME=$DEVICE
			IF_DEV=$DEVICE
			IF_BOOTPROTO=$BOOTPROTO
			IF_TYPE=Ethernet # check with /sys/class/net/eth0/type
			IF_ONBOOT=yes
			IF_IPV4_FAILURE_FATAL=yes # TODO: be smarter. (maybe we booted thru ipv6)
			IF_PEERDNS=yes
			IF_UUID=$(cat /proc/sys/kernel/random/uuid)
			IF_IPADDR=$IPADDR
			IF_NETMASK=$NETMASK
			IF_BROADCAST=$BROADCAST
			IF_GATEWAY=$GATEWAY
			_write_primary # from network.<distro>.sh
		fi
}

_read_ipv4() {
	local IFS=';'
	# Read ip tag
	CNX_IP=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/$1/ip" -v "concat(@ipv4_failure_fatal,';',@ipaddr,';',@prefix,';',@netmask,';',@broadcast,';',@gateway,';',@def_route,';',@mtu,';',@ipv4_route_metric)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
	read IF_IPV4_FAILURE_FATAL IF_IPADDR IF_PREFIX IF_NETMASK IF_BROADCAST IF_GATEWAY IF_DEFROUTE IF_MTU IF_IPV4_ROUTE_METRIC <<< "$CNX_IP"
	logdebug "Read ipv4($IF_DEV): failure_fatal=$IF_IPV4_FAILURE_FATAL ipv4=$IF_IPADDR prefix=$IF_PREFIX netmaks=$IF_NETMASK broadcast=$IF_BROADCAST gateway=$IF_GATEWAY def_route=$IF_DEFROUTE mtu=$IF_MTU metric=$IF_IPV4_ROUTE_METRIC"
	test -z "${IF_IPV4_FAILURE_FATAL}" && IF_IPV4_FAILURE_FATAL="no" # Defaults to no (inspired from nmtui)
}

_read_ipv6() {
	local IFS=';'
	# Read ip6 tag
	CNX_IP6=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/$1/ip6" -v "concat(@ipv6_failure_fatal,';',@ipv6_init,';',@ipv6_autoconf,';',@ipv6_addr,';',@ipv6_defaultgw,';',@ipv6_defroute,';',@ipv6_mtu,';',@ipv6_route_metric)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
	read IF_IPV6_FAILURE_FATAL IF_IPV6_INIT IF_IPV6_AUTOCONF IF_IPV6_ADDR IF_IPV6_DEFAULTGW IF_IPV6_DEFROUTE IF_IPV6_ROUTE_METRIC <<< "$CNX_IP6"
	logdebug "Read ipv6($IF_DEV): failure_fatal=$IF_IPV6_FAILURE_FATAL init=$IF_IPV6_INIT autoconf=$IF_IPV6_AUTOCONF ipv6=$IF_IPV6_ADDR def_gateway=$IF_IPV6_DEFAULTGW def_route=$IF_IPV6_DEFROUTE metric=$IF_IPV6_ROUTE_METRIC"
	# If no IPV6 configuration is present, then don't init IPV6 with something the user may not be aware of.
	test -z "${IF_IPV6_FAILURE_FATA}${IF_IPV6_INIT}${IF_IPV6_AUTOCONF}${IF_IPV6_ADDR}${IF_IPV6_DEFAULTGW}${IF_IPV6_DEFROUTE}${IF_IPV6_ROUTE_METRIC}" && IF_IPV6_INIT="no"
}

_read_options() {
	local IFS=';'
	# Read options tag
	CNX_OPTIONS=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/$1/options" -v "concat(@hwaddr,';',@macaddr,';',@bonding_opts)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
	read IF_HWADDR IF_MACADDR IF_BONDING_OPTS <<< "$CNX_OPTIONS"
	logdebug "Read options($IF_DEV): hwaddr=$IF_HWADDR macaddr=$IF_MACADDR bond_opts=$IF_BONDING_OPTS"
}

_read_dns() {
	local IFS=';'
	# Read the dns tag
	CNX_DNS=$(xmlstarlet sel -t -m "config/if[@dev=\"${IF_DEV}\"]/$1/dns" -v "concat(@servers,';',@search,';',@peerdns,';',@ipv6_peerdns)" -n ${NETWORK_CONFIG_FILE} | sed '/^\s*$/d')
	read IF_DNS_SERVERS IF_DNS_SEARCH IF_PEERDNS IF_IPV6_PEERDNS <<< "$CNX_DNS"
	IFS=','
	read IF_DNS1 IF_DNS2 IF_DNS3 <<< "$IF_DNS_SERVERS"
	IF_DOMAIN=${IF_DNS_SEARCH//,/ } # The search list is a space separated list.
	logdebug "Read dns($IF_DEV): DNS1=$IF_DNS1 DNS2=$IF_DNS2 DNS3=$IF_DNS3 SEARCH=$IF_DNS_SEARCH PEERDNS=$IF_PEERDNS IPV6_PEERDNS=$IF_IPV6_PEERDNS"
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

	# 1/ Check prefix both in ipaddr and prefix parameters.
	if test "${IF_IPADDR//[0-9\.]/}" = "/" -a -n "${IF_PREFIX}"
	then
		logerror "IP prefix specified in both ipaddr= and prefix= parameters for device ${IF_FULL_NAME}"
		logerror "Ignoring /PREFIX in ipaddr; using ipaddr= without its prefix"
		IF_IPADDR="${IF_IPADDR%/*}"
	fi

	# 2/ Check prefix in addr and netmask parameter is set (conflict: keep netmask)
	if test "${IF_IPADDR//[0-9\.]/}" = "/" -a -n "${IF_NETMASK}"
	then
		logerror "IP prefix specified in both ipaddr= and netmask= parameters for device ${IF_FULL_NAME}"
		logerror "Ignoring prefix from ipaddr; using ipaddr= without its prefix"
		IF_IPADDR="${IF_IPADDR%/*}"
	fi

	# 3/ Check prefix in ipaddr parameter: NetworkManager doesn't support that. move prefix from ipaddr to prefix variable
	if test "${IF_IPADDR//[0-9\.]/}" = "/" -a -z "${IF_NETMASK}" -a -z "${IF_PREFIX}"
	then
		logdebug "Converting ipaddr/prefix to ipaddr= and prefix=" # Network manager doesn't support prefixed notation
		IF_PREFIX="${IF_IPADDR#*/}"
		IF_IPADDR="${IF_IPADDR%/*}"
	fi

	# 4/ Check both prefix and netmask varaible set. drop netmask variable (conflict)
	if test -n "${IF_PREFIX}" -a -n "${IF_NETMASK}"
	then
		logerror "IP prefix specified in both prefix= and netmask= parameters for device ${IF_FULL_NAME}"
		logerror "Ignoring NETMASK; using ipaddr= with its prefix"
		IF_NETMASK=""
	fi

	# If using systemd, ipaddr must be noted as CIDR
	if test "${IF_CONTROL}" = "systemd" -a "${IF_IPADDR//[0-9\.]/}" != "/" # systemd, but IPV4 addr has no /mask: need to fix it
	then
		if test -n "${IF_NETMASK}" -a -z "${IF_PREFIX}"
		then # code inspired from https://stackoverflow.com/questions/50413579/bash-convert-netmask-in-cidr-notation
			IF_PREFIX=0 x=0$( printf '%o' ${IF_NETMASK//./ } )
			while [ $x -gt 0 ]; do
				let IF_PREFIX+=$((x%2)) 'x>>=1'
			done
		elif test -z "${IF_NETMASK}" -a -z "${IF_PREFIX}"
		then
			logwarn "No prefix or netmask set for device ${IF_DEV} systemd will chose default one which may not be what you want."
		fi
		test -n "${IF_PREFIX}" && IF_IPADDR=${IF_IPADDR}/${IF_PREFIX} # CIDR notation
	fi
	# Add an uuid if none is provided (only for legacy config).
	test -z "${IF_UUID}" && IF_UUID=$(cat /proc/sys/kernel/random/uuid) && logdebug "No UUID; generating one: $IF_UUID"
	
	# Check that HWADDR match kernel point of view if provided
	if test -n "$IF_HWADDR"
	then
		if test -e /sys/class/net/$IF_DEV/address
		then
			HARDWARE_MAC="$(cat /sys/class/net/$IF_DEV/address)"	# Compare with kernel info
			if test "$(echo $IF_HWADDR | tr '[:upper:]' '[:lower:]')" != "$HARDWARE_MAC"
			then
				logerror "Device $IF_DEV internal MAC is $HARDWARE_MAC. Config differs: hwaddr=$IF_HWADDR."
				logerror "Please fix or your network won't setup at next boot."
			else
				logdebug "hwaddr=$IF_HWADDR Match device $IF_DEV"
			fi

			# if MAC spoofing is configured for interface we booted from (only if used DHCP), then issue a warning
			# abouth DHCP configuration. this is safe to have an install MAC and a spoofed production MAC, but
			# as it is an uncommon setup, issue a warning to ease debug in case of problem.
			if test -n "$IF_MACADDR" \
				-a "$IF_DEV" = "$DEVICE" \
				-a "$BOOTPROTO" = "dhcp" \
			        -a "$IF_BOOTPROTO" = "dhcp"
			then
				logwarn "We booted from DHCP($HARDWARE_MAC), but MAC spoofing is requested for this interface"
				logwarn "Check that your DHCP also knowns $IF_MACADDR or you may fail to initialise network at next boot"

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
	_check_interface_type # Make sure that type from config file match what kernel sees.
}
