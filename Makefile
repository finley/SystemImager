#
# "VA SystemImager" - Copyright (C) 1999-2001 Brian Elliott Finley <brian@valinux.com> 
#
# This file: Makefile
#
#   Written by Dann Frazier <dannf@ldl.fc.hp.com>
#

# HEY!
# this Makefile isn't yet fully functional - here's a list of things that
# need to happen or be resolved first
#
# - should we commit a systemimager patch which includes all the kernel
#   patches, or figure out some way to download & apply patches at build time,
#   resolving any conflicts that occur
#
# - to where should we commit the raidtools patch (to create static binaries)?
#   top level?  patches/ directory?

DESTDIR = 

TEMP_DIR = ./systemimager.initrd.temp.dir
TARBALL_BUILD_DIR = ./autoinstallbin

MANUAL_DIR = doc/manual_source
MANPAGE_DIR = doc/man

# destination directories
DOC  = $(DESTDIR)/usr/share/doc/systemimager-doc
ETC  = $(DESTDIR)/etc
INITD = $(ETC)/init.d
SBIN = $(DESTDIR)/usr/sbin
MAN8 = $(DESTDIR)/usr/share/man/man8

LOG_DIR = $(DESTDIR)/var/log/systemimager

INITSCRIPT_NAME = systemimager

TFTP_BIN_SRC      = tftpstuff/systemimager
TFTP_BIN         := raidstart mkraid mkreiserfs prepareclient updateclient
TFTP_ROOT	  = $(DESTDIR)/usr/lib/systemimager
TFTP_BIN_DEST     = $(TFTP_ROOT)/systemimager

PXE_CONF_SRC      = tftpstuff/pxelinux.cfg
PXE_CONF_DEST     = $(TFTP_ROOT)/pxelinux.cfg

AUTOINSTALL_TARBALL = ./autoinstallbin.tar.gz

BINARY_SRC = ./sbin
BINARIES := makeautoinstallcd addclients getimage makeautoinstalldiskette makedhcpstatic makedhcpserver pushupdate

CLIENT_BINARY_SRC = ./tftpstuff/systemimager
CLIENT_BINARIES  := updateclient prepareclient

COMMON_BINARY_SRC = $(BINARY_SRC)
COMMON_BINARIES   = lsimage

IMAGESRC    = ./var/lib/systemimager/images
IMAGEDEST   = $(DESTDIR)/var/lib/systemimager/images
WARNING_FILES = $(IMAGEDEST)/README $(IMAGEDEST)/DO_NOT_TOUCH_THESE_DIRECTORIES $(IMAGEDEST)/CUIDADO $(IMAGEDEST)/ACHTUNG

LINUX_SRC = ./linux
LINUX_TARBALL = linux-2.2.18.tar.gz
LINUX_URL = ftp://ftp.kernel.org/pub/linux/kernel/v2.2/$(LINUX_TARBALL)
LINUX_MD5SUM = 2be6aacc7001b061de2eec51a4c89b3b
LINUX_IMAGE = $(LINUX_SRC)/arch/i386/boot/bzImage

INITRD_DIR = initrd_source
INITRD = $(INITRD_DIR)/initrd.gz

RAIDTOOLS_DIR = raidtools-0.90
RAIDTOOLS_TARBALL = raidtools-19990824-0.90.tar.bz2
RAIDTOOLS_URL = http://www.kernel.org/pub/linux/daemons/raid/alpha/$(RAIDTOOLS_TARBALL)

REISERFSPROGS_DIR = $(LINUX_SRC)/fs/reiserfs/utils

all:	raidtools reiserfsprogs $(LINUX_IMAGE) $(INITRD) docs manpages

# a complete server install
installserverall:	installserver installcommon installbinaries

# a complete client install
installclientall:	installclient installcommon

# server-only architecture independent files
installserver:	installmanpages installrsyncconfigs
	mkdir -p $(SBIN)
	$(foreach binary, $(BINARIES), \
		install -m 555 $(BINARY_SRC)/$(binary) $(SBIN);)
	install -d -m 750 $(LOG_DIR)
	install -d -m 755 $(TFTP_ROOT)/systemimager
	install -d -m 755 $(PXE_CONF_DEST)
	install -m 444 --backup $(PXE_CONF_SRC)/message.txt \
		$(PXE_CONF_DEST)/message.txt
	install -m 444 --backup $(PXE_CONF_SRC)/syslinux.cfg \
		$(PXE_CONF_DEST)/syslinux.cfg
	install -m 444 --backup $(PXE_CONF_SRC)/syslinux.cfg \
		$(PXE_CONF_DEST)/default
	install -m 644 tftpstuff/systemimager/systemimager.exclude \
		$(TFTP_ROOT)/systemimager
	install -m 555 $(TFTP_BIN_SRC)/prepareclient $(TFTP_BIN_DEST)
	install -m 555 $(TFTP_BIN_SRC)/updateclient $(TFTP_BIN_DEST)
	install -d -m 750 $(IMAGEDEST)
	$(foreach file, $(WARNING_FILES), \
		install -m 644 $(IMAGESRC)/README $(file);)

