#!/bin/sh
#
# "SystemImager"
#
#  Copyright (C) 2000 Brian Elliott Finley 
#                     <brian@bgsw.net>
#  Copyright (C) 2002-2003 Bald Guy Software
#                          <brian@bgsw.net>
#
#  Copyright (C) 2017 Olivier Lahaye
#                     <olivier.lahaye@cea.fr>
#   $Id$
#
#   See http://www.iana.org/assignments/bootp-dhcp-parameters for details
#   on custom options (new_option_NNN) as viewed below. -BEF-
#   
#   option-100  ->  IMAGESERVER (depricated -> actually reserved for "printer name")
#   option-140  ->  IMAGESERVER
#   option-141  ->  LOG_SERVER_PORT
#   option-142  ->  SSH_DOWNLOAD_URL
#   option-143  ->  FLAMETHROWER_DIRECTORY_PORTBASE
#   option-144  ->  TMPFS_STAGING
#   option-208  ->  SSH_DOWNLOAD_URL (deprecated)
#                   disabled by JRT 2006-10-11
#                   see dhclient.conf for commentary

# systemimager-load-dhcpopts will read /tmp/dhclient.$DEVICE.dhcpopts and update
# /tmp/variables.txt accordingly. (priority is givent to local.cfg, then cmdline,
# then DHCP at last)

. /lib/systemimager-lib.sh # Load /tmp/variables.txt and some macros
logdebug "==== systemimager-load-dhcpopts ===="

DEVICE=$1

. /tmp/dhclient.$DEVICE.dhcpopts || shellout "Failed to run /tmp/dhclient.$DEVICE.dhcpopts"

[ -z "$HOSTNAME" ] || [ "$HOSTNAME" == "localhost" ] || [ "$HOSTNAME" == "(none)" && HOSTNAME="$new_host_name"
[ -z "$DOMAINNAME" ] && DOMAINNAME="$new_domain_name"

################################################################################
#
# Originally we assumed the DHCP server was the imageserver, then we started
# using option-100 (turns out option-100 is reserved for "printer name"),
# now we use option-140 (reserved for "private use").  The following 
# funkification is for backwards compatibility with servers using older 
# dhcp.conf files. -BEF-
#
if [ -z "$IMAGESERVER" ]; then
    if [ ! -z "$new_option_140" ]; then
        IMAGESERVER=$new_option_140
        echo "Using option-140 as IMAGESERVER: $IMAGESERVER"

    elif [ ! -z "$new_option_100" ]; then
        IMAGESERVER=$new_option_100
        echo "Using option-100 (deprecated) as IMAGESERVER: $IMAGESERVER"

    elif [ ! -z "$new_dhcp_server_identifier" ]; then
        IMAGESERVER=$new_dhcp_server_identifier
        echo "Using DHCP server (very deprecated) as IMAGESERVER: $IMAGESERVER"
    fi
fi

[ -z "$LOG_SERVER" ] && LOG_SERVER="$new_log_servers"
[ -z "$LOG_SERVER_PORT" ] && LOG_SERVER_PORT="$new_option_141"
                                                        
[ -z "$IPADDR" ] && IPADDR="$new_ip_address"
[ -z "$NETMASK" ] && NETMASK="$new_subnet_mask"
[ -z "$NETWORK" ] && NETWORK="$new_network_number"
[ -z "$BROADCAST" ] && BROADCAST="$new_broadcast_address"
[ -z "$FLAMETHROWER_DIRECTORY_PORTBASE" ] && FLAMETHROWER_DIRECTORY_PORTBASE="$new_option_143"
[ -z "$TMPFS_STAGING" ] && TMPFS_STAGING="$new_option_144"
[ -z "$GATEWAY" ] && GATEWAY="$new_routers"
[ -z "$GATEWAY_DEV" ] && GATEWAYDEV="$DEVICE"

                                                        
################################################################################
#
# Originally we used option-208 here, but pxelinux started using it too, so 
# we switched to using option-142.
#

[ -z "$SSH_DOWNLOAD_URL" ] && SSH_DOWNLOAD_URL="$new_option_142"

# Save variables to /tmp/variables.txt
write_variables

### END SystemImager loading network config ###
