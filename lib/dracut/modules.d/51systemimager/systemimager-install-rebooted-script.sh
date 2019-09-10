#!/bin/bash
#
#  "SystemImager"
#
#  Copyright (C) 2012-2018 Olivier Lahaye <olivier.lahaye@cea.fr>
#
# Description: Installs an init script that will report the rebooted status
#              to the monitor server.
#

# Load our lib.
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

# Load variables.txt
. /tmp/variables.txt

logstep "systemimager-install-rebooted-script"


# netcat timeout in seconds
TIMEOUT=30

# File created after reboot if rebooted state was successuflly reported to the server.
rebooted_state_file=/etc/systemimager/si_monitor.client.rebooted
rebooted_message="status=102:speed=0"

send_message_cmd() {
    if [ -z $MONITOR_SERVER ]; then
        # OL: Need to do something here...(log error)
	echo "false"
        return
    fi
    if [ -z $MONITOR_PORT ]; then
        MONITOR_PORT=8181
    fi

    #mac=$(LC_ALL=C ifconfig $DEVICE 2>/dev/null | sed -ne "s/.*HWaddr //p" | sed "s/ //g" | sed s/:/./g)
    mac=$(LC_ALL=C ip addr show dev $DEVICE 2>/dev/null |grep ether | sed -E -e 's/ *[a-z/]* *([:0-9a-z]+).*$/\U\1/g' -e  's/:/./g')
    kernel=$(ls /boot/vmlinuz-*|head -1|sed 's|/boot/vmlinuz-||g')
    message="mac=$mac:ip=$IPADDR:host=$HOSTNAME:kernel=$kernel:$rebooted_message"

    # Find a netcat binary
    PATH=/sysroot/usr/bin:/sysroot/usr/bin:/sysroot/bin:/sysroot/sbin netcat=$(type -P netcat nc ncat)

    if test -z "$netcat"
    then # try to use /dev/tcp
        echo "TMOUT=$TIMEOUT exec 3<>/dev/tcp/$MONITOR_SERVER/$MONITOR_PORT; echo \"$message\" >&3"
    else # use netcat
        echo "echo \"$message\" | ${netcat//\/sysroot/} -w $TIMEOUT $MONITOR_SERVER $MONITOR_PORT"
    fi
 }

# Detect the system init technology and create init files accordingly.

create_InitFile() {
    # Create /etc/systemimager if it doesn't exist.
    if [ ! -d /sysroot/etc/systemimager ]; then
        mkdir -p /sysroot/etc/systemimager
    fi

    # Redhat like (RHEL / old Fedora / Mandrake / ...)
    if test -d /sysroot/etc/rc.d/init.d && test ! -d /sysroot/lib/systemd/system; then
	loginfo "Installing systemimager-monitor-firstboot SysV init file"
        write_SysVInitFile /sysroot/etc/rc.d/init.d/systemimager-monitor-firstboot
    # SuSE or debian like like (SuSE, OpenSuSE, ...)
    elif test -d /sysroot/etc/init.d && test ! -d /sysroot/lib/systemd/system; then
	loginfo "Installing systemimager-monitor-firstboot SysV init file"
        write_SysVInitFile /sysroot/etc/init.d/systemimager-monitor-firstboot
    # Modern distro with systemd like Fedora, Mandriva, ...
    # NOTE: debian has this directory even if systemd is not used, thus we need to check for systemd after init scripts...
    elif test -d /sysroot/lib/systemd/system; then
	loginfo "Installing systemimager-monitor-firstboot systemd service"
        write_systemdInitFile
    # Unknown script boot system. default to rc.local.
    else
	logwarn "Unable to identify boot services mechanism system"
	loginfo "Installing systemimager-monitor-firstboot script in /etc/rc.local"
        cat >> /sysroot/etc/rc.local <<EOF
$(send_message_cmd) || sed -i -e /etc/rc.local 's/^(echo ".*$//g'
EOF
    fi

}

