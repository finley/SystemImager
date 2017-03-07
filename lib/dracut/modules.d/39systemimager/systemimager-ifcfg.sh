#!/bin/bash
type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type save_netinfo >/dev/null 2>&1 || . /lib/net-lib.sh
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh


# initqueue/online hook passes interface name as $1
netif="$1"

# make sure we get ifcfg for every interface that comes up
save_netinfo $netif

echo "Network interface: [$netif]\n" >> /tmp/debug.txt
ifconfig -a >> /tmp/debug.txt

info "USING net interface: [$netif]"

DHCLIENT_DIR="/tmp"

if [ ! -f ${DHCLIENT_DIR}/dhclient.${netif}.lease ]; then
    warn "${DHCLIENT_DIR}/dhclient.${netif}.lease not found"
    shellout
fi


# read dhcp info in as variables -- this file will be created by 
# the /etc/dhcp/dhclient-exit-hooks script that is run automatically by
# dhclient.

if [ ! -f /tmp/dhcp_info.${netif} ] ; then
    warn "/tmp/dhcp_info.${netif} does not exists"
    shellout
fi

# Read the DHCLIENT variables
. /tmp/dhcp_info.${netif} || shellout

# Re-read configuration information from local.cfg to over-ride
# DHCP settings, if necessary. -BEF-
if [ -f /tmp/local.cfg ]; then
    info ""
    info "Overriding any DHCP settings with pre-boot local.cfg settings."
    . /tmp/local.cfg || shellout
fi

info ""
info "Overriding any DHCP settings with pre-boot settings from kernel append"
info "parameters."
read_kernel_append_parameters

# Save all needed variables to /tmp/variables.txt
IMAGESERVER=10.0.238.84 # BUG OL: ugly hack to be removed (override missing dhcp fields from qemu
write_variables