# client-only files
installclient: installclientmanpages
	mkdir -p $(ETC)/systemimager
	install -m 644 tftpstuff/systemimager/systemimager.exclude $(ETC)/systemimager
	mkdir -p $(SBIN)

	$(foreach binary, $(CLIENT_BINARIES), \
		install -m 755 $(CLIENT_BINARY_SRC)/$(binary) $(SBIN);)

# files common to both the client and server
installcommon:	installcommonmanpages
	mkdir -p $(SBIN)
	$(foreach binary, $(COMMON_BINARIES), \
		install -m 755 $(COMMON_BINARY_SRC)/$(binary) $(SBIN);)

## architecture dependent files
installbinaries:	installraidtools installreiserfsprogs installkernel installinitrd


########## START raidtools ##########
installraidtools:	raidtools
	mkdir -p $(TFTP_BIN_DEST)
	install -m 555 $(RAIDTOOLS_DIR)/mkraid $(TFTP_BIN_DEST)
	install -m 555 $(RAIDTOOLS_DIR)/raidstart $(TFTP_BIN_DEST)
	cp -a $(TFTP_BIN_DEST)/raidstart $(TFTP_BIN_DEST)/raidstop

raidtools:	raidtools-stamp
raidtools-stamp:	$(RAIDTOOLS_TARBALL)
	bzcat $(RAIDTOOLS_TARBALL) | tar xv
	patch -p0 < raidtools.patch
	cd $(RAIDTOOLS_DIR) && ./configure
	make -C $(RAIDTOOLS_DIR)
	touch raidtools-stamp

$(RAIDTOOLS_TARBALL):
	wget $(RAIDTOOLS_URL)
########## END raidtools ##########

installreiserfsprogs:	reiserfsprogs
	mkdir -p $(TFTP_BIN_DEST)
	install -m 555 $(REISERFSPROGS_DIR)/bin/mkreiserfs $(TFTP_BIN_DEST)

reiserfsprogs:	patchedkernel
	make -C $(REISERFSPROGS_DIR)

########## BEGIN kernel ##########
installkernel:	kernel
	mkdir -p $(TFTP_ROOT)
	cp -a $(LINUX_IMAGE) $(TFTP_ROOT)/kernel

kernel:	$(LINUX_IMAGE)

$(LINUX_IMAGE):	patchedkernel-stamp
	cp ./doc/autoinstall.kernel.config $(LINUX_SRC)/.config
	$(MAKE) -C $(LINUX_SRC) oldconfig dep bzImage

patchedkernel:	patchedkernel-stamp

patchedkernel-stamp:	$(LINUX_TARBALL)
	# remove linux tree and restore to pristine state before patching
	-rm -rf $(LINUX_SRC)
	tar xvfz $(LINUX_TARBALL)

	# attempt to patch the kernel - this patch is not currently in CVS!
	patch -p0 < systemimager-1.5.0.patch
	touch patchedkernel-stamp

$(LINUX_TARBALL):
	wget $(LINUX_URL)
	[ "$(LINUX_MD5SUM)" == `md5sum $(LINUX_TARBALL) | cut -d " " -f 1` ] || exit 1
########## END kernel ##########

########## install initrd built from source ##########
installinitrd:	$(INITRD_DIR)/initrd.gz
	mkdir -p $(TFTP_ROOT)
	install -m 644 $(INITRD_DIR)/initrd.gz $(TFTP_ROOT)

########## this is the ramdisk built from source ##########
$(INITRD_DIR)/initrd.gz:
	make -C $(INITRD_DIR)

installrsyncconfigs:
	mkdir -p $(ETC)/systemimager
	install -m 644 etc/rsyncd.conf $(ETC)/systemimager
	mkdir -p $(INITD)
	install -m 755 etc/init.d/rsync $(INITD)/$(INITSCRIPT_NAME)

########## BEGIN man pages ##########
installmanpages:	manpages
	mkdir -p $(MAN8)
	$(foreach binary, $(BINARIES), \
		cp -a $(MANPAGE_DIR)/$(binary).8.gz $(MAN8); )

installclientmanpages:	manpages
	mkdir -p $(MAN8)
	$(foreach binary, $(CLIENT_BINARIES), \
		cp -a $(MANPAGE_DIR)/$(binary).8.gz $(MAN8); )

installcommonmanpages:	manpages
	mkdir -p $(MAN8)
	$(foreach binary, $(COMMON_BINARIES), \
		cp -a $(MANPAGE_DIR)/$(binary).8.gz $(MAN8); )

manpages:
	$(MAKE) -C $(MANPAGE_DIR)
########## END man pages ##########

installdocs: docs
	mkdir -p $(DOC)
	cp -a $(MANUAL_DIR)/html $(DOC)
	mkdir -p $(DOC)/examples
	install -m 644 etc/rsyncd.conf $(DOC)/examples
	install -m 644 etc/init.d/rsync $(DOC)/examples

docs:
	-cd doc/manual_source && ln -sf ../manual/html/images
	$(MAKE) -C $(MANUAL_DIR) html ps

