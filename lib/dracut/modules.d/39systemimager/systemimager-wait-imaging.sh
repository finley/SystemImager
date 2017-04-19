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

loginfo "==== systemimager-wait-imaging ===="

if test -f /tmp/SIS_action
then
	ACTION=`cat /tmp/SIS_action`
	case "$ACTION" in
		"shell")
			logwarn "Installation successfull. Dropping to interactive shell as requested."
			sis_postimaging shell
			;;
		"emergency")
			logwarn "Installation Failed!"
			sis_postimaging emergency
			;;
		"reboot"|"kexec")
			logwarn "Installation successfull. Rebooting as requested"
			sleep 10
			sis_postimaging reboot
			;;
		"shutdown"|"poweroff")
			warn "Installation successfull. shutting down as requested"
			sleep 10
			sis_postimaging poweroff
			;;
	esac
	return 0
else
	logwarn "Imaging not yet finished.... $main_loop/$RDRETRY"
	return 1
fi

