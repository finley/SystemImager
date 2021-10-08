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
#      This file is run by initqueue/online hook from dracut-initqueue service
#      if network was successfully set up.
#      It's task is to check that we ca reach systemimager server.

type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

logstep "systemimager-pingtest: check image server visibility."
loginfo "Checking network connectivity via a ping test..."

# Systemimager possible breakpoint
getarg 'si.break=ping' && logwarn "Break ping" && interactive_shell

# The reason we don't ping the IMAGESERVER if FLAMETHROWER_DIRECTORY_PORTBASE
# is set, is that the client may never be given, know, or need to know, the 
# IP address of the imageserver because the client is receiving _all_ of it's
# data via multicast, which is more like listening to a channel, as compared 
# with connecting directly to a server.  -BEF-
#
if [ ! -z "$FLAMETHROWER_DIRECTORY_PORTBASE" ]; then
    PING_DESTINATION=$GATEWAY
    HOST_TYPE="default gateway"
else
    PING_DESTINATION=$IMAGESERVER
    HOST_TYPE="SystemImager server"
fi 
loginfo "Pinging your $HOST_TYPE to ensure we have network connectivity."


# Ping test code submitted by Grant Noruschat <grant@eigen.ee.ualberta.ca>
# modified slightly by Brian Finley.
PING_COUNT=1
PING_EXIT_STATUS=1
while [ "$PING_EXIT_STATUS" != "0" ]
do
    loginfo "Ping attempt $PING_COUNT."
    ping -c 1 $PING_DESTINATION -W 1 # Wait only 1 second. worst case is a warning.
    PING_EXIT_STATUS=$?

    if [ "$PING_EXIT_STATUS" = "0" ]; then
        loginfo "We have connectivity to your $HOST_TYPE!"
        return 0
    fi

    PING_COUNT=$(( $PING_COUNT + 1 ))
    if [ "$PING_COUNT" = "4" ]; then
        logwarn "Failed ping test."
	logwarn "Despite this seemingly depressing result, I will attempt"
	logwarn "to proceed with the install. Your $HOST_TYPE may be"
	logwarn "configured to not respond to pings, but it wouldn't hurt"
	logwarn "to double check that your networking equipment is"
	logwarn "working properly!"
        PING_EXIT_STATUS=0
    fi
done

unset PING_DESTINATION
unset HOST_TYPE

return 0
