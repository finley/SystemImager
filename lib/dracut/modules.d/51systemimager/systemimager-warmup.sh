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
# This file is responsible to wait for the systemimager plymouth environment.

# Make sure we're not called multiple time (even if it's harmless)
[ -e "$job" ] && rm "$job"

. /lib/systemimager-lib.sh
logstep "systemimager-warmup"

loginfo "Waiting for plymouth GUI to show up."
# Wait for plymouth to be ready.
#while ! plymouth --ping
#do
#	sleep 1
#done
sleep 2

# Highlight plymouth init icon.
sis_update_step init