# this target creates a tarball containing modules, binaries, and libraries
# for the autoinstall client to copy over.  before this can be used,
# the autoinstall ramdisk will need tar/gzip support
#
# this tarball will be downloaded by the autoinstall client, which will
# extract these files into it's ramdisk
# the libraries in the tarball are built against the initial ramdisk so
# that the ramdisk binaries will still function
$(AUTOINSTALL_TARBALL):	kernel
	$(MAKE) -C $(LINUX_SRC) modules_install INSTALL_MOD_PATH=./modules
	$(MAKE) -C $(INITRD_DIR) initrd
	mkdir -p $(TEMP_DIR)
	mkdir -p $(TARBALL_BUILD_DIR)/lib
	mkdir -p $(TARBALL_BUILD_DIR)/bin
	cp -a ./modules/lib/* $(TARBALL_BUILD_DIR)/lib

	### copy over binaries into $(TARBALL_BUILD_DIR)/bin ###
	mount $(INITRD_DIR)/initrd $(TEMP_DIR) -o loop
	$(INITRD_DIR)/mklibs.sh -v -d $(TARBALL_BUILD_DIR)/lib $(TEMP_DIR)/bin/* $(TARBALL_BUILD_DIR)/bin/*
	umount $(TEMP_DIR) && rmdir $(TEMP_DIR)
	tar -c $(TARBALL_BUILD_DIR)/* | gzip -9 > $(AUTOINSTALL_TARBALL)

get_source:	$(LINUX_TARBALL) $(RAIDTOOLS_TARBALL)

help:
	# This Makefiles provides targets to build and install the
	# SystemImager packages.  Here are descriptions of the various targets
	#
	# make all:			builds everything, but installs nothing
	#
	# make installclientserverall	installs all files necessary for an
	#				image server
	#
	# make installclientclientall	installs all files necessary for a
	#				golden client
	#
	# make installserver		install architecture independent
	#				server-only files - this is an
	#				incomplete server installation used
	#				for packaging
	#
	# make installclient		install architecture independent
	#				golden client-only files - this is an
	#				incomplete client installation used
	#				for packaging
	#
	# make installcommon		install files common to both the server
	#				and the golden client
	#
	# make installbinaries		install architecture-dependent files
	#				required by the image server (kernel,
	#				ramdisk, and utilities that autoinstall
	#				clients may need to retrieve during
	#				autoinstallation
	#
	# make installraidtools		install static raid utilities that
	#				autoinstall clients may need to
	#				retrieve during autoinstallation
	#
	# make raidtools		install static raid utilities that
	#				autoinstall clients may need to
	#				retrieve during autoinstallation
	#
	# make installreiserfsprogs	install static reiserfs utilities that
	#				autoinstall clients may need to
	#				retrieve during autoinstallation
	#
	# make reiserfsprogs		install static reiserfs utilities that
	#				autoinstall clients may need to
	#				retrieve during autoinstallation
	#
	# make installkernel		install kernel used to boot autoinstall
	#				clients
	#
	# make kernel			build kernel used to boot autoinstall
	#				clients
	#
	# make patchedkernel		apply the systemimager kernel patch
	#				to the kernel source tree
	#
	# make installinitrd		install ramdisk used to boot
	#				autoinstall clients
	#
	# make installrsyncconfigs	install initscript and config file
	#				for rsync, needed on image servers
	#
	# make installmanpages		install image server man pages
	#
	# make installclientmanpages	install golden client man pages
	#
	# make installcommonmanpages	install manpages common to both 
	#				image servers and golden clients
	#
	# make manpages			build manpages from sgml source
	#
	# make installdocs		install docs into $(DOC)
	#
	# make get_source		download all source that could be
	#				needed during the build
	#
	# make help			prints this message
	#
	# make clean			removes built binaries, cleans
	#				downloaded source trees and tarballs,
	#				editor backup files, etc.
	#
	# make distclean		make clean + rm downloaded source trees
	#				and tarballs

clean:
	-$(MAKE) -C $(RAIDTOOLS_DIR) clean
	-$(MAKE) -C $(REISERFSPROGS_DIR) clean
	-$(MAKE) -C $(LINUX_SRC) mrproper
	-$(MAKE) -C $(MANPAGE_DIR) clean
	-$(MAKE) -C $(MANUAL_DIR) clean
	-$(MAKE) -C $(INITRD_DIR) clean
	-find . -name "*~" -exec rm -f {} \;
	-find . -name "#*#" -exec rm -f {} \;
	-rm doc/manual_source/images
	-rm patchedkernel-stamp raidtools-stamp
	-umount $(TEMP_DIR)
	-rm -rf $(TEMP_DIR) ./modules $(TARBALL_BUILD_DIR)
	-rm $(AUTOINSTALL_TARBALL)

distclean:	clean
	-rm -rf $(LINUX_SRC) $(RAIDTOOLS_DIR)
	-rm -rf $(LINUX_TARBALL) $(RAIDTOOLS_TARBALL)
	-$(MAKE) -C $(INITRD_DIR) distclean


