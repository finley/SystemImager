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

# Re-read variables.txt each time we're called.
. /tmp/variables.txt

logdebug "==== systemimager-wait-imaging ===="

if test -f /tmp/SIS_action
then
	ACTION=`cat /tmp/SIS_action`
	case "$ACTION" in
		"shell")
			loginfo "Installation successfull. Dropping to interactive shell as requested."
			send_monitor_msg "status=106:speed=0" # 106=shell
			sis_postimaging shell
			;;
		"emergency")
			logwarn "Installation Failed!"
			send_monitor_msg "status=-1:speed=0" # -1: error
			sis_postimaging emergency
			;;
		"reboot"|"kexec")
			logwarn "Installation successfull. Rebooting as requested"
			send_monitor_msg "status=104:speed=0" # 104: rebooting
			sleep 10
			sis_postimaging reboot
			;;
		"shutdown"|"poweroff")
			loginfo "Installation successfull. shutting down as requested"
			send_monitor_msg "status=105:speed=0" # 105: shutdown/poweroff
			sleep 10
			sis_postimaging poweroff
			;;
		*)
			logwarn "Installation successfull. Invalid post action. Rebooting"
			send_monitor_msg "status=104:speed=0" # 104: rebooting
			sleep 10
			sis_postimaging reboot
			;;
	esac
	return 0
else
	logdebug "Imaging not yet finished.... (main loop: $main_loop/$RDRETRY)"
	return 1
fi

