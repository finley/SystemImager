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
TFTP_BIN_DEST     = $(DESTDIR)/tftpboot/systemimager

PXE_CONF_SRC      = tftpstuff/pxelinux.cfg
PXE_CONF_DEST     = $(DESTDIR)/tftpboot/pxelinux.cfg

CLIENT_BINARY_SRC = ./tftpstuff/systemimager
CLIENT_BINARIES  := updateclient prepareclient

IMAGESRC    = var/spool/systemimager/images
IMAGEDEST   = $(DESTDIR)/var/spool/systemimager/images

install:	installdocs
	mkdir -p $(SBIN)
	$(foreach binary, $(BINARIES), \
		install -m 555 $(BINARY_SRC)/$(binary) $(SBIN);)
	install -d -m 755 $(DESTDIR)/tftpboot/systemimager
	install -m 644 tftpstuff/initrd.gz $(DESTDIR)/tftpboot
	install -m 644 tftpstuff/kernel $(DESTDIR)/tftpboot
	install -d -m 755 $(PXE_CONF_DEST)
	install -m 444 --backup $(PXE_CONF_SRC)/message.txt \
		$(PXE_CONF_DEST)/message.txt
	install -m 444 --backup $(PXE_CONF_SRC)/syslinux.cfg \
		$(PXE_CONF_DEST)/syslinux.cfg
	install -m 444 --backup $(PXE_CONF_SRC)/syslinux.cfg \
		$(PXE_CONF_DEST)/default
	install -m 644 tftpstuff/systemimager/systemimager.exclude \
		$(DESTDIR)/tftpboot/systemimager
	$(foreach binary, $(TFTP_BIN), \
		install -m 555 $(TFTP_BIN_SRC)/$(binary) $(TFTP_BIN_DEST);)
	cp -a $(TFTP_BIN_DEST)/raidstart $(TFTP_BIN_DEST)/raidstop
	install -d -m 750 $(IMAGEDEST)
	install -m 444 $(IMAGESRC)/README $(IMAGEDEST)/README
	install -m 444 $(IMAGESRC)/README \
		$(IMAGEDEST)/DO_NOT_TOUCH_THESE_DIRECTORIES
	install -m 444 $(IMAGESRC)/README $(IMAGEDEST)/CUIDADO
	install -m 444 $(IMAGESRC)/README $(IMAGEDEST)/ACHTUNG
	mkdir -p $(ETC)
	install -m 644 etc/rsyncd.conf $(ETC)
	mkdir -p $(INITD)
	install -m 755 etc/init.d/rsync $(INITD)

installclient: installdocs
	mkdir -p $(ETC)/systemimager
	install -m 644 tftpstuff/systemimager/systemimager.exclude $(ETC)/systemimager
	mkdir -p $(SBIN)
	$(foreach binary, $(CLIENT_BINARIES), \
		install -m 755 $(CLIENT_BINARY_SRC)/$(binary) $(SBIN);)

installdocs: docs
	mkdir -p $(DOC)
	cp -a $(MANUAL_DIR)/html $(DOC)
	mkdir -p $(MAN8)
	find $(MANPAGE_DIR) -name "*.8.gz" -exec cp -a {} $(MAN8) \;

docs:
	$(MAKE) -C $(MANPAGE_DIR)
	$(MAKE) -C $(MANUAL_DIR) html ps

clean:
	$(MAKE) -C $(MANPAGE_DIR) clean
	$(MAKE) -C $(MANUAL_DIR) clean
	find . -name "*~" -exec rm -f {} \;
	find . -name "#*#" -exec rm -f {} \;

deb:
	dpkg-buildpackage -rfakeroot

