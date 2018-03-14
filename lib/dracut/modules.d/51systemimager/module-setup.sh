#!/bin/bash
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
# This file is the main systemimager dracut module setup file.

check() {
    [[ $hostonly ]] && return 1
    return 255 # this module is optional
}

depends() {
    echo network shutdown i18n
    case "$(uname -m)" in
        s390*) echo cms ;;
    esac
    return 0
}

################################################################################
# Install binaries and scripts from the OS.
# Some binaries are already installed from modules
#
# 99shutdown:   umount poweroff reboot halt losetup stat
# 40network:    ip arping dhclient sed ping ping6 brctl teamd teamdctl teamnl 
# 10i18n:       setfont loadkeys kbd_mode stty
################################################################################

install() {
    # 1/ Copy systemimager template
    (cd @@SIS_INITRD_TEMPLATE@@; tar cpf - .)|(cd $initdir; tar xpf -)

    # 2/ Install binaries we need.
    # Filesystems we want to be able to handle
    inst_multiple -o mkfs.xfs xfs_admin xfs_repair
    inst_multiple -o mkfs.ext4 mkfs.ext3 mkfs.ext2 mke2fs tune2fs resize2fs tune2fs
    inst_multiple -o mkfs.fat mkfs.msdos mkfs.vfat mkfs.ntfs mkdosfs dosfslabel fatlabel
    inst_multiple -o mkfs.btrfs btrfs btrfstune
    inst_multiple -o mkfs.reiserfs mkreiserfs reiserfstune resize_reiserfs tunefs.reiserfs
    inst_multiple -o mkfs.jfs jfs_mkfs jfs_tune
    inst_multiple -o mklost+found # Do we need that?
    # Install ssh and its requirements
    install_ssh
    # Install docker and its requirements
    install_docker
    # Install plymouth theme and its requirements
    install_plymouth_theme
    inst_multiple cut date echo env sort test false true [ expr head install tail tee tr uniq wc tac mktemp yes xmlstarlet
    # inst_multiple setfont loadkeys kbd_mode stty # i18n module
    inst_multiple bc gzip bzip2 rsync mkfs parted blockdev lsblk partprobe awk ncat tty killall kexec ipcalc findmnt tput stty
    inst_multiple lvm pvcreate pvdisplay pvremove pvscan lvcreate lvdisplay lvremove lvscan lvmconf lvmconfig lvmdump lvchange vgcreate vgdisplay vgremove vgscan fsadm
    inst_multiple chmod chown cp dd df dmesg echo egrep fdisk fgrep grep halt host hostname ifconfig init insmod kill ln ls lsmod mkdir mknod mkswap modprobe more mv ping poweroff ps reboot shutdown rm rmdir rmmod route sed sh sleep swapoff swapon sync tar touch uname logger
    inst_multiple depmod blkid
    # Some helpfull command in case of problem
    inst_multiple -o find strace sysctl vi clear reset lsof fuser
    # bittorent client needed when using bittorrent deployment method.
    inst_multiple rtorrent

    # 3/ Install dracut logic
    inst "$moddir/systemimager-lib.sh" "/lib/systemimager-lib.sh"
    inst "$moddir/autoinstall-lib.sh" "/lib/autoinstall-lib.sh"
    inst "$moddir/disksmgt-lib.sh" "/lib/disksmgt-lib.sh"
    inst "$moddir/si_inspect_client.sh" "/sbin/si_inspect_client"
    for protocol_plugin in $moddir/systemimager-xmit-*.sh
    do
        inst "$protocol_plugin" "/lib/${protocol_plugin##*/}"
    done
    inst_hook cmdline 01 "$moddir/init-cmdline.sh" # copy /etc/persistent-cmdline.d to /etc/cmdline.d/
    inst_hook cmdline 20 "${moddir}/parse-i18n.sh" # rd.vconsole.* parameters are not parsed if dracut uses systemd (upstream BUG)
    inst_hook cmdline 30 "$moddir/systemimager-check-kernel.sh" # Check that kernel & initrd match.
    inst_hook cmdline 50 "$moddir/parse-sis-options.sh" # read cmdline parameters
    inst_hook cmdline 70 "$moddir/parse-local-cfg.sh" # read local.cfg and overrides cmdline
    inst_hook initqueue/settled  50 "$moddir/systemimager-init.sh" # Creates /run/systemimager
    inst_hook initqueue/finished 90 "$moddir/systemimager-wait-imaging.sh" # Waits for file /tmp/SIS_action
    inst_hook initqueue/timeout 10 "$moddir/systemimager-timeout.sh" # In case of timeout (DHCP failure, ....)
    inst_hook initqueue/online 00 "$moddir/systemimager-load-dhcpopts.sh" # read DHCP SIS special options
    #inst_hook initqueue/online 10 "$moddir/systemimager-ifcfg.sh" # creates /tmp/variables.txt
    inst_hook initqueue/online 20 "$moddir/systemimager-pingtest.sh" # do a ping_test()
    inst_hook initqueue/online 30 "$moddir/systemimager-load-scripts-ecosystem.sh" # load /scripts read $SIS_CONFIG
    inst_hook initqueue/online 50 "$moddir/systemimager-monitor-server.sh" # Start the log monitor server
    inst_hook initqueue/online 90 "$moddir/systemimager-deploy-client.sh" # Imaging occures here
#    inst_hook pre/pivot 50 "$moddir/systemimager-save-inst-logs.sh"

    dracut_need_initqueue
}

################################################################################
# sub routine that installs ssh
#
install_ssh() {
    # Install binaries
    inst_multiple -o ssh scp ssh-keygen sshd wget
    # Install clients config
    (cd /etc; tar cpf - ssh/ssh_config*)|(cd $initdir/etc; tar xpf -)
    # Install server config
    (cd /etc; tar cpf - ssh/sshd_config ssh/moduli)|(cd $initdir/etc; tar xpf -)
    # Disable PAM authentication.
    sed -i -e 's/^UsePAM\syes/UsePAM no/g' $initdir/etc/ssh/sshd_config
}

################################################################################
# sub routine that installs docker client
#
install_docker() {
    # Install binaries
    inst_multiple -o docker docker-current
    # Install clients config
    (cd /etc; test -f docker/seccomp.json && tar cpf - docker/seccomp.json)|(cd $initdir/etc; tar xpf -)
    # Install system docker config.
    [ -f /etc/sysconfig/docker ] && mkdir -p $initdir/etc/sysconfig && cp /etc/sysconfig/docker $initdir/etc/sysconfig
    [ -f /etc/default/docker ] && mkdir -p $initdir/etc/default && c /etc/default/docker $initdir/etc/default
}

################################################################################
# sub routine that installs plymouth theme
#
install_plymouth_theme() {
    PLUGINDIR=`plymouth --get-splash-plugin-path`
    inst $PLUGINDIR/script.so $initdir
    inst $PLUGINDIR/label.so $initdir
    # Cleanup unwanted themes
    ( cd $initdir/usr/share/plymouth/themes/
        for THEME in `echo *|sed -r 's/\stext|\sdetails//g'`
       	do
            rm -rf $initdir/usr/share/plymouth/themes/$THEME # Remove unwanted themes
        done
    )
    # Install required fonts
    inst /usr/share/fonts/dejavu/DejaVuSerif.ttf $initdir
    inst /usr/share/fonts/dejavu/DejaVuSans.ttf $initdir
    inst /etc/fonts/fonts.conf $initdir # fontconfig lib used by plymouth requires it.

    # Install systemimager plymouth theme
     mkdir -p $initdir/usr/share/plymouth/themes/systemimager
    cp $moddir/plymouth_theme/{*.png,systemimager.plymouth,systemimager.script} $initdir/usr/share/plymouth/themes/systemimager
    ( cd ${initdir}/usr/share/plymouth/themes; ln -sf systemimager/systemimager.plymouth default.plymouth 2>&1 )
    cat > ${initdir}/etc/plymouth/plymouthd.conf <<EOF
# SystemImager is the default theme
[Daemon]
Theme=systemimager
ShowDelay=0
DeviceTimeout=5
EOF
}
