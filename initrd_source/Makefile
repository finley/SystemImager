DESTDIR =

# where utilities that may need to be retrieved
# by autoinstall clients are stored
TFTPROOT = $(DESTDIR)/usr/lib/systemimager

TEMP_DIR = ./systemimager.initrd.temp.dir
INITRD_SIZE = 2600      # number of 1KB blocks in ramdisk.

########## BEGIN definitions for binaries built from source ##########
BEEP_VERSION = 1.2.1
BEEP_ROOT = ./beep-$(BEEP_VERSION)
BEEP_BINARY = $(BEEP_ROOT)/beep
BEEP_TARBALL = beep-$(BEEP_VERSION).tar.gz
BEEP_URL = http://www.johnath.com/beep/$(BEEP_TARBALL)

BUSYBOX_VERSION = 0.50
BUSYBOX_ROOT = ./busybox-$(BUSYBOX_VERSION)
BUSYBOX_BINARY = $(BUSYBOX_ROOT)/busybox
BUSYBOX_TARBALL = busybox-$(BUSYBOX_VERSION).tar.gz
BUSYBOX_URL = ftp://opensource.lineo.com/busybox/$(BUSYBOX_TARBALL)

MASSDNS_VERSION = 1.0
MASSDNS_ROOT = ./massdns-$(MASSDNS_VERSION)
MASSDNS_BINARY = $(MASSDNS_ROOT)/massdns
MASSDNS_TARBALL = massdns-$(MASSDNS_VERSION).tgz
MASSDNS_URL = http://www.mgix.com/massdns/$(MASSDNS_TARBALL)
########## END definitions for binaries built from source ##########

# tools provided by busybox (i.e. hard links to create)
BUSY_BIN := cat chgrp chmod chown cp df dmesg grep hostname kill ln ls mkdir mknod more mount mv ping ps pwd rm rmdir sleep sync touch umount uname ifconfig route
BUSY_SBIN := halt init insmod loadkmap makedevs mkswap reboot swapoff swapon update
BUSY_USR_BIN := clear cut expr find free killall reset telnet tr
BUSY_USR_SBIN := chroot

# these binaries will be copied over from the local system
LOCAL_BINARIES := /sbin/sfdisk /usr/bin/mawk /sbin/mke2fs /bin/ash /usr/bin/rsync /bin/sed /usr/bin/snarf /sbin/dhclient-2.2.x

initrd.gz:	initrd
	gzip -9 < initrd > initrd.gz

initrd:	binaries $(LOCAL_BINARIES)
	# create ramdisk file & mount it as a filesystem
	dd if=/dev/zero of=initrd bs=1k count=$(INITRD_SIZE)
	mke2fs -N 584 -m 0 -q -F initrd
	mkdir $(TEMP_DIR)
	mount initrd $(TEMP_DIR) -o loop

	# create directory structure
	cd $(TEMP_DIR) && mkdir -m 755 bin dev etc lib proc root sbin usr var
	cd $(TEMP_DIR) && mkdir -m 1777 tmp
	cd $(TEMP_DIR) && mkdir -m 755 usr/bin usr/sbin etc/init.d var/run

	# make /dev/entries
	./dupdevs.sh $(TEMP_DIR)/dev < dev_ls-lR

	# create hardlinks to busybox
	cp -a $(BUSYBOX_BINARY) $(TEMP_DIR)/bin
	cd $(TEMP_DIR) && $(foreach tool, $(BUSY_BIN), \
		ln ./bin/busybox ./bin/$(tool); )
	cd $(TEMP_DIR) && $(foreach tool, $(BUSY_SBIN), \
		ln ./bin/busybox ./sbin/$(tool); )
	cd $(TEMP_DIR) && $(foreach tool, $(BUSY_USR_BIN), \
		ln ./bin/busybox ./usr/bin/$(tool); )
	cd $(TEMP_DIR) && $(foreach tool, $(BUSY_USR_SBIN), \
		ln ./bin/busybox ./usr/sbin/$(tool); )

	# copy over other binaries
	cp -a $(BEEP_BINARY) $(MASSDNS_BINARY) $(LOCAL_BINARIES) \
		$(TEMP_DIR)/bin
	mv $(TEMP_DIR)/bin/dhclient-2.2.x $(TEMP_DIR)/bin/dhclient

	cd $(TEMP_DIR) && ln ./bin/ash ./bin/sh

	# copy over text files from the skel directory
	cp -a ./skel/* $(TEMP_DIR)

	# create small dynamic libraries
	./mklibs.sh -v -d $(TEMP_DIR)/lib $(TEMP_DIR)/bin/*

	umount $(TEMP_DIR) && rmdir $(TEMP_DIR)

install:	initrd.gz
	mkdir $(TFTPROOT)
	cp -a initrd.gz $(TFTPROOT)

# binaries that we build from source
binaries:	beep busybox massdns

########## BEGIN beep rules ##########
beep:	$(BEEP_BINARY)

$(BEEP_BINARY):	$(BEEP_TARBALL)
	tar xvfz $(BEEP_TARBALL)
	$(MAKE) -C $(BEEP_ROOT) beep
	strip $(BEEP_BINARY)

$(BEEP_TARBALL):
	wget $(BEEP_URL)
########## END beep rules ##########

########## BEGIN busybox rules ##########
busybox:	$(BUSYBOX_BINARY)

$(BUSYBOX_BINARY):	$(BUSYBOX_TARBALL)
	tar xvfz $(BUSYBOX_TARBALL)
	cp -a busybox.Config.h $(BUSYBOX_ROOT)/Config.h
	$(MAKE) -C $(BUSYBOX_ROOT) busybox
	strip $(BUSYBOX_BINARY)

$(BUSYBOX_TARBALL):
	wget $(BUSYBOX_URL)
########## END busybox rules ##########

########## BEGIN massdns rules ##########
massdns:	$(MASSDNS_BINARY)

$(MASSDNS_BINARY):	$(MASSDNS_TARBALL)
	tar xvfz $(MASSDNS_TARBALL)
	patch -p0 < massdns.patch
	$(MAKE) -C $(MASSDNS_ROOT)
	strip $(MASSDNS_BINARY)

$(MASSDNS_TARBALL):
	wget $(MASSDNS_URL)
########## END massdns rules ##########

clean:
	-$(MAKE) -C $(BUSYBOX_ROOT) clean
	-$(MAKE) -C $(BEEP_ROOT) clean
	-$(MAKE) -C $(MASSDNS_ROOT) clean
	-find . -name "*~" -exec rm -f {} \;
	-umount $(TEMP_DIR)
	-rm -rf $(TEMP_DIR) initrd initrd.gz

distclean:	clean
	-rm -rf $(BEEP_ROOT) $(BUSYBOX_ROOT) $(MASSDNS_ROOT)
	-rm -rf $(BEEP_TARBALL) $(BUSYBOX_TARBALL) $(MASSDNS_TARBALL)

get_source:	$(BEEP_TARBALL) $(BUSYBOX_TARBALL) $(MASSDNS_TARBALL)
