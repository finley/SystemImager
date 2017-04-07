#!/bin/bash

. /lib/systemimager-lib.sh

loginfo "==== systemimager-start ===="

export DEVICE=$1
write_variables					# Save $DEVICE

/sbin/systemimager-ifcfg $DEVICE		# creates /tmp/variables.txt
/sbin/systemimager-pingtest $DEVICE		# do a ping_test()
/sbin/systemimager-monitor-server $DEVICE	# Start the log monitor server
/sbin/systemimager-deploy-client $DEVICE	# Imaging occures here
