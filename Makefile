#
#	"SystemImager"  
#
#   Copyright (C) 1999-2004 Brian Elliott Finley
#   Copyright (C) 2001-2004 Hewlett-Packard Company <dannf@hp.com>
#   
#   Others who have contributed to this code:
#   	Sean Dague <sean@dague.net>
#
#   $Id$
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
#	2004.04.13 	Brian Elliott Finley
#	- Michael Jennings suggested permissions changes on some files.  done.
#	2004.09.08  Brian Elliott Finley
#	- add MKSWAP_BINARY
#   2004.09.10  Brian Elliott Finley
#   - include as part of standard boel_binaries_tarball
#   - move to using gpg .sign files only.  no need for md5 too, especially
#     if we want to be knee-jerk reactionary to the recent md5 hash collision
#     reports. :-)
#   2004.09.11  Brian Elliott Finley
#   - install everything in the doc/examples directory.
#   2004.09.19  Brian Elliott Finley
#   - add 'show_targets' target.
#   2004.10.13  Brian Elliott Finley
#   - add hfsutils
#   2004.10.24  Brian Elliott Finley
#   - get rid of source, which may also exist as a link to the kernel source
#     directory
#   2004.12.13  Josh Aas
#   - make 'make (rpm|srpm)' work again
#   2005.01.15  Brian Elliott Finley
#   - install UseYourOwnKernel.pm as part of 'make install_common_libs'
# 	2005-01-12 Andrea Righi
# 	- patches to add lvm support
# 	2005.01.30 Brian Elliott Finley
# 	- 'make source_tarball' -> do cvs export, instead of 'find+cp -> find+rm'
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
#   o autoinstall scripts:      /var/lib/systemimager/scripts/
#   o override directories:     /var/lib/systemimager/overrides/
#
#   o web gui pages:            /usr/share/systemimager/web-gui/
#
#   o kernels:                  /usr/share/systemimager/boot/`arch`/flavor/
#   o initrd.img:               /usr/share/systemimager/boot/`arch`/flavor/
#   o boel_binaries.tar.gz:     /usr/share/systemimager/boot/`arch`/flavor/
#
#   o perl libraries:           /usr/lib/systemimager/perl/
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
#     (lsimage, mkautoinstalldiskette, mkautoinstallcd)
#   o sysadmin binaries:        /usr/sbin
#     (all other binaries)
#
# Standards for pre-defined rsync modules:
#   o boot (directory that holds architecture specific directories with
#           boot files for clients)
#   o overrides
#   o scripts
#
# To include the ctcs test suite, and associated files, do a 'make WITH_CTCS=1 all'
#

DESTDIR =
VERSION = $(shell cat VERSION)
CVS_TAG = $(shell cat VERSION | tr '.' '_')
CVSROOT=$(shell cat CVS/Root)

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
RELEASE_DOCS = CHANGE.LOG COPYING CREDITS ERRATA README VERSION

# This includes the file which is autoconf generated
include config.inc

# should we be messing with the user's PATH? -dannf
# no i don't think so. -bef-
#PATH = /sbin:/bin:/usr/sbin:/usr/bin:/usr/bin/X11:/usr/local/sbin:/usr/local/bin
ARCH = $(shell uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/)

# Follows is a set of arch manipulations to distinguish between ppc types
ifeq ($(ARCH),ppc64)
IS_PPC64 := 1
ifneq ($(shell ls /proc/iSeries 2>/dev/null),)
        ARCH := ppc64-iSeries
endif
endif

# is userspace 64bit
USERSPACE64 := 0
ifeq ($(ARCH),ia64) 
	USERSPACE64 :=1
endif

ifneq ($(BUILD_ARCH),)
	ARCH := $(BUILD_ARCH)
endif

MANUAL_DIR = $(TOPDIR)/doc/manual_source
MANPAGE_DIR = $(TOPDIR)/doc/man
PATCH_DIR = $(TOPDIR)/patches
LIB_SRC = $(TOPDIR)/lib
SRC_DIR = $(TOPDIR)/src
BINARY_SRC = $(TOPDIR)/sbin

