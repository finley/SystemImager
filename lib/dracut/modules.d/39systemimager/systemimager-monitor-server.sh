#!/bin/bash

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

. /tmp/variables.txt

if [ ! -z "$MONITOR_SERVER" ]; then
    # 1st, load previous messages in log file.
    if test ! -f /tmp/si_monitor.log
    then
        if command -v journalctl >/dev/null 2>/dev/null
        then
            journalctl -ab --no-pager -o short-monotonic >/tmp/si_monitor.log
        else
            dmesg >/tmp/si_monitor.log
        fi
    fi

    # Then, Send initialization status.
    send_monitor_msg "status=0:first_timestamp=on:speed=0"
    loginfo "Monitoring initialized."
    # Start client log gathering server: for each connection
    # to the local client on port 8181 the full log is sent
    # to the requestor. -AR-
    if [ "x$MONITOR_CONSOLE" = "xy" ]; then
        MONITOR_CONSOLE=yes
    fi
    if [ "x$MONITOR_CONSOLE" = "xyes" ]; then
        while :; do ncat -p 8181 -l < /tmp/si_monitor.log; done &
	MONITOR_PID=$!
        logmsg "Logs monitor forwarding task started: PID=$MONITOR_PID ."
	echo $MONITOR_PID > /run/systemimager/si_monitor.pid
    fi
    loginfo "si monitor started"
fi

