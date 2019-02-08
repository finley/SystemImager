#
#	"SystemImager"  
#
#   Copyright (C) 1999-2012 Brian Elliott Finley
#   Copyright (C) 2001-2004 Hewlett-Packard Company <dannf@hp.com>
#   
#   Others who have contributed to this code:
#   	Sean Dague <sean@dague.net>
#
#   $Id$
# 	 vi: set filetype=make:
#
#   2012.03.09  Brian Elliott Finley
#   * Fix egrep regex so that e2fsprogs targets show with 'make show_all_targets'
#
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#
# ERRORS when running make:
#   If you encounter errors when running "make", because make couldn't find
#   certain things that it needs, and you are fortunate enough to be building
#   on a Debian system, you can issue the following command to ensure that
#   all of the proper tools are installed.
#
#   On Debian, "apt-get build-dep systemimager ; apt-get install wget libssl-dev", will 
#   install all the right tools.  Note that you need the deb-src entries in 
#   your /etc/apt/sources.list file.
#
#
# SystemImager file location standards:
#   o images will be stored in: /var/lib/systemimager/images/
#   o pre-install scripts:      /var/lib/systemimager/scripts/pre-install/
#   o autoinstall scripts:      /var/lib/systemimager/scripts/main-install/
#   o post-install scripts:     /var/lib/systemimager/scripts/post-install/
#   o tarball files for BT:     /var/lib/systemimager/tarballs/
#   o torrent files:            /var/lib/systemimager/torrents/
#   o override directories:     /var/lib/systemimager/overrides/
#   o images config files       /var/lib/systemimager/configs/
#
#   o web gui pages:            /usr/share/systemimager/web-gui/
#
#   o kernels:                  /usr/share/systemimager/boot/`arch`/flavor/
#   o initrd.img:               /usr/share/systemimager/boot/`arch`/flavor/
#   o boel_binaries.tar.gz:     /usr/share/systemimager/boot/`arch`/flavor/
#
#   o perl libraries:           /%{perl_vendorlib}
#
#   o docs:                     Use distribution appropriate location.
#                               Defaults to /usr/share/doc/systemimager/ 
#                               for installs from tarball or source.
#
#   o man pages:                /usr/share/man/man8/
#
#   o log files:                /var/log/systemimager/
#
#   o configuration files:      /etc/systemimager/
#   o rsyncd.conf:              /etc/systemimager/rsyncd.conf
#   o rsyncd init script:       /etc/init.d/systemimager
#   o netbootmond init script:  /etc/init.d/netbootmond
#   
#   o tftp files will be copied to the appropriate destination (as determined
#     by the local SysAdmin when running "mkbootserver".
#
#   o user visible binaries:    /usr/bin
#     (si_lsimage, si_mkautoinstalldisk, si_mkautoinstallcd)
#   o sysadmin binaries:        /usr/sbin
#     (all other binaries)
#
#
# Standards for pre-defined rsync modules:
#   o boot (directory that holds architecture specific directories with
#           boot files for clients)
#   o overrides
#   o scripts
#   o torrents
#
#

DESTDIR :=
VERSION := $(shell cat VERSION)
DRACUT_MODULE_INDEX = 51

## is this an unstable release?
MINOR = $(shell echo $(VERSION) | cut -d "." -f 2)
UNSTABLE = 0
ifeq ($(shell echo "$(MINOR) % 2" | bc),1)
UNSTABLE = 1
endif

FLAVOR = $(shell cat FLAVOR)

TOPDIR  := $(CURDIR)

# RELEASE_DOCS are toplevel files that should be included with all posted
# tarballs, but aren't installed onto the destination machine by default
RELEASE_DOCS = CHANGE.LOG COPYING CREDITS README VERSION

ARCH = $(shell uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/)

TAR = $(shell gtar --version >/dev/null >&2 && echo gtar || echo tar)

# Follows is a set of arch manipulations to distinguish between ppc types
ifeq ($(ARCH),ppc64)

# Check if machine is Playstation 3
IS_PS3 = $(shell grep -q PS3 /proc/cpuinfo && echo 1)
ifeq ($(IS_PS3),1)
        ARCH = ppc64-ps3
else
        IS_PPC64 := 1
        ifneq ($(shell ls /proc/iSeries 2>/dev/null),)
                ARCH = ppc64-iSeries
        endif
endif

endif

# is userspace 64bit
USERSPACE64 := 0
ifeq ($(ARCH),ia64)
	USERSPACE64 := 1
endif

ifeq ($(ARCH),x86_64)
        USERSPACE64 := 1
endif

ifneq ($(BUILD_ARCH),)
	ARCH := $(BUILD_ARCH)
endif

#
# To be used by "make" for rules that can take it!
NCPUS := $(shell egrep -c '^processor' /proc/cpuinfo )

MANUAL_DIR = $(TOPDIR)/doc/manual_source
MANPAGE_DIR = $(TOPDIR)/doc/man
LIB_SRC = $(TOPDIR)/lib
SRC_DIR = $(TOPDIR)/src
BINARY_SRC = $(TOPDIR)/sbin

