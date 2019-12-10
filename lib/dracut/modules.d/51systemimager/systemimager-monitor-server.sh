#!/bin/bash
#
#    vi:set filetype=bash et ts=4:
#
#    This file is part of SystemImager.
#
#    SystemImager is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    SystemImager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with SystemImager. If not, see <https://www.gnu.org/licenses/>.
#
#    Copyright (C) 2017-2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#    Purpose:
#      This file will start the si_monitor server that will let si_monitortk to
#      remotely gather the imaging text console.

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type update_client_status >/dev/null 2>&1 || . /lib/systemimager-lib.sh

logstep "systemimager-monitor-server: console and progress report task."

# Systemimager possible breakpoint
getarg 'si.break=monitor' && logwarn "Break start monitor" && interactive_shell

if [ ! -z "$MONITOR_SERVER" ]; then
    # Start socat local socket server. Aim it to have a unique persistent connection with server.
    if socat /dev/null TCP:$MONITOR_SERVER:$MONITOR_PORT 2>/dev/null
    then
	# freeze log dispatcher so we can add 1st line to log (avoid race condition)
	LOG_DISPATCHER_PID=$(cat /run/systemimager/log_dispatcher.pid) # TODO: add error checking
	kill -STOP $LOG_DISPATCHER_PID
	mv /tmp/si_report.stream /etc/si_report.stream.tmp
	UPTIME=$(cat /proc/uptime)
	# 1st line will List MAC and uptime. server will substract client uptime to server timestamp to
	# get the effective first_timestamp.
	echo "MAC:$CLIENT_MAC;${UPTIME%%.*}" > /tmp/si_report.stream
	cat /etc/si_report.stream.tmp >> /tmp/si_report.stream
	kill -CONT $LOG_DISPATCHER_PID
	rm -f /etc/si_report.stream.tmp

	# start the socat server
	socat -u FILE:/tmp/si_report.stream,ignoreeof TCP-CONNECT:$MONITOR_SERVER:$MONITOR_PORT&
	echo $! > /run/systemimager/reporting_socat.pid

	loginfo "Local console forwarder started and log forwarded to image server."
    else
	MONITOR_CONSOLE="n"
	logerror "Can' connect to server console logging. Console log disabled!"
    fi

    # Send initialization status.
    #send_monitor_msg "status=0:first_timestamp=on:speed=0"
    update_client_status 0 0
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