# write_systemdVInitFile()
#
write_systemdInitFile() {

# Create the systemd service file
    logdebug "Creating systemimager-monitor-firstboot service file"
    cat > /sysroot/lib/systemd/system/systemimager-monitor-firstboot.service <<EOF
# systemd service description file for systemimager
# (c) Olivier Lahaye 2012

[Unit]
Description=Report the REBOOTED state to the image server
After=syslog.target network.target
Before=final.target
ConditionPathExists=!$rebooted_state_file
#ConditionFirstBoot=true

[Service]
Type=oneshot
ExecStart=/lib/systemd/systemimager-monitor-firstboot
RemainAfterExit=no

[Install]
WantedBy=default.target
EOF

# Create the script that will run
    logdebug "Creating systemimager-monitor-firstboot script"
    cat > /sysroot/lib/systemd/systemimager-monitor-firstboot <<EOF
#!/bin/bash
# systemd service script for systemimager
# (c) Olivier Lahaye 2012-2019

# 1st, get last si_monitor.log and variables.txt files from /run/systemimager or /dev/.initramfs if it exists
# It will exists if we did a direct boot.
for file in {/run/initramfs,/dev/.initramfs}/systemimager/{si_monitor.log,si_dracut.log,variables.txt}
do
	if test -r \$file -a -w /root/SystemImager_logs/
	then
		cat \$file | sed -E 's/\\[[0-9]{2}m//g' > /root/SystemImager_logs/\${file##*/}
	fi
done

if ($(send_message_cmd))
then
    touch $rebooted_state_file
else
    echo "Error, cannot report rebooted status to server $MONITOR_SERVER"
    echo "Check that systemimager-monitord is running on the server"
    exit 1
fi
EOF

    logdebug "Setting execute permission on systemimager-monitor-firstboot script"
    chmod +x /sysroot/lib/systemd/systemimager-monitor-firstboot
    # --no-reload avoid systemd to immediately start the service (before reboot).
    logdebug "enabling systemimager-monitor-firstboot service in client"
    chroot /sysroot systemctl --no-reload enable systemimager-monitor-firstboot.service
}

#
# write_SysVInitFile()
# $1 name of the init script with full path.
#
write_SysVInitFile() {
    logdebug "Creating systemimager-monitor-firstboot init script"
    cat > $1 <<EOF
#!/bin/bash
#
# systemimager-monitor-firstboot	starts systemimager-monitor-firstboot
#
# chkconfig: 2345 11 99
# description: Inform systemimager monitord that reboot is done.
#
### BEGIN INIT INFO
# Provides: systemimager-monitor-firstboot
# Required-Start: $network $local_fs $syslog
# Required-Stop:
# Default-Start:  2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Report the REBOOTED state to the image server
# Description: Send the informations to the si_monitor daemon on the image
#              to set the REBOOTED state for this correctly installed client.
### END INIT INFO

set -e

case "\$1" in
  start)
	# 1st, get last si_monitor.log and variables.txt files from /run/systemimager or /dev/.initramfs if it exists
	# It will exists if we did a direct boot.
	for file in {/run/initramfs,/dev/.initramfs}/systemimager/{si_monitor.log,si_dracut.log,variables.txt}
	do
		if test -r \$file -a -w /root/SystemImager_logs/
		then
			cat \$file | sed -E 's/\\[[0-9]{2}m//g' > /root/SystemImager_logs/\${file##*/}
		fi
	done

        if ($(send_message_cmd))
        then
            if [ -x /sbin/chkconfig ]; then
                /sbin/chkconfig --del systemimager-monitor-firstboot
            elif [ -e /etc/rcS.d/S99systemimager-monitor-firstboot ]; then
                rm -f /etc/rcS.d/S99systemimager-monitor-firstboot
            fi
            touch $rebooted_state_file
        else
            echo "Error, cannot report rebooted status to server $MONITOR_SERVER"
            echo "Check that systemimager-monitord is running on the server"
        fi
        ;;
  stop|reload|restart|force-reload)
        ;;
  *)
        exit 1
        ;;
esac
exit 0
EOF

    chmod a+x $1
    if [ -x /sysroot/sbin/chkconfig ]; then
	logdebug "Enabling systemimager-monitor-firstboot in client using chkconfig"
        chroot /sysroot chkconfig --add systemimager-monitor-firstboot || logerror "Failed to enable systemimager-monitor-firstboot service using chkconfig"
    elif [ ! -e /etc/rcS.d/S99systemimager-monitor-firstboot ]; then
	logdebug "Enabling systemimager-monitor-firstboot in client using old school link"
	(cd /sysroot; ln -s $1 /etc/rcS.d/S99systemimager-monitor-firstboot || logerror "Failed to enable systemimager-monitor-firstboot service using link method")
    fi
}

# Make sure the rebooted state file is not already present in installed system (present in image)
rm -f /sysroot/$rebooted_state_file

# Create the init file that will report the rebooted states at first boot.
create_InitFile

# -- END --
