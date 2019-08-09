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

SEVERITY=( emerg alert crit err warning notice info debug )
FACILITY=( kern user mail daemon auth syslog lpr news uucp cron authpriv ftp ntp security console cron local0 local1 local2 local3 local4 local5 local6 local7 )

journalctl --follow -o json | jq -r '"\(.SYSLOG_FACILITY) \(.PRIORITY) \(.SYSLOG_IDENTIFIER) \(.MESSAGE)"' |
while read LOG_FACILITY LOG_SEVERITY LOG_TAG LOG_MESSAGE
do
	logmessage ${FACILITY[$LOG_FACILITY]}.${SEVERITY[$LOG_SEVERITY]} "$LOG_TAG" "$LOG_MESSAGE"
done&
echo "$!" $(jobs -p) > /tmp/log-dispatcher.pids

loginfo "Log event dispatcher started...."

