#!/bin/bash
# module-setup.sh for systemimager

check() {
    [[ $hostonly ]] && return 1
    return 255 # this module is optional
}

depends() {
    echo network syslog shutdown ssh-client i18n
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
# 95ssh-client: ssh scp
# 40network:    ip arping dhclient sed ping ping6 brctl teamd teamdctl teamnl 
# 10i18n:       setfont loadkeys kbd_mode stty
################################################################################

install() {
    # Copy systemimager template
    (cd @@SIS_INITRD_TEMPLATE@@; tar cpf - .)|(cd $initdir; tar xpf -)
    # binaries we want in initramfs
    inst_multiple -o mke2fs mkfs.ext2 mkfs.ext3 mkfs.ext4 mklost+found resize2fs tune2fs e2fsck mkfs.xfs
    inst_multiple -o dosfsck dosfslabel fatlabel fsck.fat fsck.msdos fsck.vfat mkdosfs mkfs.fat mkfs.msdos mkfs.vfat
    # Install hfs if available.
    inst_multiple -o fsck.hfs hattrib hcd hcopy hdel hdir hformat hfs hfsck hls hmkdir hmount hpwd hrename hrmdir humount hvol
    # Install btrfs is available
    inst_multiple -o btrfs btrfsck btrfstune fsck.btrfs mkfs.btrfs
    inst_multiple cut date echo env sort test false true [ expr head install tail tee tr uniq wc tac
    # inst_multiple setfont loadkeys kbd_mode stty # i18n module
    inst_multiple bc gzip bzip2 rsync parted blockdev awk ncat tty killall kexec ipcalc findmnt tput
    inst_multiple depmod blkid
    # Some helpfull commands in case of problem
    inst_multiple find strace sysctl vi clear reset lsof fuser
    inst_multiple chmod chown cp dd df dmesg echo egrep fdisk fgrep grep host hostname ifconfig init insmod kill ln ls lsmod mkdir mknod mkswap modprobe more mv ping ps rm rmdir rmmod route sed sh sleep swapoff swapon sync tar touch uname

    inst "$moddir/systemimager-lib.sh" "/lib/systemimager-lib.sh"
    inst "$moddir/autoinstall-lib.sh" "/lib/autoinstall-lib.sh"
    inst_hook cmdline 10 "$moddir/restore-persistent-cmdline.d.sh" # copy /etc/persistent-cmdline.d to /etc/cmdline.d/
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
    inst_hook initqueue/online 50 "$moddir/systemimager-monitor-server.sh" # Start the log monitor server
    inst_hook initqueue/online 90 "$moddir/systemimager-deploy-client.sh" # Imaging occures here
#    inst_hook pre/pivot 50 "$moddir/systemimager-save-inst-logs.sh"

    dracut_need_initqueue
}