# destination directories
PREFIX = /usr
ETC  = $(DESTDIR)/etc
INITD = $(ETC)/init.d
SYSTEMD_UNITS_DIR = $(USR)/lib/systemd/system
SYSTEMD_SRC = $(TOPDIR)/systemd
USR = $(DESTDIR)$(PREFIX)
DOC  = $(USR)/share/doc/systemimager-doc
BIN = $(USR)/bin
SBIN = $(USR)/sbin
MAN8 = $(USR)/share/man/man8
LIBEXEC_DEST = $(USR)/lib/systemimager
LIB_DEST = $(DESTDIR)$(shell perl -V:vendorlib | sed s/vendorlib=\'// | sed s/\'\;//)
#LIB_DEST = $(USR)/lib/systemimager/perl
LOG_DIR = $(DESTDIR)/var/log/systemimager
LOCK_DIR = $(DESTDIR)/var/lock/systemimager

INITRD_DIR = $(TOPDIR)/initrd_source
INITRD_BUILD_DIR = $(INITRD_DIR)/build_dir
DRACUT_BASEDIR = $(shell test -d /usr/lib/dracut && echo "/lib/dracut" || echo "/share/dracut")
DRACUT_SYSDIR = /usr$(DRACUT_BASEDIR)
DRACUT_MODULES = $(USR)$(DRACUT_BASEDIR)/modules.d



BOOT_BIN_DEST     = $(USR)/share/systemimager/boot/$(ARCH)/$(FLAVOR)
BOOT_BIN_PATH     = $(PREFIX)/share/systemimager/boot/$(ARCH)/$(FLAVOR)
BOOT_NOARCH_DEST  = $(USR)/share/systemimager/boot
BOOT_NOARCH_PATH  = $(PREFIX)/share/systemimager/boot

PXE_CONF_SRC      = etc/pxelinux.cfg
PXE_CONF_DEST     = $(ETC)/systemimager/pxelinux.cfg

KBOOT_CONF_SRC    = etc/kboot.cfg
KBOOT_CONF_DEST   = $(ETC)/systemimager/kboot.cfg

BINARIES := si_mkautoinstallcd si_mkautoinstalldisk si_psh si_pcp si_pushoverrides si_clusterconfig
SBINARIES := si_addclients si_cpimage si_getimage si_mkdhcpserver si_mkdhcpstatic si_mkautoinstallscript si_mvimage si_pushupdate si_pushinstall si_rmimage si_mkrsyncd_conf si_mkclientnetboot si_netbootmond si_monitor si_monitortk si_installbtimage
CLIENT_SBINARIES  := si_updateclient si_prepareclient
COMMON_BINARIES   = si_lsimage si_mkbootpackage

IMAGESRC    = $(TOPDIR)/var/lib/systemimager/images
IMAGEDEST   = $(DESTDIR)/var/lib/systemimager/images
WARNING_FILES = $(IMAGESRC)/README $(IMAGESRC)/CUIDADO $(IMAGESRC)/ACHTUNG
AUTOINSTALL_SCRIPT_DIR = $(DESTDIR)/var/lib/systemimager/scripts
AUTOINSTALL_TORRENT_DIR = $(DESTDIR)/var/lib/systemimager/torrents
AUTOINSTALL_TARBALL_DIR = $(DESTDIR)/var/lib/systemimager/tarballs
OVERRIDES_DIR = $(DESTDIR)/var/lib/systemimager/overrides
OVERRIDES_README = $(TOPDIR)/var/lib/systemimager/overrides/README
FLAMETHROWER_STATE_DIR = $(DESTDIR)/var/state/systemimager/flamethrower

RSYNC_STUB_DIR = $(ETC)/systemimager/rsync_stubs

SI_INSTALL = $(TOPDIR)/tools/si_install --si-prefix=$(PREFIX)
GETSOURCE = $(TOPDIR)/tools/getsource

# Some root tools are probably needed to build SystemImager packages, so
# explicitly add the right paths here. -AR-
PATH := $(PATH):/sbin:/usr/sbin:/usr/local/sbin

########################################################################
#
#  BEGIN Give friendly config and packages help. -BEF-
#
IS_CONFIGURED = $(shell test -e config.inc && echo 1 || echo 0)
ifeq ($(IS_CONFIGURED),0)

.PHONY:	all
all:	show_build_deps

else

	include config.inc
# build everything, install nothing
.PHONY:	all
all:	install_initrd_template manpages


endif
#
#  END Give friendly config and packages help. -BEF-
#
########################################################################

include $(TOPDIR)/initrd_source/initrd.rul

binaries: $(BOEL_BINARIES_TARBALL) $(INITRD_BOOTFILES_DIR).build


# a full install (usefull for packaging)
.PHONY: install_all
install_all:	install_server install_client install_common install_dracut install_initrd_template install_binaries

# a complete server install
.PHONY:	install_server_all
install_server_all:	install_server install_common install_binaries install_dracut

# a complete client install
.PHONY:	install_client_all
install_client_all:	install_client install_common install_initrd_template

# install server-only architecture independent files
.PHONY:	install_server
install_server:	install_server_man 	\
				install_configs 	\
				install_server_libs
	$(SI_INSTALL) -d $(BIN)
	$(SI_INSTALL) -d $(SBIN)
	$(foreach binary, $(BINARIES), \
		$(SI_INSTALL) -m 755 $(BINARY_SRC)/$(binary) $(BIN);)
	$(foreach binary, $(SBINARIES), \
		$(SI_INSTALL) -m 755 $(BINARY_SRC)/$(binary) $(SBIN);)
ifneq ("$(wildcard /usr/lib/systemd/*system)","")
	$(SI_INSTALL) -m 755 $(BINARY_SRC)/si_mkbootserver.systemd $(SBIN)/si_mkbootserver
else
	$(SI_INSTALL) -m 755 $(BINARY_SRC)/si_mkbootserver.sysvinit $(SBIN)/si_mkbootserver
endif
	$(SI_INSTALL) -d -m 755 $(LOG_DIR)
	$(SI_INSTALL) -d -m 755 $(LOCK_DIR)
	$(SI_INSTALL) -d -m 755 $(BOOT_BIN_DEST)
	$(SI_INSTALL) -d -m 755 $(AUTOINSTALL_TARBALL_DIR)
	$(SI_INSTALL) -d -m 755 $(AUTOINSTALL_TORRENT_DIR)
	$(SI_INSTALL) -d -m 755 $(AUTOINSTALL_SCRIPT_DIR)
	$(SI_INSTALL) -d -m 755 $(AUTOINSTALL_SCRIPT_DIR)/configs
	$(SI_INSTALL) -d -m 755 $(AUTOINSTALL_SCRIPT_DIR)/disks-layouts
	$(SI_INSTALL) -d -m 755 $(AUTOINSTALL_SCRIPT_DIR)/main-install
	$(SI_INSTALL) -d -m 755 $(AUTOINSTALL_SCRIPT_DIR)/pre-install
	$(SI_INSTALL) -m 644 --backup --text \
		$(TOPDIR)/var/lib/systemimager/scripts/pre-install/99all.harmless_example_script \
		$(AUTOINSTALL_SCRIPT_DIR)/pre-install/
	$(SI_INSTALL) -m 644 --backup --text \
		$(TOPDIR)/var/lib/systemimager/scripts/pre-install/README \
		$(AUTOINSTALL_SCRIPT_DIR)/pre-install/
	$(SI_INSTALL) -d -m 755 $(AUTOINSTALL_SCRIPT_DIR)/post-install
	$(SI_INSTALL) -m 644 --backup --text \
		$(TOPDIR)/var/lib/systemimager/scripts/post-install/99all.harmless_example_script \
		$(TOPDIR)/var/lib/systemimager/scripts/post-install/10all.fix_swap_uuids\
                $(TOPDIR)/var/lib/systemimager/scripts/post-install/11all.replace_byid_device\
		$(AUTOINSTALL_SCRIPT_DIR)/post-install/
	$(SI_INSTALL) -m 644 --backup --text \
		$(TOPDIR)/var/lib/systemimager/scripts/post-install/README \
		$(AUTOINSTALL_SCRIPT_DIR)/post-install/
	$(SI_INSTALL) -d -m 755 $(OVERRIDES_DIR)
	$(SI_INSTALL) -m 644 $(OVERRIDES_README) $(OVERRIDES_DIR)
	$(SI_INSTALL) -d -m 755 $(PXE_CONF_DEST)
	$(SI_INSTALL) -m 644 --backup --text $(PXE_CONF_SRC)/message.txt \
		$(PXE_CONF_DEST)/message.txt
	$(SI_INSTALL) -m 644 --backup $(PXE_CONF_SRC)/syslinux.cfg \
		$(PXE_CONF_DEST)/syslinux.cfg
	$(SI_INSTALL) -m 644 --backup $(PXE_CONF_SRC)/syslinux.cfg.gfxboot \
		$(PXE_CONF_DEST)/syslinux.cfg.gfxboot
	$(SI_INSTALL) -m 644 --backup $(PXE_CONF_SRC)/syslinux.cfg.localboot \
		$(PXE_CONF_DEST)/syslinux.cfg.localboot
	$(SI_INSTALL) -m 644 --backup $(PXE_CONF_SRC)/syslinux.cfg.localboot \
		$(PXE_CONF_DEST)/default
	$(SI_INSTALL) -d -m 755 $(KBOOT_CONF_DEST)
#	$(SI_INSTALL) -m 644 --backup --text $(KBOOT_CONF_SRC)/message.txt \
#		$(KBOOT_CONF_DEST)/message.txt
	$(SI_INSTALL) -m 644 --backup $(KBOOT_CONF_SRC)/localboot \
		$(KBOOT_CONF_DEST)/
	$(SI_INSTALL) -m 644 --backup $(KBOOT_CONF_SRC)/default \
		$(KBOOT_CONF_DEST)/
	$(SI_INSTALL) -d -m 755 $(IMAGEDEST)
	$(SI_INSTALL) -m 644 $(WARNING_FILES) $(IMAGEDEST)
	cp -a $(IMAGEDEST)/README $(IMAGEDEST)/DO_NOT_TOUCH_THESE_DIRECTORIES
	$(SI_INSTALL) -d -m 755 $(FLAMETHROWER_STATE_DIR)

# install client-only files
.PHONY:	install_client
install_client: install_client_man install_client_libs
	mkdir -p $(ETC)/systemimager
	$(SI_INSTALL) -b -m 644 etc/updateclient.local.exclude \
	  $(ETC)/systemimager
	$(SI_INSTALL) -b -m 644 etc/client.conf \
	  $(ETC)/systemimager
	mkdir -p $(SBIN)

	$(foreach binary, $(CLIENT_SBINARIES), \
		$(SI_INSTALL) -m 755 $(BINARY_SRC)/$(binary) $(SBIN);)

# install files common to both the server and client
.PHONY:	install_common
install_common:	install_common_man install_common_libs
	mkdir -p $(ETC)/systemimager
	$(SI_INSTALL) -b -m 644 etc/UYOK.modules_to_exclude $(ETC)/systemimager
	$(SI_INSTALL) -b -m 644 etc/UYOK.modules_to_include $(ETC)/systemimager
	mkdir -p $(BIN)
	$(foreach binary, $(COMMON_BINARIES), \
		$(SI_INSTALL) -m 755 $(BINARY_SRC)/$(binary) $(BIN);)

# install files for dracut-systemimager module.
.PHONY:	install_dracut
install_dracut:
	mkdir -p $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/
ifneq (,$(wildcard /usr/*/dracut/modules.d/99base/install)) # if "" not equals second argument (not empty, thus found), we're using an old dracut)
	########## Old dracut ('check' and 'install' in charge of module install)
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/check $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/parse-systemimager-old.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/parse-systemimager.sh
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-genrules.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-start.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-netstart-old.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-sysroot-helper.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/install $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	sed -i -e "s|@@SIS_INITRD_TEMPLATE@@|$(BOOT_NOARCH_PATH)/initrd_template/|g" $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/install
else
       	########## New dracut ('module-setup.sh' in charge of module install)
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/parse-systemimager.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-sysroot.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/module-setup.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	sed -i -e "s|@@SIS_INITRD_TEMPLATE@@|$(BOOT_NOARCH_PATH)/initrd_template/|g" $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/module-setup.sh
endif
	########## Files common to all dracut versions
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/autoinstall-lib.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/disksmgt-lib.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/parse-local-cfg.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/si_inspect_client.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-check-kernel.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-cleanup.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-deploy-client.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-init.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-install-rebooted-script.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-lib.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-load-network-infos.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-load-scripts-ecosystem.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-monitor-server.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-pingtest.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-timeout.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-wait-imaging.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-warmup.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-xmit-docker.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-xmit-flamethrower.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-xmit-nfs.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-xmit-rsync.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-xmit-ssh.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-xmit-template.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/systemimager-xmit-torrent.sh $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager
	mkdir -p $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/Background.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/COPYRIGHTS $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/hide_box.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/icon_bootloader.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/icon_format.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/icon_init.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/icon_partition.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/icon_postinstall.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/icon_preinstall.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/icon_writeimage.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/no.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/action.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/dialog_bgnd.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/box.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/progress_gauge.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/README $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/SystemImagerBanner.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/systemimager.plymouth $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/systemimager.script $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme
	$(SI_INSTALL) -b -m 755 $(LIB_SRC)/dracut/modules.d/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme/yes.png $(DRACUT_MODULES)/$(DRACUT_MODULE_INDEX)systemimager/plymouth_theme

# install server-only libraries
.PHONY:	install_server_libs
install_server_libs:
	mkdir -p $(LIB_DEST)/SystemImager
	mkdir -p $(LIB_DEST)/BootMedia
	mkdir -p $(LIB_DEST)/BootGen/Dev
	mkdir -p $(LIB_DEST)/BootGen/InitrdFS
	$(SI_INSTALL) -m 644 $(LIB_SRC)/SystemImager/Server.pm  $(LIB_DEST)/SystemImager
	$(SI_INSTALL) -m 644 $(LIB_SRC)/SystemImager/HostRange.pm  $(LIB_DEST)/SystemImager
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootMedia/BootMedia.pm 	$(LIB_DEST)/BootMedia
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootMedia/MediaLib.pm 	$(LIB_DEST)/BootMedia
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootMedia/alpha.pm 	$(LIB_DEST)/BootMedia
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootMedia/i386.pm 	$(LIB_DEST)/BootMedia
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootGen/Dev.pm 		$(LIB_DEST)/BootGen/
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootGen/Dev/Devfs.pm 	$(LIB_DEST)/BootGen/Dev/
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootGen/Dev/Static.pm 	$(LIB_DEST)/BootGen/Dev/
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootGen/InitrdFS.pm 	$(LIB_DEST)/BootGen/
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootGen/InitrdFS/Cramfs.pm 	$(LIB_DEST)/BootGen/InitrdFS/
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootGen/InitrdFS/Ext2.pm 	$(LIB_DEST)/BootGen/InitrdFS/
	mkdir -p $(USR)/share/systemimager/icons
	$(SI_INSTALL) -m 644 $(LIB_SRC)/icons/serverinit.gif	$(USR)/share/systemimager/icons
	$(SI_INSTALL) -m 644 $(LIB_SRC)/icons/serverinst.gif 	$(USR)/share/systemimager/icons
	$(SI_INSTALL) -m 644 $(LIB_SRC)/icons/serverok.gif 	$(USR)/share/systemimager/icons
	$(SI_INSTALL) -m 644 $(LIB_SRC)/icons/servererror.gif 	$(USR)/share/systemimager/icons

# install client-only libraries
.PHONY:	install_client_libs
install_client_libs:
	mkdir -p $(LIB_DEST)/SystemImager
	$(SI_INSTALL) -m 644 $(LIB_SRC)/SystemImager/Client.pm $(LIB_DEST)/SystemImager

# install common libraries
.PHONY:	install_common_libs
install_common_libs:
	mkdir -p $(LIB_DEST)/SystemImager
	$(SI_INSTALL) -m 644 $(LIB_SRC)/SystemImager/Common.pm $(LIB_DEST)/SystemImager
	$(SI_INSTALL) -m 644 $(LIB_SRC)/SystemImager/Options.pm $(LIB_DEST)/SystemImager
	$(SI_INSTALL) -m 644 $(LIB_SRC)/SystemImager/Config.pm $(LIB_DEST)/SystemImager
	$(SI_INSTALL) -m 644 $(LIB_SRC)/SystemImager/UseYourOwnKernel.pm $(LIB_DEST)/SystemImager
	mkdir -p $(LIBEXEC_DEST)
	$(SI_INSTALL) -m 755 $(LIB_SRC)/confedit $(LIBEXEC_DEST)

# install the initscript & config files for the server
.PHONY:	install_configs
install_configs:
	$(SI_INSTALL) -d $(ETC)/systemimager
	$(SI_INSTALL) -m 644 etc/systemimager.conf $(ETC)/systemimager/
	$(SI_INSTALL) -m 644 etc/flamethrower.conf $(ETC)/systemimager/
	$(SI_INSTALL) -m 644 --backup etc/bittorrent.conf $(ETC)/systemimager/
	$(SI_INSTALL) -m 644 --backup etc/cluster.xml $(ETC)/systemimager/
	$(SI_INSTALL) -m 644 etc/autoinstallscript.template $(ETC)/systemimager/
	$(SI_INSTALL) -m 644 etc/autoinstallconf.template $(ETC)/systemimager/
	$(SI_INSTALL) -m 644 etc/getimage.exclude $(ETC)/systemimager/

	mkdir -p $(RSYNC_STUB_DIR)
	$(SI_INSTALL) -b -m 644 etc/rsync_stubs/10header $(RSYNC_STUB_DIR)
	[ -f $(RSYNC_STUB_DIR)/99local ] \
		&& $(SI_INSTALL) -b -m 644 etc/rsync_stubs/99local $(RSYNC_STUB_DIR)/99local.dist~ \
		|| $(SI_INSTALL) -b -m 644 etc/rsync_stubs/99local $(RSYNC_STUB_DIR)
	$(SI_INSTALL) -b -m 644 etc/rsync_stubs/README $(RSYNC_STUB_DIR)

ifneq ("$(wildcard /usr/lib/systemd/*system)","")
	[ "$(SYSTEMD_UNITS_DIR)" != "" ] || exit 1
	mkdir -p $(SYSTEMD_UNITS_DIR)
	$(SI_INSTALL) -b -m 644 $(SYSTEMD_SRC)/systemimager-server-bittorrent-seeder.service $(SYSTEMD_UNITS_DIR)
	$(SI_INSTALL) -b -m 644 $(SYSTEMD_SRC)/systemimager-server-bittorrent.service $(SYSTEMD_UNITS_DIR)
	$(SI_INSTALL) -b -m 644 $(SYSTEMD_SRC)/systemimager-server-bittorrent-tracker.service $(SYSTEMD_UNITS_DIR)
	$(SI_INSTALL) -b -m 644 $(SYSTEMD_SRC)/systemimager-server-flamethrowerd.service $(SYSTEMD_UNITS_DIR)
	$(SI_INSTALL) -b -m 644 $(SYSTEMD_SRC)/systemimager-server-monitord.service $(SYSTEMD_UNITS_DIR)
	$(SI_INSTALL) -b -m 644 $(SYSTEMD_SRC)/systemimager-server-netbootmond.service $(SYSTEMD_UNITS_DIR)
	$(SI_INSTALL) -b -m 644 $(SYSTEMD_SRC)/systemimager-server-rsyncd.service $(SYSTEMD_UNITS_DIR)
	$(SI_INSTALL) -b -m 644 $(SYSTEMD_SRC)/systemimager-server-rsyncd@.service $(SYSTEMD_UNITS_DIR)
	$(SI_INSTALL) -b -m 644 $(SYSTEMD_SRC)/systemimager-server-rsyncd.socket $(SYSTEMD_UNITS_DIR)
else
	[ "$(INITD)" != "" ] || exit 1
	mkdir -p $(INITD)
	$(SI_INSTALL) -b -m 755 etc/init.d/systemimager-server-rsyncd 			$(INITD)
	$(SI_INSTALL) -b -m 755 etc/init.d/systemimager-server-netbootmond 		$(INITD)
	$(SI_INSTALL) -b -m 755 etc/init.d/systemimager-server-flamethrowerd 	$(INITD)
	$(SI_INSTALL) -b -m 755 etc/init.d/systemimager-server-bittorrent 	$(INITD)
	$(SI_INSTALL) -b -m 755 etc/init.d/systemimager-server-monitord		$(INITD)
endif
########## END service files ##########


########## BEGIN man pages ##########
# build all of the manpages
.PHONY:	manpages install_server_man install_client_man install_common_man install_docs docs
ifeq ($(SI_BUILD_DOCS),1)
manpages:
	$(MAKE) -C $(MANPAGE_DIR) TOPDIR=$(TOPDIR)

# install the manpages for the server
install_server_man: manpages
	cd $(MANPAGE_DIR) && $(MAKE) install_server_man TOPDIR=$(TOPDIR) PREFIX=$(PREFIX) $@

# install the manpages for the client
install_client_man: manpages
	cd $(MANPAGE_DIR) && $(MAKE) install_client_man TOPDIR=$(TOPDIR) PREFIX=$(PREFIX) $@

# install manpages common to the server and client
install_common_man: manpages
	cd $(MANPAGE_DIR) && $(MAKE) install_common_man TOPDIR=$(TOPDIR) PREFIX=$(PREFIX) $@

########## END man pages ##########

# installs the manual and some examples
install_docs: docs
	mkdir -p $(DOC)
	cp -a $(MANUAL_DIR)/html $(DOC)
	#cp $(MANUAL_DIR)/*.ps $(MANUAL_DIR)/*.pdf $(DOC)
	rsync -av --exclude 'CVS/' --exclude '.svn/' doc/examples/ $(DOC)/examples/
	#XXX $(SI_INSTALL) -m 644 doc/media-api.txt $(DOC)/

# builds the manual from SGML source
docs:
	#$(MAKE) -C $(MANUAL_DIR) html ps pdf
	$(MAKE) -C $(MANUAL_DIR) html
endif

.PHONY:	install
install:
	@echo ''
	@echo 'Try "make help", and/or read README for installation details.'
	@echo ''

.PHONY:	install_binaries
install_binaries:	install_boot_files

.PHONY:	complete_source_tarball
complete_source_tarball:	$(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source.tar.bz2.sign
$(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source.tar.bz2.sign:	$(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source.tar.bz2
	cd $(TOPDIR)/tmp && gpg --detach-sign -a --output systemimager-$(VERSION)-complete_source.tar.bz2.sign systemimager-$(VERSION)-complete_source.tar.bz2
	cd $(TOPDIR)/tmp && gpg --verify systemimager-$(VERSION)-complete_source.tar.bz2.sign 

$(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source.tar.bz2: systemimager.spec
	rm -fr $(TOPDIR)/tmp
	if [ -d $(TOPDIR)/.svn ]; then \
		mkdir -p $(TOPDIR)/tmp; \
		svn export . $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source; \
	else \
		make distclean && mkdir -p $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source; \
		(cd $(TOPDIR) && $(TAR) --exclude=tmp -cvf - .) | (cd $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source && $(TAR) -xvf -); \
	fi
	cd $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source && ./configure
	$(MAKE) -C $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source get_source
	#
	# Make sure we've got all kernel source.  NOTE:  The egrep -v '-' bit is so that we don't include customized kernels (Ie: -ydl).
	$(foreach linux_version, $(shell grep 'LINUX_VERSION =' make.d/kernel.rul | egrep -v '(^#|-)' | sort -u | perl -pi -e 's#.*= ##'), \
		$(GETSOURCE) $(shell dirname $(LINUX_URL))/linux-$(linux_version).tar.bz2 $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source/src;)
	$(MAKE) -C $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source clean
ifeq ($(UNSTABLE), 1)
	if [ -f README.unstable ]; then \
		cd $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source && cp README README.tmp; \
		cd $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source && cp README.unstable README; \
		cd $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source && cat README.tmp >> README; \
		cd $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source && rm README.tmp; \
	fi
	PKG_REL=`test -d .git && git show --pretty='format:%ci'|head -1|sed -e 's/ .*//g' -e 's/-//g' -e 's/$$/git/' -e 's/^/0./'|| echo 1`; \
		cd $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source && sed -i -e "s/##PKG_REL##/$${PKG_REL}/g" systemimager.spec
else
	cd $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source && sed -i -e "s/##PKG_REL##/1/g" systemimager.spec
endif
	rm -f $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source/README.unstable
	perl -pi -e "s/^%define\s+ver\s+\d+\.\d+\.\d+.*/%define ver $(VERSION)/" \
		$(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source/systemimager.spec
	find $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source -type f -exec chmod ug+r  {} \;
	find $(TOPDIR)/tmp/systemimager-$(VERSION)-complete_source -type d -exec chmod ug+rx {} \;
	cd $(TOPDIR)/tmp && $(TAR) -ch systemimager-$(VERSION)-complete_source | bzip2 > systemimager-$(VERSION)-complete_source.tar.bz2
	@echo
	@echo "complete source tarball has been created in $(TOPDIR)/tmp"
	@echo

.PHONY:	source_tarball
source_tarball:	$(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2.sign
$(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2.sign:	$(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2
	cd $(TOPDIR)/tmp && gpg --detach-sign -a --output systemimager-$(VERSION).tar.bz2.sign systemimager-$(VERSION).tar.bz2
	cd $(TOPDIR)/tmp && gpg --verify systemimager-$(VERSION).tar.bz2.sign 

$(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2: $(TOPDIR)/systemimager.spec
	rm -fr $(TOPDIR)/tmp
	if [ -d $(TOPDIR)/.svn ]; then \
		mkdir -p $(TOPDIR)/tmp; \
		svn export . $(TOPDIR)/tmp/systemimager-$(VERSION); \
	else \
		make distclean && mkdir -p $(TOPDIR)/tmp/systemimager-$(VERSION); \
		(cd $(TOPDIR) && $(TAR) --exclude=tmp --exclude=.git -cvf - .) | (cd $(TOPDIR)/tmp/systemimager-$(VERSION) && $(TAR) -xvf -); \
	fi
ifeq ($(UNSTABLE), 1)
	if [ -f README.unstable ]; then \
		cd $(TOPDIR)/tmp/systemimager-$(VERSION) && cp README README.tmp; \
		cd $(TOPDIR)/tmp/systemimager-$(VERSION) && cp README.unstable README; \
		cd $(TOPDIR)/tmp/systemimager-$(VERSION) && cat README.tmp >> README; \
		cd $(TOPDIR)/tmp/systemimager-$(VERSION) && rm README.tmp; \
	fi
	PKG_REL=`test -d .git && git show --pretty='format:%ci'|head -1|sed -e 's/ .*//g' -e 's/-//g' -e 's/$$/git/' -e 's/^/0./' || echo 1`; \
		cd $(TOPDIR)/tmp/systemimager-$(VERSION) && sed -i -e "s/##PKG_REL##/$${PKG_REL}/g" systemimager.spec
else
	cd $(TOPDIR)/tmp/systemimager-$(VERSION) && sed -i -e "s/##PKG_REL##/1/g" systemimager.spec
endif
	rm -f $(TOPDIR)/tmp/systemimager-$(VERSION)/README.unstable
	perl -pi -e "s/^%define\s+ver\s+\d+\.\d+\.\d+.*/%define ver $(VERSION)/" \
		$(TOPDIR)/tmp/systemimager-$(VERSION)/systemimager.spec
	find $(TOPDIR)/tmp/systemimager-$(VERSION) -type f -exec chmod ug+r  {} \;
	find $(TOPDIR)/tmp/systemimager-$(VERSION) -type d -exec chmod ug+rx {} \;
	cd $(TOPDIR)/tmp && $(TAR) -ch systemimager-$(VERSION) | bzip2 > systemimager-$(VERSION).tar.bz2
	@echo
	@echo "source tarball has been created in $(TOPDIR)/tmp"
	@echo

# make the srpms for systemimager
.PHONY:	srpm
srpm: $(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2 $(TOPDIR)/systemimager.spec
	rpmbuild --define '%dist %{nil}' -ts $(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2

# make the rpms for systemimager
.PHONY:	rpm rpms
rpms: rpm
rpm: $(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2 $(TOPDIR)/systemimager.spec
	rpmbuild -tb $(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2

# make the debs for systemimager
#
# I wonder if installing libpam-dev would eliminate the need for
# "--disable-login --disable-su" in  initrd_source/make.d/util-linux.rul
# ?? -BEF-  If so, we should add libpam-dev to UBUNTU_PRECISE_BUILD_DEPS
# in initrd_source/make.d/util-linux.rul.
#
UBUNTU_PRECISE_BUILD_DEPS += dos2unix docbook-utils libncurses-dev
.PHONY: deb debs
debs: deb
deb: $(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2
	# Check package version.
	@(if [ ! "`dpkg-parsechangelog | grep ^Version: | cut -d ' ' -f 2`" = $(VERSION) ]; then \
		echo "ERROR: versions in debian/changelog doesn't match with version specified into the file VERSION"; \
		echo "Please fix it."; \
		exit 1; \
	else \
		exit 0; \
	fi)
	@cd $(TOPDIR)/tmp && $(TAR) xvjf systemimager-$(VERSION).tar.bz2
	@cd $(TOPDIR)/tmp/systemimager-$(VERSION) && make -f debian/rules debian/control
	@cd $(TOPDIR)/tmp/systemimager-$(VERSION) && dpkg-buildpackage -rfakeroot -uc -us
	@echo "=== deb packages for systemimager ==="
	@ls -l $(TOPDIR)/tmp/*.deb
	@echo "====================================="

# removes object files, docs, editor backup files, etc.
.PHONY:	clean
clean:	initrd_clean
	-$(MAKE) -C $(MANPAGE_DIR) clean
	-$(MAKE) -C $(MANUAL_DIR) clean

	## where the tarballs are built
	-rm -rf tmp

	## editor backups
	-find . -name "*~" -exec rm -f {} \;
	-find . -name "#*#" -exec rm -f {} \;
	-find . -name ".#*" -exec rm -f {} \;

	rm -f config.inc config.log config.status

# same as clean, but also removes downloaded source, stamp files, etc.
.PHONY:	distclean
distclean:	clean initrd_distclean
	-rm -rf $(SRC_DIR)

.PHONY:	help
help:  show_build_deps

#
#
# Show me a list of all targets in this entire build heirarchy
.PHONY:	show_targets
show_targets:
	@echo
	@echo Makefile targets you are probably most interested in:
	@echo ---------------------------------------------------------------------
	@echo "all"
	@echo "    Build everything you need for your machine's architecture."
	@echo "	"
	@echo "install_client_all"
	@echo "    Install all files needed by a client."
	@echo "	"
	@echo "install_server_all"
	@echo "    Install all files needed by a server."
	@echo "	"
	@echo "install_dracut"
	@echo "    Install all files needed by dracut (dracut module)."
	@echo " "
	@echo "source_tarball"
	@echo "    Make a source tarball for distribution."
	@echo "	"
	@echo "    Includes SystemImager source only.  Source for all"
	@echo "    the tools SystemImager depends on will be found in /usr/src "
	@echo "    or will be automatically downloaded at build time."
	@echo "	"
	@echo "complete_source_tarball"
	@echo "    Make a source tarball for distribution."
	@echo "    "
	@echo "    Includes all necessary source for building SystemImager and"
	@echo "    all of it's supporting tools."
	@echo "	"
	@echo "rpm"
	@echo "    Build all of the RPMs that can be build on your platform."
	@echo ""
	@echo "srpm"
	@echo "    Build yourself a source RPM."
	@echo ""
	@echo "deb"
	@echo "    Build all of the debs that can be build on your platform."
	@echo ""
	@echo "show_build_deps"
	@echo "    Shows the list of packages necessary for building on"
	@echo "    various distributions and releases."
	@echo
	@echo "show_all_targets"
	@echo "    Show all available targets."
	@echo


.PHONY: show_build_deps
show_build_deps:
	@echo "Before you can build SystemImager, you'll need to do the following:"
	@echo
	@echo "1) Install the appropriate build dependencies for your distribution."
	@echo "   The easiest path is to cut and paste the command below that is"
	@echo "   appropriate for your distribution."
	@echo
	@echo "   Ubuntu 12.04 and newer:"
	@echo "     apt-get install build-essential rpm flex $(UBUNTU_PRECISE_BUILD_DEPS)"
	@echo
	@echo "   Ubuntu 6.06:"
	@echo "     apt-get install build-essential flex $(UBUNTU_DAPPER_BUILD_DEPS)"
	@echo
	@echo "   RHEL6, CentOS6, and friends:"
	@echo "     yum install rpm-build patch wget flex bc docbook-utils dos2unix device-mapper-devel gperf pam-devel quilt lzop glib2-devel PyXML glibc-static $(RHEL6_BUILD_DEPS)"
	@echo
	@echo "   Debian Stable:"
	@echo "     apt-get install build-essential flex $(DEBIAN_STABLE_BUILD_DEPS)"
	@echo     
	@echo "   NOTE: Other distro versions may build fine, and are simply untested by"
	@echo "         the SystemImage dev team."
	@echo
	@echo "2) Run './configure'"
	@echo
	@echo "3) Run 'make show_targets' to see a list of make targets from which you can"
	@echo "   choose."
	@echo

.PHONY:	show_all_targets
SHOW_TARGETS_ALL_MAKEFILES = $(shell find . make.d/ initrd_source/ initrd_source/make.d/  -maxdepth 1 -name 'Makefile' -or -name '*.rul' )
show_all_targets:
	@echo All Available Targets Include:
	@echo ---------------------------------------------------------------------
	@cat $(SHOW_TARGETS_ALL_MAKEFILES) | egrep '^[a-zA-Z0-9_]+:' | sed 's/:.*//' | sort -u
	@echo
