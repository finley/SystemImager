#!/bin/sh
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
# This file is run by initqueue/finished hook from dracut-initqueue service
# It is called every seconds until it returns 0
# IF a file /tmp/SIS_action is found it acts according to content:
# reboot: imaging is finished and reboot was the default action
# shutdown: imaging is finished and shutdown was the default action
# emergency: a problem occured => trigger emergency shell.

type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

if test -f /tmp/SIS_action
then
	case $(cat /tmp/SIS_action) in
		"shell")
			warn
			warn "========================================================"
			warn "Installation successfull. Dropping to shell as requested"
			emergency_shell -n "Installation successfull"
			;;
		"emergency")
			shellout
			;;
		"reboot")
			warn
			warn "========================================================"
			warn "Installation successfull. Rebooting as requested"
			sleep 10
			/sbin/reboot
			;;
		"shutdown")
			warn
			warn "========================================================"
			warn "Installation successfull. shutting down as requested"
			sleep 10
			/sbin/shutdown
			;;
	esac
	exit 0
else
	exit 1
fi

