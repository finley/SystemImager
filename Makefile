#
# "VA SystemImager" - Copyright (C) 1999-2001 Brian Elliott Finley <brian@valinux.com> 
#
# This file: Makefile
#
#   Written by Dann Frazier <dannf@ldl.fc.hp.com>
#

DESTDIR = 

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

BINARY_SRC = ./sbin
BINARIES := makeautoinstallcd addclients getimage makeautoinstalldiskette makedhcpstatic makedhcpserver pushupdate

CLIENT_BINARY_SRC = ./tftpstuff/systemimager
CLIENT_BINARIES  := updateclient prepareclient

COMMON_BINARY_SRC = $(BINARY_SRC)
COMMON_BINARIES   = lsimage

IMAGESRC    = ./var/lib/systemimager/images
IMAGEDEST   = $(DESTDIR)/var/lib/systemimager/images
WARNING_FILES = $(IMAGEDEST)/README $(IMAGEDEST)/DO_NOT_TOUCH_THESE_DIRECTORIES $(IMAGEDEST)/CUIDADO $(IMAGEDEST)/ACHTUNG

LINUX_SRC = other_source_and_patches_used_in_this_release/linux-2.2.18+reiserfs+raid+aic7xxx+VM

INITRD_DIR = initrd

RAIDTOOLS_DIR = other_source_and_patches_used_in_this_release/raidtools-0.90
REISERFSPROGS_DIR = $(LINUX_SRC)/fs/reiserfs/utils

all:	raidtools reiserfsprogs kernel initrd-build docs manpages

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

installraidtools:	raidtools
	mkdir -p $(TFTP_BIN_DEST)
	install -m 555 $(RAIDTOOLS_DIR)/mkraid $(TFTP_BIN_DEST)
	install -m 555 $(RAIDTOOLS_DIR)/raidstart $(TFTP_BIN_DEST)
	cp -a $(TFTP_BIN_DEST)/raidstart $(TFTP_BIN_DEST)/raidstop

raidtools:
	cd $(RAIDTOOLS_DIR) && ./configure
	make -C $(RAIDTOOLS_DIR)

installreiserfsprogs:	reiserfsprogs
	mkdir -p $(TFTP_BIN_DEST)
	install -m 555 $(REISERFSPROGS_DIR)/bin/mkreiserfs $(TFTP_BIN_DEST)

reiserfsprogs:
	make -C $(REISERFSPROGS_DIR)

installkernel:	kernel
	mkdir -p $(TFTP_ROOT)
	cp -a $(LINUX_SRC)/arch/i386/boot/bzImage $(TFTP_ROOT)/kernel

kernel:
	cp ./doc/autoinstall.kernel.config $(LINUX_SRC)/.config
	$(MAKE) -C $(LINUX_SRC) oldconfig dep bzImage

# install initrd built from source
installinitrd:	initrd-build
	mkdir -p $(TFTP_ROOT)
	install -m 644 $(INITRD_DIR)/initrd.gz $(TFTP_ROOT)

# this is the ramdisk built from source
initrd-build:
	make -C $(INITRD_DIR)

installrsyncconfigs:
	mkdir -p $(ETC)/systemimager
	install -m 644 etc/rsyncd.conf $(ETC)/systemimager
	mkdir -p $(INITD)
	install -m 755 etc/init.d/rsync $(INITD)/$(INITSCRIPT_NAME)

## man pages
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

installdocs: docs
	mkdir -p $(DOC)
	cp -a $(MANUAL_DIR)/html $(DOC)
	mkdir -p $(DOC)/examples
	install -m 644 etc/rsyncd.conf $(DOC)/examples
	install -m 644 etc/init.d/rsync $(DOC)/examples

docs:
	-cd doc/manual_source && ln -sf ../manual/html/images
	$(MAKE) -C $(MANUAL_DIR) html ps

clean:
	-$(MAKE) -C $(RAIDTOOLS_DIR) clean
	-$(MAKE) -C $(REISERFSPROGS_DIR) clean
	-$(MAKE) -C $(LINUX_SRC) mrproper
	-$(MAKE) -C $(MANPAGE_DIR) clean
	-$(MAKE) -C $(MANUAL_DIR) clean
	-$(MAKE) -C $(INITRD_DIR) distclean
	-find . -name "*~" -exec rm -f {} \;
	-find . -name "#*#" -exec rm -f {} \;
	-rm doc/manual_source/images
deb:
	dpkg-buildpackage
