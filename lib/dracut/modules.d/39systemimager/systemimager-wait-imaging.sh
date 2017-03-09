#!/bin/bash
. /lib/dracut-lib.sh

# Wait that systemimager kernel cmdline parameters are dumped
#test -f /tmp/kernel_append_parameter_variables.txt || exit 1

#info "SYSTEMIMAGER: initqueue finished."

#exit 0

if test -f /tmp/SIS_action
then
	case $(cat /tmp/SIS_action) in
		"emergency")
			/bin/dracut-emergency
			;;
		"reboot")
			save_logs_to_sysroot
			sleep 10
			/sbin/reboot
			;;
		"shutdown")
			save_logs_to_sysroot
			sleep 10
			/sbin/shutdown
			;;
	esac
	exit 0
else
	exit 1
fi

