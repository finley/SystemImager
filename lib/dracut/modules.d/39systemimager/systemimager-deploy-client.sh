#!/bin/bash

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
#type save_netinfo >/dev/null 2>&1 || . /lib/net-lib.sh
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

loginfo "==== systemimager-deploy-client ===="

. /tmp/variables.txt

if [ "$TMPFS_STAGING" = "yes" ]; then
    tmpfs_watcher
fi

if [ "x$SSHD" = "xy" ]; then
    logmsg
    logmsg start_sshd
    start_sshd
fi

if [ ! -z "$SSH_DOWNLOAD_URL" ]; then
    SSH=y
fi
if [ "x$SSH" = "xy" ]; then
    logmsg
    logmsg start_ssh
    start_ssh
fi

get_scripts_directory

show_loaded_modules

# HOSTNAME may already be set via cmdline, dhcp or local.cfg
if [ -z "$HOSTNAME" ]; then
    get_hostname_by_hosts_file
fi

if [ -z "$HOSTNAME" ]; then
    get_hostname_by_dns
fi

if [ ! -z "$HOSTNAME" ]; then
    loginfo
    loginfo "This hosts name is: $HOSTNAME"
fi

run_pre_install_scripts

# If none of SCRIPTNAME, HOSTNAME, or IMAGENAME is set, then we cannot proceed.
# (IMAGENAME may have been set by local.cfg).  -BEF-
if [ -z $SCRIPTNAME ] && [ -z $IMAGENAME ] && [ -z $HOSTNAME ]; then
    logwarn "FATAL:  None of SCRIPTNAME, IMAGENAME, or HOSTNAME were set, and I"
    logwarn "can no proceed!  (Scottish accent -- think Groundskeeper Willie)"
    logwarn ""
    logwarn "HOSTNAME is what most people use, and I try to determine it automatically"
    logwarn "from this hosts IP address ($IPADDR) in the following order:"
    logwarn ""
    logwarn "  1)  /var/lib/systemimager/scripts/hosts on your imageserver"
    logwarn "  2)  DNS"
    logwarn ""
    logwarn "Finally, you can explicitly set many variables pre-boot, including SCRIPTNAME,"
    logwarn "IMAGENAME, and HOSTNAME, as kernel append parameters or with a local.cfg file."

    shellout
fi

choose_autoinstall_script

# Update /tmp/variables.txt
write_variables

run_autoinstall_script

# Everything is finished. Tell initqueue/finished that we are done.
# BUG, /tmp/SIS_action can contain reboot, shutdown or emergency
#echo reboot > /tmp/SIS_action

