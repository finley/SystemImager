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
# This file will start the si_monitor server that will let si_monitortk to
# remotely gather the imaging text console.

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type send_monitor_msg >/dev/null 2>&1 || . /lib/systemimager-lib.sh

logstep "systemimager-monitor-server: network console for simonitor_tk"

# Systemimager possible breakpoint
getarg 'si.break=monitor' && logwarn "Break start monitor" && interactive_shell

if [ ! -z "$MONITOR_SERVER" ]; then
    # Start socat local socket server. Aim it to have a unique persistent connection with server.
    if socat /dev/null TCP:$MONITOR_SERVER:8182 2>/dev/null
    then
	# freeze log dispatcher so we can add 1st line to log (avoid race condition)
	LOG_DISPATCHER_PID=$(cat /run/systemimager/log_dispatcher.pid) # TODO: add error checking
	kill -STOP $LOG_DISPATCHER_PID
	mv /tmp/si_monitor.json /etc/si_monitor.json.tmp
	echo "{ \"MAC\" : \"$CLIENT_MAC\" }" > /tmp/si_monitor.json # 1st line will be suppressed by server once used.
	cat /etc/si_monitor.json.tmp >> /tmp/si_monitor.json
	kill -CONT $LOG_DISPATCHER_PID
	rm -f /etc/si_monitor.json.tmp

	# start the socat server
	#socat UNIX-LISTEN:/tmp/logger.socket,ignoreeof TCP-CONNECT:10.0.238.84:8182&
	socat -u FILE:/tmp/si_monitor.json,ignoreeof TCP-CONNECT:$MONITOR_SERVER:8182&
	echo $! > /run/systemimager/monitor_socat.pid

	loginfo "Local console forwarder started and log forwarded to image server."
    else
	MONITOR_CONSOLE="n"
	logerror "Can' connect to server console logging. Console log disabled!"
    fi

    # Send initialization status.
    send_monitor_msg "status=0:first_timestamp=on:speed=0"
    loginfo "Progress monitoring initialized."
    # Start client log gathering server: for each connection
    # to the local client on port 8181 the full log is sent
    # to the requestor. -AR-
    if [ "x$MONITOR_CONSOLE" = "xy" ]; then
        if [ -z "$MONITOR_PORT" ]; then
            MONITOR_PORT=8181
        fi
	loginfo "Starting Console server (si.monitor-console=yes)..."
	logdebug "Listenning on port [$MONITOR_PORT]."
        while :
        do
            # OL: BUG: Maybe we need to differentiate MONITOR_PORT on server
            # and CONSOLE_PORT on client being imaged.
            tail -F -n +0 /tmp/si_monitor.log | ncat -p $MONITOR_PORT -l -k
	    logdebug "Monitor restart: exit=$?"
	    sleep 0.5s
        done &
	MONITOR_PID=$!
	echo $MONITOR_PID > /run/systemimager/si_monitor.pid
        loginfo "Logs monitor forwarding task started: PID=$MONITOR_PID ."
    else
	loginfo "Console server disabled (si.monitor-console=no)"
    fi
fi