# destination directories
PREFIX = /usr
ETC  = $(DESTDIR)/etc
INITD = $(ETC)/init.d
USR = $(DESTDIR)$(PREFIX)
DOC  = $(USR)/share/doc/systemimager-doc
BIN = $(USR)/bin
SBIN = $(USR)/sbin
MAN8 = $(USR)/share/man/man8
LIB_DEST = $(USR)/lib/systemimager/perl
LOG_DIR = $(DESTDIR)/var/log/systemimager
LOCK_DIR = $(DESTDIR)/var/lock/systemimager

INITRD_DIR = $(TOPDIR)/initrd_source

BOOT_BIN_DEST     = $(USR)/share/systemimager/boot/$(ARCH)/$(FLAVOR)

PXE_CONF_SRC      = etc/pxelinux.cfg
PXE_CONF_DEST     = $(ETC)/systemimager/pxelinux.cfg

BINARIES := si_mkautoinstallcd si_mkautoinstalldiskette si_mkbootmedia
SBINARIES := si_addclients si_cpimage si_getimage si_mkdhcpserver si_mkdhcpstatic si_mkautoinstallscript si_mkbootserver si_mvimage si_pushupdate si_rmimage si_mkrsyncd_conf si_mkclientnetboot si_netbootmond si_imagemanip si_mkbootpackage si_monitor
CLIENT_SBINARIES  := si_updateclient si_prepareclient
COMMON_BINARIES   = si_lsimage

IMAGESRC    = $(TOPDIR)/var/lib/systemimager/images
IMAGEDEST   = $(DESTDIR)/var/lib/systemimager/images
WARNING_FILES = $(IMAGESRC)/README $(IMAGESRC)/CUIDADO $(IMAGESRC)/ACHTUNG
AUTOINSTALL_SCRIPT_DIR = $(DESTDIR)/var/lib/systemimager/scripts
OVERRIDES_DIR = $(DESTDIR)/var/lib/systemimager/overrides
OVERRIDES_README = $(TOPDIR)/var/lib/systemimager/overrides/README
FLAMETHROWER_STATE_DIR = $(DESTDIR)/var/state/systemimager/flamethrower

RSYNC_STUB_DIR = $(ETC)/systemimager/rsync_stubs

