#!/bin/bash

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type save_netinfo >/dev/null 2>&1 || . /lib/net-lib.sh
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

. /tmp/variables.txt

if [ ! -z "$MONITOR_SERVER" ]; then
    init_monitor_server
    info "si monitor started"
fi

