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
# This file will start the log dispatcher task
# This log dispatcher will read event log and dispatch it to:
# - console (local)
# - plymouth (local)
# - /tmp/si_monitor.log (local)
# - remote syslog (remote - optional - default: disabled)
# - imager console monitor (remote - optional - default: enabled)
#
# NOTE: This version is specific to systemd journald based distros.

type write_variables >/dev/null 2>&1 || . /lib/systemimager-lib.sh

# logstep cant be used as log dispatcher is not yet started.
logmessage local1.debug systemimager "systemimager-log-dispatcher: event log dispatcher task"

# Systemimager possible breakpoint
getarg 'si.break=log-dispatcher' && logmessage local0.warning systemimager "Break event log dispatcher" && interactive_shell

{
	SEVERITY=( emerg alert crit err warning notice info debug )
	FACILITY=( kern user mail daemon auth syslog lpr news uucp cron authpriv ftp ntp security console cron local0 local1 local2 local3 local4 local5 local6 local7 )
	while IFS=';' read LOG_FACILITY LOG_SEVERITY LOG_TAG LOG_MESSAGE
	do
		logmessage ${FACILITY[$LOG_FACILITY]}.${SEVERITY[$LOG_SEVERITY]} "$LOG_TAG" "$LOG_MESSAGE"
	done < <( journalctl --follow -o json --no-pager --no-tail | jq --unbuffered -r '"\(.SYSLOG_FACILITY // 3);\(.PRIORITY // 6 );\(.SYSLOG_IDENTIFIER // "journald");\(.MESSAGE | tojson | @sh // "no message")"' )
	#done < <( journalctl --follow -o json --no-pager --no-tail | jq --unbuffered -r '"\(.SYSLOG_FACILITY // 3);\(.PRIORITY // 6 );\(.SYSLOG_IDENTIFIER // "journald");\(.MESSAGE | sub("\\n";" ";"g")  | sub("\\";"\\\\";"g") | sub("\\\"";"\\\"";"g") // "no message")"' )
}&

LOG_DISPATCHER_PID=$!

disown # Remove this task from shell job list so no debug output will be written when killed.

test ! -d /run/systemimager && mkdir -p /run/systemimager
echo $LOG_DISPATCHER_PID > /run/systemimager/log-dispatcher.pid
logdetail "log dispatcher PID: $LOG_DISPATCHER_PID"

loginfo "Log event dispatcher started...."
