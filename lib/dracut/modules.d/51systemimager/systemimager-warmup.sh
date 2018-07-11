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
logdebug "==== systemimager-warmup ===="

# Wait for plymouth to be ready.
#while ! plymouth --ping
#do
#	sleep 1
#done
loginfo "Waiting for plymouth GUI to show up."
sleep 0.5

# Highlight plymouth init icon.
sis_update_step init

