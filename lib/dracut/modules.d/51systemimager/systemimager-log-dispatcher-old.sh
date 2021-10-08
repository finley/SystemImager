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
#      This file will start the log dispatcher task
#      This log dispatcher will read event log and dispatch it to:
#      - console (local)
#      - plymouth (local)
#      - /tmp/si_monitor.log (local)
#      - remote syslog (remote - optional - default: disabled)
#      - imager console monitor (remote - optional - default: enabled)
#
#    NOTE: This version is specific to old distro that have no systemd journald.
#

type write_variables >/dev/null 2>&1 || . /lib/systemimager-lib.sh

# logstep cant be used as log dispatcher is not yet started.
logmessage local1.debug systemimager "systemimager-log-dispatcher: event log dispatcher task"

# Systemimager possible breakpoint
getarg 'si.break=log-dispatcher' && logmessage local0.warning systemimager "Break event log dispatcher" && interactive_shell

{
	SEVERITY=( emerg alert crit err warning notice info debug )
	FACILITY=( kern user mail daemon auth syslog lpr news uucp cron authpriv ftp ntp security console cron local0 local1 local2 local3 local4 local5 local6 local7 )

	# socat UDP no CRLF solution given by "meuh" here:
	# https://stackoverflow.com/questions/57399323/cant-read-logger-message-thru-socat-u-unix-recv-dev-log-ignoreeof-because-t/57401796#57401796

	socat -v -u UNIX-RECV:/dev/log,ignoreeof OPEN:/dev/null 2>&1 |
	while read sign date time len from to
	do
		len=${len##*=}
		read -n "$len" -r LINE
		IFS=' :<>' read -r -a SPLIT <<< "$LINE"
		read LOG_SEVERITY LOG_FACILITY <<< $(dc <<< "${SPLIT[1]} 8 ~ f")
		LOG_DATE="${SPLIT[2]} ${SPLIT[3]} ${SPLIT[4]}:${SPLIT[5]}:${SPLIT[6]}"
		LOG_TAG="${SPLIT[7]}"
		LOG_MESSAGE="${LINE#*${LOG_TAG}: }"
		logmessage ${FACILITY[$LOG_FACILITY]}.${SEVERITY[$LOG_SEVERITY]} "$LOG_TAG" "$LOG_MESSAGE"
	done
}&

LOG_DISPATCHER_PID=$!

disown # Remove this task from shell job list so no debug output will be written when killed.
test ! -d /run/systemimager && mkdir -p /run/systemimager
echo "$LOG_DISPATCHEZR_PID" > /run/systemimager/log_dispatcher.pid
logdetail "log dispatcher PID: $LOG_DISPATCHER_PID"

loginfo "Log event dispatcher started...."

