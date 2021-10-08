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
#      This file is run by initqueue/finished hook from dracut-initqueue service
#      It is called every seconds until it returns 0
#      Depending on SI_IMAGING_STATUS (finished, failed, inprogress)
#      reboot: imaging is finished and reboot was the default action
#      shutdown: imaging is finished and shutdown was the default action
#      emergency: a problem occured => trigger emergency shell.
#

type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

# Re-read variables.txt each time we're called.
. /tmp/variables.txt

# If /tmp/.mainloop doesn't exists yet, this is the 1st time we're called.
# Time for checking that plymouth GUI is brought up.
if test ! -f /tmp/.mainloop
then
	loginfo "Waiting for plymouth GUI to show up."
	# Wait for plymouth to be ready.
	#while ! plymouth --ping
	#do
	#       sleep 1
	#done
	sleep 2

	# Highlight plymouth init icon.
	sis_update_step init
fi

# Report only once that we entered mainloop.
test ! -f /tmp/.mainloop && logstep "systemimager-wait-imaging: Imager main event loop."
touch /tmp/.mainloop

logdebug "Called as: $f by $0"

case "$SI_IMAGING_STATUS" in
	"finished")
		if test ! -e /etc/fstab.systemimager
		then
			# Already run. We are called for each network interface that has been set-up.
			logdebug "Iamging: finished already treated"
			return 0
		fi

		logdebug "Imaging finished. Doing post action [$SI_POST_ACTION]"

		cd / # Make sure we're not in the wrong plce.
		case "$SI_POST_ACTION" in
			"shell")
				loginfo "Installation successfull. Dropping to interactive shell as requested."
				# send_monitor_msg "status=106:speed=0" # 106=shell
				update_client_status 106 0 # 106=shell
				sis_postimaging shell
				;;
			"reboot"|"kexec")
				logwarn "Installation successfull. Rebooting as requested"
				#send_monitor_msg "status=104:speed=0" # 104: rebooting
				update_client_status 104 0 # 104=rebooting
				sleep 10
				sis_postimaging reboot
				;;
			"shutdown"|"poweroff")
				loginfo "Installation successfull. shutting down as requested"
				#send_monitor_msg "status=105:speed=0" # 105: shutdown/poweroff
				update_client_status 105 0 # 105=shutdown/poweroff
				sleep 10
				sis_postimaging poweroff
				;;
			"directboot")
				loginfo "Installation successfull. Finishing as normal boot without rebooting"
				#send_monitor_msg "status=104:speed=0" # 104: rebooting
				update_client_status 104 0 # 104=rebooting
				sleep 10
				sis_postimaging directboot
				logdebug "directboot engaged"
				;;
			*)
				logwarn "Installation successfull. Invalid post action. Rebooting"
				#send_monitor_msg "status=104:speed=0" # 104: rebooting
				update_client_status 104 0 # 104=rebooting
				sleep 10
				sis_postimaging reboot
				;;
		esac
		return 0
		;;
	"failed")
		logwarn "Installation Failed!"
		# send_monitor_msg "status=-1:speed=0" # -1: error
		update_client_status -1 0 # -1: error
		sis_postimaging emergency
		return 0
		;;
	"inprogress")
		logdebug "Imaging not yet finished.... (main loop: $main_loop/$RDRETRY)"
		return 1
		;;
esac