CHECK_FLOPPY_SIZE = expr \`du -b $(INITRD_DIR)/initrd.img | cut -f 1\` + \`du -b $(LINUX_IMAGE) | cut -f 1\`

BOEL_BINARIES_DIR = $(TOPDIR)/tmp/boel_binaries
BOEL_BINARIES_TARBALL = $(BOEL_BINARIES_DIR).tar.gz

SI_INSTALL = $(TOPDIR)/tools/si_install --si-prefix=$(PREFIX)
GETSOURCE = $(TOPDIR)/tools/getsource

# build everything, install nothing
.PHONY:	all
all:	config.inc zlib openssl util-linux $(BOEL_BINARIES_TARBALL) kernel $(INITRD_DIR)/initrd.img manpages

.PHONY:	help
help:  show_targets

#
#
# Show me a list of all targets in this entire build heirarchy
.PHONY:	show_targets
SHOW_TARGETS_ALL_MAKEFILES = $(shell find . -name 'Makefile' -or -name '*.rul')
show_targets:
	@echo
	@echo Makefile targets you are probably most interested in:
	@echo ---------------------------------------------------------------------
	@echo   all
	@echo   install_client_all
	@echo   install_server_all
	@echo   install_boel_binaries_tarball
	@echo   install_initrd
	@echo
	@echo
	@echo All Available Targets Include:
	@echo ---------------------------------------------------------------------
	cat $(SHOW_TARGETS_ALL_MAKEFILES) | egrep '^[a-z_]+:' | sed 's/:.*//' | sort -u
	@echo

binaries: $(BOEL_BINARIES_TARBALL) kernel $(INITRD_DIR)/initrd.img

# All has been modified as docs don't build on non debian platforms
#
#all:	$(BOEL_BINARIES_TARBALL) kernel $(INITRD_DIR)/initrd.img docs manpages

# Now include the other targets
# This has to be right after all to make all the default target
include $(TOPDIR)/make.d/*.rul $(INITRD_DIR)/initrd.rul

BOEL_MKLIBS_LOCATIONS := "$(SRC_DIR)/$(ZLIB_DIR)"
BOEL_MKLIBS_LOCATIONS := "$(BOEL_MKLIBS_LOCATIONS):$(SRC_DIR)/$(OPENSSL_DIR)"
BOEL_MKLIBS_LOCATIONS := "$(BOEL_MKLIBS_LOCATIONS):$(SRC_DIR)/$(POPT_DIR)/.libs"
BOEL_MKLIBS_LOCATIONS := "$(BOEL_MKLIBS_LOCATIONS):$(SRC_DIR)/$(PARTED_DIR)/libparted/.libs"
BOEL_MKLIBS_LOCATIONS := "$(BOEL_MKLIBS_LOCATIONS):$(SRC_DIR)/$(DISCOVER_DIR)/lib/.libs"
BOEL_MKLIBS_LOCATIONS := "$(BOEL_MKLIBS_LOCATIONS):$(SRC_DIR)/$(DEVMAPPER_DIR)/lib/ioctl"
BOEL_MKLIBS_LOCATIONS := "$(BOEL_MKLIBS_LOCATIONS):$(SRC_DIR)/$(E2FSPROGS_DIR)/lib"

ifeq ($(USERSPACE64),1)
	BOEL_MKLIBS_LOCATIONS := "$(BOEL_MKLIBS_LOCATIONS):/lib64:/usr/lib64"
endif

# a complete server install
.PHONY:	install_server_all
install_server_all:	install_server install_common install_binaries

# a complete client install
.PHONY:	install_client_all
install_client_all:	install_client install_common

# install server-only architecture independent files
.PHONY:	install_server
install_server:	install_server_man install_configs install_server_libs
	$(SI_INSTALL) -d $(BIN)
	$(SI_INSTALL) -d $(SBIN)
	$(foreach binary, $(BINARIES), \
		$(SI_INSTALL) -m 755 $(BINARY_SRC)/$(binary) $(BIN);)
	$(foreach binary, $(SBINARIES), \
		$(SI_INSTALL) -m 755 $(BINARY_SRC)/$(binary) $(SBIN);)
	$(SI_INSTALL) -d -m 755 $(LOG_DIR)
	$(SI_INSTALL) -d -m 755 $(LOCK_DIR)
	$(SI_INSTALL) -d -m 755 $(BOOT_BIN_DEST)
	$(SI_INSTALL) -d -m 755 $(AUTOINSTALL_SCRIPT_DIR)

	$(SI_INSTALL) -d -m 755 $(AUTOINSTALL_SCRIPT_DIR)/pre-install
	$(SI_INSTALL) -m 644 --backup --text \
		$(TOPDIR)/var/lib/systemimager/scripts/pre-install/99all.harmless_example_script \
		$(AUTOINSTALL_SCRIPT_DIR)/pre-install/

	$(SI_INSTALL) -d -m 755 $(AUTOINSTALL_SCRIPT_DIR)/post-install
	$(SI_INSTALL) -m 644 --backup --text \
		$(TOPDIR)/var/lib/systemimager/scripts/post-install/99all.harmless_example_script \
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
	$(SI_INSTALL) -m 644 --backup $(PXE_CONF_SRC)/syslinux.cfg.localboot \
		$(PXE_CONF_DEST)/syslinux.cfg.localboot
	$(SI_INSTALL) -m 644 --backup $(PXE_CONF_SRC)/syslinux.cfg.localboot \
		$(PXE_CONF_DEST)/default

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
	mkdir -p $(BIN)
	$(foreach binary, $(COMMON_BINARIES), \
		$(SI_INSTALL) -m 755 $(BINARY_SRC)/$(binary) $(BIN);)

# install server-only libraries
.PHONY:	install_server_libs
install_server_libs:
	mkdir -p $(LIB_DEST)/SystemImager
	mkdir -p $(LIB_DEST)/BootMedia
	$(SI_INSTALL) -m 644 $(LIB_SRC)/SystemImager/Server.pm  $(LIB_DEST)/SystemImager
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootMedia/BootMedia.pm 	$(LIB_DEST)/BootMedia
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootMedia/MediaLib.pm 	$(LIB_DEST)/BootMedia
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootMedia/alpha.pm 	$(LIB_DEST)/BootMedia
	$(SI_INSTALL) -m 644 $(LIB_SRC)/BootMedia/i386.pm 	$(LIB_DEST)/BootMedia

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
	$(SI_INSTALL) -m 755 $(LIB_SRC)/confedit $(LIB_DEST)

# checks the sized of the i386 kernel and initrd to make sure they'll fit 
# on an autoinstall diskette
.PHONY:	check_floppy_size
check_floppy_size:	$(LINUX_IMAGE) $(INITRD_DIR)/initrd.img
ifeq ($(ARCH), i386)
	@### see if the kernel and ramdisk are larger than the size of a 1.44MB
	@### floppy image, minus about 10k for syslinux stuff
	@echo -n "Ramdisk + Kernel == "
	@echo "`$(CHECK_FLOPPY_SIZE)`"
	@echo "                    1454080 is the max that will fit."
	@[ `$(CHECK_FLOPPY_SIZE)` -lt 1454081 ] || \
	     (echo "" && \
	      echo "************************************************" && \
	      echo "Dammit.  The kernel and ramdisk are too large.  " && \
	      echo "************************************************" && \
	      exit 1)
	@echo " - ok, that should fit on a floppy"
endif

# install the initscript & config files for the server
.PHONY:	install_configs
install_configs:
	$(SI_INSTALL) -d $(ETC)/systemimager
	$(SI_INSTALL) -m 644 etc/systemimager.conf $(ETC)/systemimager/
	$(SI_INSTALL) -m 644 etc/flamethrower.conf $(ETC)/systemimager/
	$(SI_INSTALL) -m 644 etc/autoinstallscript.template $(ETC)/systemimager/
	$(SI_INSTALL) -m 644 etc/imagemanip.conf $(ETC)/systemimager/
	$(SI_INSTALL) -m 644 etc/imagemanip.perm $(ETC)/systemimager/

	mkdir -p $(RSYNC_STUB_DIR)
	$(SI_INSTALL) -b -m 644 etc/rsync_stubs/10header $(RSYNC_STUB_DIR)
	[ -f $(RSYNC_STUB_DIR)/99local ] \
		&& $(SI_INSTALL) -b -m 644 etc/rsync_stubs/99local $(RSYNC_STUB_DIR)/99local.dist~ \
		|| $(SI_INSTALL) -b -m 644 etc/rsync_stubs/99local $(RSYNC_STUB_DIR)
	$(SI_INSTALL) -b -m 644 etc/rsync_stubs/README $(RSYNC_STUB_DIR)

	[ "$(INITD)" != "" ] || exit 1
	mkdir -p $(INITD)
	$(SI_INSTALL) -b -m 755 etc/init.d/systemimager-server-rsyncd 			$(INITD)
	$(SI_INSTALL) -b -m 755 etc/init.d/systemimager-server-netbootmond 		$(INITD)
	$(SI_INSTALL) -b -m 755 etc/init.d/systemimager-server-flamethrowerd 	$(INITD)

########## END initrd ##########


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
	cp $(MANUAL_DIR)/*.ps $(MANUAL_DIR)/*.pdf $(DOC)
	rsync -av --exclude 'CVS/' doc/examples/ $(DOC)/examples/
	#XXX $(SI_INSTALL) -m 644 doc/media-api.txt $(DOC)/

# builds the manual from SGML source
docs:
	$(MAKE) -C $(MANUAL_DIR) html ps pdf
endif

# pre-download the source to other packages that are needed by 
# the build system
.PHONY:	get_source
get_source:	$(ALL_SOURCE)

.PHONY:	install
install: 
	@echo ''
	@echo 'Read README for installation details.'
	@echo ''

.PHONY:	install_binaries
install_binaries:	install_kernel install_initrd \
			install_boel_binaries_tarball \
			install_initrd_template


################################################################################
#
#	boel_binaries_tarball
#
# 	Perhaps there could be problems here in building multiple arch's from
# 	a single source directory, but we'll deal with that later...  Perhaps use
# 	$(TOPDIR)/tmp/$(ARCH)/ instead of just $(TOPDIR)/tmp/. -BEF-
#
.PHONY:	install_boel_binaries_tarball
install_boel_binaries_tarball:	$(BOEL_BINARIES_TARBALL)
	$(SI_INSTALL) -m 644 $(BOEL_BINARIES_TARBALL) $(BOOT_BIN_DEST)
	# boel_binaries.tar.gz installed.

.PHONY:	boel_binaries_tarball
boel_binaries_tarball:	$(BOEL_BINARIES_TARBALL)

$(BOEL_BINARIES_TARBALL):	\
				$(BC_BINARY) \
				$(TAR_BINARY) \
				$(GZIP_BINARY) \
				$(DISCOVER_BINARY) \
				$(DISCOVER_DATA_FILES) \
				$(HFSUTILS_BINARY) \
				$(MKDOSFS_BINARY) \
				$(MKE2FS_BINARY) \
				$(TUNE2FS_BINARY) \
				$(PARTED_BINARY) \
				$(SFDISK_BINARY) \
				$(MKSWAP_BINARY) \
				$(RAIDTOOLS_BINARIES) \
				$(MKREISERFS_BINARY) \
				$(MKJFS_BINARY) \
				$(MKXFS_BINARY) \
				$(CTCS_BINARY) \
				$(DEPMOD_BINARY) \
				$(INSMOD_BINARY) \
				$(MODPROBE_BINARY) \
				$(OPENSSH_BINARIES) \
				$(OPENSSH_CONF_FILES) \
				$(LVM_BINARY) \
				$(SRC_DIR)/modules_build-stamp
	#
	# Put binaries in the boel_binaries_tarball...
	#
	rm -fr $(BOEL_BINARIES_DIR)
	mkdir -m 755 -p $(BOEL_BINARIES_DIR)/bin
	mkdir -m 755 -p $(BOEL_BINARIES_DIR)/sbin
	mkdir -m 755 -p $(BOEL_BINARIES_DIR)/etc/ssh
	install -m 755 --strip $(BC_BINARY) 			$(BOEL_BINARIES_DIR)/bin/
	install -m 755 --strip $(TAR_BINARY) 			$(BOEL_BINARIES_DIR)/bin/
	install -m 755 --strip $(GZIP_BINARY) 			$(BOEL_BINARIES_DIR)/bin/
	install -m 755 --strip $(DEPMOD_BINARY)			$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(INSMOD_BINARY)			$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(MODPROBE_BINARY)		$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(DISCOVER_BINARY) 		$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(HFSUTILS_BINARY) 		$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(MKDOSFS_BINARY) 		$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(MKE2FS_BINARY) 		$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(TUNE2FS_BINARY) 		$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(PARTED_BINARY)			$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(SFDISK_BINARY)			$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(MKSWAP_BINARY)			$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(RAIDTOOLS_BINARIES) 		$(BOEL_BINARIES_DIR)/sbin/
	cd $(BOEL_BINARIES_DIR)/sbin/ && ln -f raidstart raidstop
	install -m 755 --strip $(MKREISERFS_BINARY) 		$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(MKJFS_BINARY) 			$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(OPENSSH_BINARIES) 		$(BOEL_BINARIES_DIR)/sbin/
	install -m 644 $(OPENSSH_CONF_FILES) 			$(BOEL_BINARIES_DIR)/etc/ssh
ifdef MKXFS_BINARY
	install -m 755 --strip $(MKXFS_BINARY) $(BOEL_BINARIES_DIR)/sbin/
endif
	#
	# 2005-01-18 Andrea Righi
	# 
	install -m 755 --strip $(LVM_BINARY)			$(BOEL_BINARIES_DIR)/sbin/
	#
	# Create LVM symlinks to lvm binary
	#
	cd $(BOEL_BINARIES_DIR)/sbin && $(foreach binary,$(shell cat $(SRC_DIR)/$(LVM_DIR)/tools/.commands),ln -s -f lvm $(binary) && ) /bin/true

	mkdir -m 755 -p $(BOEL_BINARIES_DIR)/lib
	test ! -d /lib64 || mkdir -m 755 -p $(BOEL_BINARIES_DIR)/lib64

	#
ifdef WITH_CTCS
	mkdir -p $(BOEL_BINARIES_DIR)/usr/src
	cp -a $(LINUX_SRC)/ $(BOEL_BINARIES_DIR)/usr/src/linux/
	$(MAKE) -sw -C $(BOEL_BINARIES_DIR)/usr/src/linux/ clean
	cp -a $(SRC_DIR)/$(CTCS_DIR)/ $(BOEL_BINARIES_DIR)/usr/src/ctcs/
	tar -cv $(CTCS_OTHER_FILES) | tar -C $(BOEL_BINARIES_DIR) -xv
	cd /usr/include && h2ph -d $(BOEL_BINARIES_DIR)/usr/lib/perl/5.6.1 asm/*
endif
	#
	# Copy over miscellaneous other files...
	#
	mkdir -m 755 -p $(BOEL_BINARIES_DIR)/usr/share/discover
	install -m 644 $(DISCOVER_DATA_FILES) $(BOEL_BINARIES_DIR)/usr/share/discover

	# copy over libnss files for non-uclibc arches
	# (mklibs doesn't automatically pull these in)
ifeq ($(USERSPACE64),1)
	## there maybe older compat versions that we don't want, but
	## they have names like libnss1_dns so this shouldn't copy them.
	## we do the sort so that filse from /lib64 files will be copied over
	## identically named files from /lib
	#cp -a $(sort $(wildcard /lib*/libnss_dns-*)) $(BOEL_BINARIES_DIR)/lib
	## if multiple libnss_dns.so.* symlinks exist, only grab the one with
	## the greatest soname, which should drop the old compat versions
	#cp -a $(word $(words $(sort $(wildcard /lib*/libnss_dns*))), \
	#  $(sort $(wildcard /lib*/libnss_dns*))) $(BOEL_BINARIES_DIR)/lib
	#
	#
	#XXX trying new code below -BEF- XXX  cp -a $(sort $(wildcard /lib*/libnss_dns-*)) $(BOEL_BINARIES_DIR)/lib
	#XXX we're not concerned about space here, why are we trying to only get the largest .so name?  why not all?
	#XXX simplifying the code.  let's see if anything breaks. -BEF-
	cp -a /lib/libnss_dns*   $(BOEL_BINARIES_DIR)/lib
	test ! -d /lib64 || cp -a /lib64/libnss_dns* $(BOEL_BINARIES_DIR)/lib64
endif

	#
	# Use the mklibs script from Debian to find and copy libraries and 
	# any soft links.  Note: This does not require PIC libraries -- it will
	# copy standard libraries if it can't find a PIC equivalent.  -BEF-
	#
ifneq ($(ARCH),i386)
	# But copy over ld.so* files first.  for some reason these don't always 
	# get copied by mklibs if both /lib/ld* and /lib64/ld* exist) -BEF-
	#
	cp -a /lib/ld*   $(BOEL_BINARIES_DIR)/lib
	test ! -d /lib64 || cp -a /lib64/ld* $(BOEL_BINARIES_DIR)/lib64
endif

	cd $(BOEL_BINARIES_DIR) \
		&& $(PYTHON) $(TOPDIR)/initrd_source/mklibs -L $(BOEL_MKLIBS_LOCATIONS) -v -d lib bin/* sbin/*
	#
	# Include other files required by openssh that apparently aren't 
	# picked up by mklibs for some reason. -BEF-
	#
	tar -cv $(OPENSSH_OTHER_FILES) | tar -C $(BOEL_BINARIES_DIR) -xv
	#
	#
	# install kernel modules. -BEF-
	#
ifdef DEPMOD_BINARY
	$(MAKE) -C $(LINUX_SRC) modules_install INSTALL_MOD_PATH="$(BOEL_BINARIES_DIR)" DEPMOD=$(DEPMOD_BINARY)
	#
	# If the build system doesn't have module-init-tools installed, and
	# our modules need it, we need to use the depmod we built
	#
	# The find command is to figure out the kernel version string
	#
	$(DEPMOD_BINARY) -r -b $(BOEL_BINARIES_DIR) \
	  $(shell find $(BOEL_BINARIES_DIR)/lib/modules -type d -mindepth 1 \
                       -maxdepth 1 -printf "%f")
	#
else
	$(MAKE) -C $(LINUX_SRC) modules_install INSTALL_MOD_PATH="$(BOEL_BINARIES_DIR)"
endif
	#
	# get rid of build, which may exist as a link to the kernel source directory (won't exist in BOEL anyway). -BEF-
	rm -f $(BOEL_BINARIES_DIR)/lib/modules/*/build
	#
	# get rid of source, which may also exist as a link to the kernel source directory (won't exist in BOEL anyway). -BEF-
	rm -f $(BOEL_BINARIES_DIR)/lib/modules/*/source
	#
	# Tar it up, baby! -BEF-
	cd $(BOEL_BINARIES_DIR) && tar -cv * | gzip -9 > $(BOEL_BINARIES_TARBALL)
	#
	# Note: This tarball should be installed to the "boot/$(ARCH)/$(FLAVOR)" directory.

#
################################################################################


.PHONY:	source_tarball
source_tarball:	$(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2.sign

$(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2.sign:	$(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2
	cd $(TOPDIR)/tmp && gpg --detach-sign -a --output systemimager-$(VERSION).tar.bz2.sign systemimager-$(VERSION).tar.bz2
	cd $(TOPDIR)/tmp && gpg --verify systemimager-$(VERSION).tar.bz2.sign 


$(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2: systemimager.spec
	mkdir -p tmp/
	cd tmp && cvs -d$(CVSROOT) export -r v$(CVS_TAG) systemimager
	mv tmp/systemimager tmp/systemimager-$(VERSION)
	$(MAKE) -C $(TOPDIR)/tmp/systemimager-$(VERSION) distclean
	$(MAKE) -C $(TOPDIR)/tmp/systemimager-$(VERSION) get_source
ifeq ($(UNSTABLE), 1)
	cd $(TOPDIR)/tmp/systemimager-$(VERSION) && cp README README.tmp
	cd $(TOPDIR)/tmp/systemimager-$(VERSION) && cp README.unstable README
	cd $(TOPDIR)/tmp/systemimager-$(VERSION) && cat README.tmp >> README
	cd $(TOPDIR)/tmp/systemimager-$(VERSION) && rm README.tmp
endif
	rm $(TOPDIR)/tmp/systemimager-$(VERSION)/README.unstable
	perl -pi -e "s/^%define\s+ver\s+\d+\.\d+\.\d+.*/%define ver $(VERSION)/" \
		$(TOPDIR)/tmp/systemimager-$(VERSION)/systemimager.spec
	find . -type f -exec chmod ug+r  {} \;
	find . -type d -exec chmod ug+rx {} \;
	cd $(TOPDIR)/tmp && tar -ch systemimager-$(VERSION) | bzip2 > systemimager-$(VERSION).tar.bz2
	@echo
	@echo "source tarball has been created in $(TOPDIR)/tmp"
	@echo

# create user-distributable tarballs for the server and the client
.PHONY:	tarballs
tarballs:	
	@ echo -e "\nbinary tarballs are no longer supported\n"

# make the srpms for systemimager
.PHONY:	srpm
srpm: $(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2
	rpmbuild -ts $(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2

# make the rpms for systemimager
.PHONY:	rpm
rpm: $(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2
	rpmbuild -tb $(TOPDIR)/tmp/systemimager-$(VERSION).tar.bz2

# removes object files, docs, editor backup files, etc.
.PHONY:	clean
clean:	$(subst .rul,_clean,$(shell cd $(TOPDIR)/make.d && ls *.rul)) initrd_clean
	-$(MAKE) -C $(MANPAGE_DIR) clean
	-$(MAKE) -C $(MANUAL_DIR) clean

	## where the tarballs are built
	-rm -rf tmp

	## editor backups
	-find . -name "*~" -exec rm -f {} \;
	-find . -name "#*#" -exec rm -f {} \;
	-find . -name ".#*" -exec rm -f {} \;

# same as clean, but also removes downloaded source, stamp files, etc.
.PHONY:	distclean
distclean:	clean initrd_distclean
	-rm -rf $(SRC_DIR) $(INITRD_SRC_DIR)
