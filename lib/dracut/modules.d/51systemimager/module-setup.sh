#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=4 sw=4 sts=4 et filetype=sh
# vi: set filetype=sh et ts=4:
#
# "SystemImager"
#
#  Copyright (C) 1999-2018 Brian Elliott Finley <brian@thefinleys.com>
#  Code written by Olivier LAHAYE.
#
# This file is the main systemimager dracut module setup file.

check() {
    [[ $hostonly ]] && return 1 # Module is incompatible with hostonly option.
    return 255                  # this module is optional
}

depends() {
    echo network shutdown crypt
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
################################################################################

install() {
    # 1/ Copy systemimager template
    (cd ${SI_INITRD_TEMPLATE:=/usr/share/systemimager/boot/$(uname -m)/standard/initrd_template/}; tar cpf - .)|(cd $initdir; tar xpf -)

    # 2/ Install binaries we need.
    # Filesystems we want to be able to handle
    inst_multiple -o mkfs.xfs xfs_admin xfs_repair
    inst_multiple -o mkfs.ext4 mkfs.ext3 mkfs.ext2 mke2fs tune2fs resize2fs tune2fs
    inst_multiple -o mkfs.fat mkfs.msdos mkfs.vfat mkfs.ntfs mkdosfs dosfslabel fatlabel
    inst_multiple -o mkfs.btrfs btrfs btrfstune
    inst_multiple -o mkfs.reiserfs mkreiserfs reiserfstune resize_reiserfs tunefs.reiserfs
    inst_multiple -o mkfs.jfs jfs_mkfs jfs_tune
    inst_multiple -o mklost+found # Do we need that?
    inst_multiple -o socat # plymouth ask-for-password replacement requirement (CentOS-7 at least)

    # Install console utilities (i18n is missing on Debian, so we can't rely on this module)
    inst_multiple -o setfont loadkeys kbd_mode stty

    # Install ssh and its requirements
    install_ssh

    # Install docker and its requirements
    install_docker

    # Install plymouth theme and its requirements
    install_plymouth_theme
    inst_multiple cut date echo env sort test false true [ expr head install tail tee tr uniq wc tac mktemp yes xmlstarlet

    # inst_multiple setfont loadkeys kbd_mode stty # i18n module
    inst_multiple -o lsscsi lspci ethtool mii-tool mii-diag
    inst_multiple bc dc gzip bzip2 rsync mkfs parted sgdisk fdisk blockdev lsblk partprobe awk ncat tty killall kexec ipcalc findmnt findfs tput stty
    inst_multiple lvm pvcreate pvdisplay pvremove pvscan lvcreate lvdisplay lvremove lvscan lvmconf lvmconfig lvmdump lvchange vgcreate vgdisplay vgremove vgscan fsadm
    inst_multiple chmod chown cp dd df dmesg echo egrep fgrep grep halt host hostname ifconfig init insmod kill ln ls lsmod mkdir mknod mkswap modprobe more mv ping poweroff ps reboot shutdown rm rmdir rmmod route sed sh sleep swapoff swapon sync tar touch uname logger od
    inst_multiple depmod blkid
    inst_multiple uuidgen

    # Some helpfull command in case of problem
    inst_multiple -o find strace sysctl vi clear reset lsof fuser

    # bittorent client needed when using bittorrent deployment method.
    inst_multiple rtorrent

    # Install lsusb
    inst_multiple -o lsusb
    mkdir -p "$moddir/usr/share/hwdata"
    test -f /usr/share/hwdata/usb.ids && cp /usr/share/hwdata/usb.ids $moddir/usr/share/hwdata/

    # 3/ Install dracut logic
    inst "$moddir/systemimager-lib.sh" "/lib/systemimager-lib.sh"
    inst "$moddir/autoinstall-lib.sh" "/lib/autoinstall-lib.sh"
    inst "$moddir/disksmgt-lib.sh" "/lib/disksmgt-lib.sh"
    inst "$moddir/netmgt-lib.sh" "/lib/netmgt-lib.sh"
    inst "$moddir/network.debian.sh" "/lib/network.debian.sh"
    inst "$moddir/network.rhel.sh" "/lib/network.rhel.sh"
    inst "$moddir/network.suse.sh" "/lib/network.suse.sh"
    inst "$moddir/systemimager-install-rebooted-script.sh" "/lib/systemimager-install-rebooted-script"
    inst "$moddir/si_inspect_client.sh" "/sbin/si_inspect_client"
    for protocol_plugin in $moddir/systemimager-xmit-*.sh
    do
        inst "$protocol_plugin" "/lib/${protocol_plugin##*/}"
    done
    mkdir -p $initdir/usr/lib/systemimager/
    inst "$moddir/do_partitions.xsl" "/lib/systemimager/do_partitions.xsl" # Installs partition xml transformation filter
    inst "$moddir/disks-layout.xsd" "/lib/systemimager/disks-layout.xsd" # Installs disks layout validation schem.
    inst "$moddir/network-config.xsd" "/lib/systemimager/network-config.xsd" # Installs network configuration validation schem.
    inst_hook cmdline 30 "$moddir/systemimager-check-kernel.sh" # Check that kernel & initrd match.
    inst_hook cmdline 50 "$moddir/parse-systemimager.sh" # read cmdline parameters
    inst_hook cmdline 70 "$moddir/systemimager-init.sh" # Creates /run/systemimager and sets rootok
    inst_hook initqueue/settled 50 "$moddir/systemimager-warmup.sh" # Waits for plymouth
    inst_hook initqueue/finished 90 "$moddir/systemimager-wait-imaging.sh" # Waits for $SI_IMAGING_STATUS = "finished"
    inst_hook initqueue/timeout 10 "$moddir/systemimager-timeout.sh" # In case of timeout (DHCP failure, ....)
    inst_hook initqueue/online 00 "$moddir/parse-local-cfg.sh" # Read local.cfg (takes precedence over cmdline)
    inst_hook initqueue/online 10 "$moddir/systemimager-load-network-infos.sh" # read network informations
    inst_hook initqueue/online 20 "$moddir/systemimager-pingtest.sh" # do a ping_test()
    inst_hook initqueue/online 30 "$moddir/systemimager-load-scripts-ecosystem.sh" # load /scripts read $SIS_CONFIG
    inst_hook initqueue/online 50 "$moddir/systemimager-monitor-server.sh" # Start the log monitor server
    inst_hook initqueue/online 90 "$moddir/systemimager-deploy-client.sh" # Imaging occures here
    inst_hook pre-mount 10 "$moddir/systemimager-sysroot.sh" # Mount root in case we do "directboot"
    inst_hook cleanup 90 "$moddir/systemimager-cleanup.sh" # Clean any remaining systemimager remaining stuffs
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
    # Install minimal plymouth support
    PLUGINDIR=`plymouth --get-splash-plugin-path`
    inst $PLUGINDIR/script.so $initdir
    inst $PLUGINDIR/label.so $initdir
    inst /usr/share/plymouth/themes/text/text.plymouth $initdir
    inst /usr/share/plymouth/themes/details/details.plymouth $initdir

    # Install required fonts
    for font in $(find /usr/share/fonts -type f -name \*.ttf | grep -E 'DejaVuSerif.ttf|DejaVuSans.ttf')
    do
        inst $font $initdir
    done
    inst /etc/fonts/fonts.conf $initdir # fontconfig lib used by plymouth requires it.

    # Install systemimager plymouth theme
     mkdir -p $initdir/usr/share/plymouth/themes/systemimager
    cp $moddir/plymouth_theme/{*.png,systemimager.plymouth,systemimager.script} $initdir/usr/share/plymouth/themes/systemimager
    ( cd ${initdir}/usr/share/plymouth/themes; ln -sf systemimager/systemimager.plymouth default.plymouth 2>&1 )
    mkdir -p ${initdir}/etc/plymouth/
    cat > ${initdir}/etc/plymouth/plymouthd.conf <<EOF
# SystemImager is the default theme
[Daemon]
Theme=systemimager
ShowDelay=0
# DeviceTimeout=5
EOF
    cp -f ${initdir}/etc/plymouth/plymouthd.conf ${initdir}/usr/share/plymouth/plymouthd.defaults
}
