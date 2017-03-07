#!/bin/bash
. /lib/dracut-lib.sh

# Wait that systemimager kernel cmdline parameters are dumped
#test -f /tmp/kernel_append_parameter_variables.txt || exit 1

#info "SYSTEMIMAGER: initqueue finished."

#exit 0

if test -f /tmp/finished
then
	info "IMAGING Finished...."
	sleep 10
#	reboot
	exit 0
else
	exit 1
fi
