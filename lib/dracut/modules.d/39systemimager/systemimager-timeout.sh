#!/bin/bash

# We should never get here.

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type save_netinfo >/dev/null 2>&1 || . /lib/net-lib.sh
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

# 1st: check if we got an IP address.
if test -z "$(ip -o -4 addr show|grep -v '127.0.0.1')"
then
	logmsg "Failed to get an IP address"
	shellout
fi

# 2nd: check if we were able to retreive the imaging scripts


# 3rd: check that we were able to rsync something

# 4th: check that /sysroot and /sysroot/boot are not full.

