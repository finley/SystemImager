#!/bin/sh

test -r /tmp/root.info && . /tmp/root.info
test -z "$NEWROOT" && NEWROOT=/sysroot
unset netroot

