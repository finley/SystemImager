#!/bin/sh

# Make sure we're not called multiple time (even if it's harmless)
[ -e "$job" ] && rm "$job"

. /lib/systemimager-lib.sh
loginfo "==== systemimager-init ===="
# Init /run/systemimager directory
test ! -d /run/systemimager && mkdir -p /run/systemimager
