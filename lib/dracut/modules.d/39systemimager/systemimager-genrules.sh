#!/bin/sh
# Creates the systemimager udev rules to be triggered when interface becomes online.
. /lib/dracut-lib.sh

loginfo "==== systemimager-genrules ===="

if [ -e "/sbin/systemimager-start" ]; then
        printf 'ACTION=="online", SUBSYSTEM=="net", RUN+="/sbin/initqueue --onetime /sbin/systemimager-start $env{INTERFACE}"\n' > /etc/udev/rules.d/70-systemimager.rules
else
        warn "syslog-genrules: Could not find script to start systemimager. systemimager will not be started."
fi
