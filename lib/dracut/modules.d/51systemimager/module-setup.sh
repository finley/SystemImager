#!/bin/bash
#
#    vi:set filetype=bash et ts=4:
#
#    This file is part of SystemImager.
#
#    SystemImager is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    SystemImager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with SystemImager. If not, see <https://www.gnu.org/licenses/>.
#
#    Copyright (C) 2017-2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#    Purpose:
#      This file is the main systemimager dracut module setup file.
#

check() {
    [[ $hostonly ]] && return 1 # Module is incompatible with hostonly option.
    return 255                  # this module is optional
}

depends() {
    echo network shutdown crypt plymouth
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
    # Copy systemimager template
    (cd ${SI_INITRD_TEMPLATE:=/usr/share/systemimager/boot/initrd_template/}; tar cpf - .)|(cd $initdir; tar xpf -)

    # Generate /etc/systemimager-release
    mkdir -p $initdir/etc/ # Make sure etc already exists.
    cat > $initdir/etc/systemimager-release <<EOF
NAME="SystemImager"
VERSION="##VERSION##-##PKG_REL##"
ID="systemimager"
ID_LIKE="systemimager"
VERSION_ID="##VERSION##"
PRETTY_NAME="$(ComputePrettyName)"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:systemimager:linux:5:imager"
HOME_URL="http://www.systemimager.org/"
BUG_REPORT_URL="https://github.com/finley/SystemImager/issues"
EOF
    # Install binaries we need.

    # Network commands that we need (since RHEL-8.1, 40network doesn't include that by default)
    inst_multiple ip ping
    inst_multiple -o dhclient # dhclient is not available on NetworkManager based distros (E.g. RHEL >= 8.4)
    inst_multiple -o arping ping6 # For future needs

    # Filesystems we want to be able to handle
    inst_multiple -o mkfs.xfs xfs_admin xfs_repair
    inst_multiple -o mkfs.ext4 mkfs.ext3 mkfs.ext2 mke2fs tune2fs resize2fs tune2fs
    inst_multiple -o mkfs.fat mkfs.msdos mkfs.vfat mkfs.ntfs mkdosfs dosfslabel fatlabel
    inst_multiple -o mkfs.btrfs btrfs btrfstune
    inst_multiple -o mkfs.reiserfs mkreiserfs reiserfstune resize_reiserfs tunefs.reiserfs
    inst_multiple -o mkfs.jfs jfs_mkfs jfs_tune
    inst_multiple -o mklost+found # Do we need that?
    test -f /etc/mke2fs.conf && inst /etc/mke2fs.conf $initdir

    inst_multiple socat # also used for plymouth ask-for-password replacement (CentOS-7 at least)

    # Install console utilities (i18n is missing on Debian, so we can't rely on this module)
    inst_multiple -o setfont loadkeys kbd_mode stty

    # Install usefull debugging commands
    inst_multiple -o script

    # Install ssh and its requirements
    install_ssh

    # Install docker and its requirements
    install_docker

    # Install plymouth theme and its requirements
    install_plymouth_theme
    inst_multiple cut date echo env sort test false true [ expr head install tail tee tr uniq wc tac mktemp yes xmlstarlet jq

    # inst_multiple setfont loadkeys kbd_mode stty # i18n module
    inst_multiple -o ethtool mii-tool mii-diag

    # some command needed on debian
    inst_multiple dmidecode
    inst_multiple -o biosdecode vpddecode ownership # Not available on aarch64, thus optional

    inst_multiple bc dc gzip bzip2 rsync mkfs parted sgdisk fdisk sfdisk blockdev lsblk partprobe awk ncat tty killall kexec ipcalc findmnt findfs tput stty
    inst_multiple lvm pvcreate pvdisplay pvremove pvscan lvcreate lvdisplay lvremove lvscan lvmconfig lvmdump lvchange vgcreate vgdisplay vgremove vgscan fsadm stat
    inst_multiple chmod chown cp dd df dmesg echo egrep fgrep grep halt host hostname ifconfig init insmod kill ln ls lsmod mkdir mknod mkswap modprobe more mv poweroff ps reboot shutdown rm rmdir rmmod route sed sh sleep swapoff swapon sync tar touch uname logger od readlink
    inst_multiple depmod blkid
    inst_multiple uuidgen

    # Some helpfull command in case of problem
    inst_multiple -o find strace sysctl vi clear reset lsof fuser pidof

    # bittorent client needed when using bittorrent deployment method.
    inst_multiple rtorrent

    # udpcast client require for flamethrower deployment method
    inst_multiple udp-receiver

    # Install lsusb lsscsi lspci
    inst_multiple -o lsusb lsscsi lspci lshw
    mkdir -p "$initdir/usr/share/hwdata"
    test -f /usr/share/hwdata/usb.ids && inst /usr/share/hwdata/usb.ids $initdir
    test -f /usr/share/hwdata/pci.ids && inst /usr/share/hwdata/pci.ids $initdir
    test -f /usr/share/hwdata/pnp.ids && inst /usr/share/hwdata/pnp.ids $initdir

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

    # Deployment sub tasks called by systemimager-start.sh from initqueue/online hook
    inst "$moddir/parse-local-cfg.sh" "/sbin/parse-local-cfg" # Read local.cfg (takes precedence over cmdline)
    inst "$moddir/systemimager-load-network-infos.sh" "/sbin/systemimager-load-network-infos" # read network informations
    inst "$moddir/systemimager-pingtest.sh" "/sbin/systemimager-pingtest" # do a ping_test()
    inst "$moddir/systemimager-load-scripts-ecosystem.sh" "/sbin/systemimager-load-scripts-ecosystem" # load /scripts read $SIS_CONFIG
    inst "$moddir/systemimager-monitor-server.sh" "/sbin/systemimager-monitor-server" # Start the log monitor server
    inst "$moddir/systemimager-deploy-client.sh" "/sbin/systemimager-deploy-client" # Imaging occures here
    inst "$moddir/systemimager-check-ifaces.sh" "/sbin/systemimager-check-ifaces" # Check network interfaces concistence with cmdline ip=

    for protocol_plugin in $moddir/systemimager-xmit-*.sh
    do
        inst "$protocol_plugin" "/lib/${protocol_plugin##*/}"
    done
    mkdir -p $initdir/usr/lib/systemimager/
    inst "$moddir/do_partitions.xsl" "/lib/systemimager/do_partitions.xsl" # Installs partition xml transformation filter
    inst "$moddir/disks-layout.xsd" "/lib/systemimager/disks-layout.xsd" # Installs disks layout validation schem.
    inst "$moddir/network-config.xsd" "/lib/systemimager/network-config.xsd" # Installs network configuration validation schem.
    inst "$moddir/files-to-exclude-from-image.txt" "/lib/systemimager/files-to-exclude-from-image.txt" # Installs files to exclude from image list.
    inst_hook cmdline 10 "$moddir/systemimager-log-dispatcher.sh" # journald event dispatcher 
    inst_hook cmdline 30 "$moddir/systemimager-check-kernel.sh" # Check that kernel & initrd match.
    inst_hook cmdline 50 "$moddir/parse-systemimager.sh" # read cmdline parameters
    inst_hook cmdline 70 "$moddir/systemimager-init.sh" # Creates /run/systemimager and sets rootok
    inst_hook initqueue/finished 90 "$moddir/systemimager-wait-imaging.sh" # Waits for $SI_IMAGING_STATUS = "finished"
    inst_hook initqueue/timeout 10 "$moddir/systemimager-timeout.sh" # In case of timeout (DHCP failure, ....)
    inst_hook initqueue/online 90 "$moddir/systemimager-start.sh" 
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
    test -f /etc/docker/seccomp.json && (cd /etc; tar cpf - docker/seccomp.json)|(cd $initdir/etc; tar xpf -)
    # Install system docker config.
    [ -f /etc/sysconfig/docker ] && mkdir -p $initdir/etc/sysconfig && cp /etc/sysconfig/docker $initdir/etc/sysconfig
    [ -f /etc/default/docker ] && mkdir -p $initdir/etc/default && c /etc/default/docker $initdir/etc/default
}

my_dracut_install() {
    for FILE in $*
    do
        if test ! -f $FILE
        then
            echo "ERROR: $FILE not found"
            return -1
        else
            test ! -d $initdir${FILE%/*} && mkdir -p $initdir${FILE%/*}
            test ! -f ${initdir}${FILE} && cp $FILE ${initdir}${FILE} && echo "$FILE installed."
        fi
        ldd $FILE|while read -r -a LIB_DEP
        do
            if test -n "${LIB_DEP[2]}"
            then
                test ! -d $initdir${LIB_DEP[2]%/*} && mkdir -p $initdir${LIB_DEP[2]%/*}
                if test ! -e $initdir${LIB_DEP[2]}
                then
                    if test -L ${LIB_DEP[2]}
                    then
                        REAL_FILE_NAME=$(readlink ${LIB_DEP[2]})
                        test ! -e $initdir${LIB_DEP[2]%/*}/${REAL_FILE_NAME} && \
                            cp ${LIB_DEP[2]%/*}/${REAL_FILE_NAME} $initdir${LIB_DEP[2]%/*}/${REAL_FILE_NAME}
                        test ! -e $initdir${LIB_DEP[2]} && \
                            ln -sr $initdir${LIB_DEP[2]%/*}/${REAL_FILE_NAME} $initdir${LIB_DEP[2]}
                    else
                        cp ${LIB_DEP[2]} $initdir${LIB_DEP[2]}
                    fi
                    my_dracut_install ${LIB_DEP[2]} # Recursive call to handle sub dependancies
                    echo "${LIB_DEP[2]} installed."
                fi
            fi
        done
    done
}

################################################################################
# sub routine that installs plymouth theme
#
install_plymouth_theme() {
    # Install minimal plymouth support
    PLUGINDIR=`plymouth --get-splash-plugin-path`
    #inst $PLUGINDIR/script.so $initdir
    #inst $PLUGINDIR/label.so $initdir
    inst_libdir_file "plymouth/script.so" "plymouth/label.so"

    # Avoid DEBIAN Bug#997827 inst_libdir_file is buggy and forget to copy deps.
    # Friendly add missing files if any.
    my_dracut_install $PLUGINDIR/{script,label}.so
    # End DEBIAN specific stuff

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
ShowDelay=0.0
DeviceTimeout=2.0
EOF
    cp -f ${initdir}/etc/plymouth/plymouthd.conf ${initdir}/usr/share/plymouth/plymouthd.defaults
}

ComputePrettyName() {
	if test -r /etc/os-release
	then
		. /etc/os-release
		echo "SystemImager - $PRETTY_NAME - imager"
	elif test -r /etc/centos-release
	then
		echo "SystemImager - $(cat /etc/centos-release) - imager"
	elif test -r /etc/redhat-release
	then
		echo "SystemImager - $(cat /etc/redhat-release) - imager"
	elif test -r /etc/debian_version
	then
		echo "SystemImager - Debian GNU/Linux $(cat /etc/debian_version) - imager"
	elif test -r /etc/SuSE-release
	then
		echo "SystemImager - $(cat /etc/SuSE-release |head -1) - imager"
	else
		echo "SystemImager - Unknown Distro - imager"
	fi
}

