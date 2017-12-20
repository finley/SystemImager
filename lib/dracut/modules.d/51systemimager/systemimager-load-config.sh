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
# This file is responsible to load optional config file from rsync

. /lib/systemimager-lib.sh
logdebug "==== systemimager-load-config ===="

if test -n "$SIS_CONFIG"
then
	# retreive imaging config file
	loginfo "Loading $SIS_CONFIG from $IMAGESERVER configs using rsync."
	logdebug "rsync -av --numeric-ids $IMAGESERVER::configs/$SIS_CONFIG /tmp"
	rsync -a $IMAGESERVER::configs/$SIS_CONFIG /tmp || shellout "Failed to load $SIS_CONFIG from $IMAGESERVER configs."
	# update variables.
	. /tmp/$SIS_CONFIG
	# Keep track of variables.
	write_variables
fi

