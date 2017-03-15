#!/bin/bash
# module-setup.sh for systemimager

check() {
    [[ $hostonly ]] && return 1
    return 255 # this module is optional
}

depends() {
    echo network syslog shutdown ssh-client
    case "$(uname -m)" in
        s390*) echo cms ;;
    esac
    return 0
}

install() {
    arch=$(uname -m)
    # Copy systemimager template
    (cd /usr/share/systemimager/boot/${arch}/standard/initrd_template/; tar cpf - .)|(cd $initdir; tar xpf -)
    # binaries we want in initramfs
    inst_multiple mke2fs mkfs.ext2 mkfs.ext3 mkfs.ext4 mklost+found resize2fs tune2fs e2fsck mkfs.xfs
    inst_multiple dosfsck dosfslabel fatlabel fsck.fat fsck.msdos fsck.vfat mkdosfs mkfs.fat mkfs.msdos mkfs.vfat
    #inst_multiple fsck.hfs hattrib hcd hcopy hdel hdir hformat hfs hfsck hls hmkdir hmount hpwd hrename hrmdir humount hvol
    inst_multiple btrfs btrfsck btrfstune fsck.btrfs mkfs.btrfs
    inst_multiple cut date echo env sort test false true [ expr head install tail tee tr uniq wc tac
    inst_multiple bc gzip bzip2 rsync parted loadkeys blockdev awk clear reset ncat stty tty killall kexec ipcalc
    inst_multiple systemd-cat
    inst_multiple depmod blkid
    inst_multiple find strace
    inst_multiple chmod chown cp dd df dmesg echo egrep fdisk fgrep grep halt hostname ifconfig init insmod kill ln ls lsmod mkdir mknod mkswap modprobe more mv ping poweroff ps reboot rm rmdir rmmod route sed sh sleep swapoff swapon sync tar touch uname vi
    # inst_multiple -o syslogd
    #inst_binary /usr/libexec/anaconda/dd_extract /bin/dd_extract

    inst "$moddir/systemimager-lib.sh" "/lib/systemimager-lib.sh"
    inst "$moddir/autoinstall-lib.sh" "/lib/autoinstall-lib.sh"
    # We need to overwrite 40network dhclient-script with our version that handles /etc/dhcp/dhclient-exit-hooks
    inst_script "$moddir/dhclient-script.sh" "/sbin/dhclient-script"
    inst_hook cmdline 90 "$moddir/parse-sis-options.sh" # Creates /tmp/kernel_append_parameter_variables.txt
    inst_hook initqueue/settled 50 "$moddir/systemimager-init.sh" # Creates /run/systemimager
    inst_hook initqueue/finished 90 "$moddir/systemimager-wait-imaging.sh" # Waits for file /tmp/SIS_action
    inst_hook initqueue/timeout 10 "$moddir/systemimager-timeout.sh" # In case of timeout (DHCP failure, ....)
    inst_hook initqueue/online 00 "$moddir/systemimager-ifcfg.sh" # creates /tmp/variables.txt
    inst_hook initqueue/online 10 "$moddir/systemimager-pingtest.sh" # do a ping_test()
    inst_hook initqueue/online 50 "$moddir/systemimager-monitor-server.sh" # Start the log monitor server
    inst_hook initqueue/online 90 "$moddir/systemimager-deploy-client.sh" # Imaging occures here
#    inst_hook pre-pivot 50 "$moddir/systemimager-save-inst-logs.sh"

    dracut_need_initqueue
}
