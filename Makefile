#
# "VA SystemImager" - Copyright (C) 1999-2001 Brian Elliott Finley <brian@valinux.com> 
#
# This file: Makefile
#
#   Written by Dann Frazier <daniel_frazier@hp.com>
#

DESTDIR = 

MANUAL_DIR = doc/manual_source
MANPAGE_DIR = doc/man

# destination directories
DOC  = $(DESTDIR)/usr/share/doc/va-systemimager
#CLIENT_DOC  = $(DESTDIR)/usr/share/doc/va-systemimager-client
ETC  = $(DESTDIR)/etc
INITD = $(ETC)/init.d
SBIN = $(DESTDIR)/usr/sbin
MAN8 = $(DESTDIR)/usr/share/man/man8

BINARY_SRC = ./sbin
BINARIES := makeautoinstallcd addclients getimage makeautoinstalldiskette makedhcpstatic makedhcpserver

TFTP_BIN_SRC      = tftpstuff/systemimager
TFTP_BIN         := raidstart mkraid mkreiserfs prepareclient updateclient
TFTP_ROOT	  = $(DESTDIR)/tftpboot
TFTP_BIN_DEST     = $(TFTP_ROOT)/systemimager

PXE_CONF_SRC      = tftpstuff/pxelinux.cfg
PXE_CONF_DEST     = $(TFTP_ROOT)/pxelinux.cfg

CLIENT_BINARY_SRC = ./tftpstuff/systemimager
CLIENT_BINARIES  := updateclient prepareclient

IMAGESRC    = var/spool/systemimager/images
IMAGEDEST   = $(DESTDIR)/var/spool/systemimager/images

install:	installserver installkernel installinitrd installrsyncconfigs installraidutils installreiserfsutils

installserver:	installdocs install_manpages
	mkdir -p $(SBIN)
	$(foreach binary, $(BINARIES), \
		install -m 555 $(BINARY_SRC)/$(binary) $(SBIN);)
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
	install -m 444 $(IMAGESRC)/README $(IMAGEDEST)/README
	install -m 444 $(IMAGESRC)/README \
		$(IMAGEDEST)/DO_NOT_TOUCH_THESE_DIRECTORIES
	install -m 444 $(IMAGESRC)/README $(IMAGEDEST)/CUIDADO
	install -m 444 $(IMAGESRC)/README $(IMAGEDEST)/ACHTUNG

installclient: installdocs install_client_manpages
	mkdir -p $(ETC)/systemimager
	install -m 644 tftpstuff/systemimager/systemimager.exclude $(ETC)/systemimager
	mkdir -p $(SBIN)
	$(foreach binary, $(CLIENT_BINARIES), \
		install -m 755 $(CLIENT_BINARY_SRC)/$(binary) $(SBIN);)

installraidutils:
	mkdir -p $(TFTP_BIN_DEST)
	install -m 555 $(TFTP_BIN_SRC)/mkraid $(TFTP_BIN_DEST)
	install -m 555 $(TFTP_BIN_SRC)/raidstart $(TFTP_BIN_DEST)
	cp -a $(TFTP_BIN_DEST)/raidstart $(TFTP_BIN_DEST)/raidstop

installreiserfsutils:
	mkdir -p $(TFTP_BIN_DEST)
	install -m 555 $(TFTP_BIN_SRC)/mkreiserfs $(TFTP_BIN_DEST)

installkernel:
	mkdir -p $(TFTP_ROOT)
	install -m 644 tftpstuff/kernel $(TFTP_ROOT)

installinitrd:
	mkdir -p $(TFTP_ROOT)
	install -m 644 tftpstuff/initrd.gz $(TFTP_ROOT)

installrsyncconfigs:
	mkdir -p $(ETC)
	install -m 644 etc/rsyncd.conf $(ETC)
	mkdir -p $(INITD)
	install -m 755 etc/init.d/rsync $(INITD)

install_manpages:	manpages
	mkdir -p $(MAN8)
	$(foreach binary, $(BINARIES), \
		cp -a $(MANPAGE_DIR)/$(binary).8.gz $(MAN8); )

install_client_manpages:	manpages
	mkdir -p $(MAN8)
	$(foreach binary, $(CLIENT_BINARIES), \
		cp -a $(MANPAGE_DIR)/$(binary).8.gz $(MAN8); )

installdocs: docs
	mkdir -p $(DOC)
	cp -a $(MANUAL_DIR)/html $(DOC)
	mkdir -p $(DOC)/examples
	install -m 644 etc/rsyncd.conf $(DOC)/examples
	install -m 644 etc/init.d/rsync $(DOC)/examples

docs:
	$(MAKE) -C $(MANUAL_DIR) html ps

manpages:
	$(MAKE) -C $(MANPAGE_DIR)

clean:
	$(MAKE) -C $(MANPAGE_DIR) clean
	$(MAKE) -C $(MANUAL_DIR) clean
	find . -name "*~" -exec rm -f {} \;
	find . -name "#*#" -exec rm -f {} \;

deb:
	dpkg-buildpackage -rfakeroot

