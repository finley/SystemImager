#!/bin/bash

#if [ -z $MONITOR_SERVER ]; then
#        return
#    fi
# OL: Note: this function ins called in the initqueue mainloop at each loop.
#     We just need to do that once. (code inspired from /sbin/rdsoreport)

if test ! -f /tmp/si_monitor.log
then
    # exec >/tmp/si_monitor.log 2>&1
    if command -v journalctl >/dev/null 2>/dev/null
    then
	journalctl -ab --no-pager -o short-monotonic >/tmp/si_monitor.log
    else
        dmesg >/tmp/si_monitor.log
    fi
    echo "=========================" >>/tmp/si_monitor.log
    echo "Early system messages saved to /tmp/si_monitor.log for future use." >>/tmp/si_monitor.log
fi
exit 0
