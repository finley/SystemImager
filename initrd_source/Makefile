DESTDIR =

PATH = /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

SUDO = $(shell if [ `id -u` != 0 ]; then echo -n "sudo"; fi)
ARCH = $(shell uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/)

WGET = wget --passive-ftp

# where utilities that may need to be retrieved
# by autoinstall clients are stored
USR = $(DESTDIR)/usr/local
INSTALL_DIR = $(USR)/share/systemimager/$(ARCH)-boot

PATCH_DIR = ./patches
SRC_DIR = ./src

EXTRA_BLOCKS = 100       # number of 1KB blocks in ramdisk.
EXTRA_INODES = 50 # number of inodes available on ramdisk

########## BEGIN definitions for binaries built from source ##########

BEEP_VERSION = 1.2.1
BEEP_ROOT = $(SRC_DIR)/beep-$(BEEP_VERSION)
BEEP_BINARY = $(BEEP_ROOT)/beep
BEEP_TARBALL = beep-$(BEEP_VERSION).tar.gz
BEEP_URL = http://www.johnath.com/beep/$(BEEP_TARBALL)
BEEP_PATCH = $(PATCH_DIR)/beep.patch

BUSYBOX_VERSION = 0.60.0
BUSYBOX_ROOT = $(SRC_DIR)/busybox-$(BUSYBOX_VERSION)
BUSYBOX_BINARY = $(BUSYBOX_ROOT)/busybox
BUSYBOX_TARBALL = busybox-$(BUSYBOX_VERSION).tar.gz
BUSYBOX_URL = ftp://opensource.lineo.com/busybox/$(BUSYBOX_TARBALL)

########## END definitions for binaries built from source ##########

# tools provided by busybox (i.e. hard links to create)
BUSY_BIN := cat chgrp chmod chown cp df dmesg grep hostname kill ln ls mkdir mknod more mount mv ping ps pwd rm rmdir sed sleep sync touch umount uname ifconfig route
BUSY_SBIN := halt init insmod loadkmap makedevs mkswap reboot swapoff swapon update
BUSY_USR_BIN := clear cut expr find free killall reset telnet tr
BUSY_USR_SBIN := chroot

# these binaries will be copied over from the local system
LOCAL_BINARIES := /sbin/sfdisk /usr/bin/mawk /sbin/mke2fs /bin/ash /usr/bin/rsync /usr/bin/snarf /sbin/dhclient-2.2.x /usr/bin/host

initrd.gz:	initrd
	gzip -9 < initrd > initrd.gz

initrd:	binary-build-stamp $(LOCAL_BINARIES)
	# create a temporary skeleton directory
	cp -a skel skel.tmp

	# clear out CVS cruft
	find skel.tmp -type d -name CVS -depth | xargs rm -rf

	# copy over files from local system
	cp -a $(BEEP_BINARY) $(LOCAL_BINARIES) skel.tmp/bin
	cd skel.tmp && ln ./bin/ash ./bin/sh
	mv skel.tmp/bin/dhclient-2.2.x skel.tmp/bin/dhclient

	# copy over needed libs that aren't automatically
	# pulled in by mklibs.sh
	mkdir skel.tmp/lib
	cp -a /lib/libnss_dns* skel.tmp/lib

	$(SUDO) chown 0 -R skel.tmp/*
	$(SUDO) chgrp 0 -R skel.tmp/*

	$(SUDO) ./mkboel.sh -busybox $(BUSYBOX_BINARY) -d dev_ls-lR \
	  -s skel.tmp -eb $(EXTRA_BLOCKS) -ei $(EXTRA_INODES) -fs ext2 \
	  -o initrd

	$(SUDO) rm -rf skel.tmp

install:	initrd.gz
	mkdir $(INSTALL_DIR)
	cp -a initrd.gz $(INSTALL_DIR)

# binaries that we build from source
binaries:	binary-build-stamp

binary-build-stamp:
	$(MAKE) beep busybox
	touch binary-build-stamp

########## BEGIN beep rules ##########

beep:
	$(MAKE) $(SRC_DIR)/$(BEEP_TARBALL)
	[ -d $(BEEP_ROOT) ] || \
		( cd $(SRC_DIR) && tar xvfz $(BEEP_TARBALL) && \
		  [ ! -f ../$(BEEP_PATCH) ] || \
		  patch -p0 < ../$(BEEP_PATCH) )
	$(MAKE) -C $(BEEP_ROOT) beep
	strip $(BEEP_BINARY)

$(SRC_DIR)/$(BEEP_TARBALL):
	[ -d $(SRC_DIR) ] || mkdir -p $(SRC_DIR)
	cd $(SRC_DIR) && $(WGET) $(BEEP_URL)

########## END beep rules ##########

########## BEGIN busybox rules ##########

busybox:
	$(MAKE) $(SRC_DIR)/$(BUSYBOX_TARBALL)
	[ -d $(BUSYBOX_ROOT) ] || \
		( cd $(SRC_DIR) && tar xvfz $(BUSYBOX_TARBALL) )
	cp -a busybox.Config.h $(BUSYBOX_ROOT)/Config.h
	$(MAKE) -C $(BUSYBOX_ROOT) busybox
	strip $(BUSYBOX_BINARY)

$(SRC_DIR)/$(BUSYBOX_TARBALL):
	[ -d $(SRC_DIR) ] || mkdir -p $(SRC_DIR)
	cd $(SRC_DIR) && $(WGET) $(BUSYBOX_URL)

########## END busybox rules ##########

get_source:	$(SRC_DIR)/$(BEEP_TARBALL) $(SRC_DIR)/$(BUSYBOX_TARBALL)

help:
	@echo ' This Makefile provides rules to create a ramdisk (initrd.gz) for'
	@echo ' SystemImager autoinstall clients.  '
	@echo ''
	@echo ' Steps for the Chronically Impatient'
	@echo ' -----------------------------------'
	@echo ' 1) Do a "make get_source".'
	@echo ' 2) Modify the source code as desired.'
	@echo ' 3) Modify the init script as desired "vi skel/etc/init.d/rcS".'
	@echo ' 4) Modify any other configuration files as desired.  Most of these'
	@echo '    are in the "skel" directory. (skel is short for skeleton files)'
	@echo ' 5) Modify "dev_ls-lR" to add or remove device entries.'
	@echo ' 5) Run "make install"'
	@echo ''
	@echo ''
	@echo ' Details so that the Impatient can know what broke'
	@echo ' -------------------------------------------------'
	@echo ' Here are descriptions of the various rules:'
	@echo ''
	@echo ' make initrd.gz          makes a complete compressed ramdisk'
	@echo ''
	@echo ' make initrd             makes a complete uncompressed ramdisk'
	@echo ''
	@echo ' make install            installs a complete compressed ramdisk'
	@echo '                         to $(INSTALL_DIR)'
	@echo ''
	@echo ' make binaries           downloads the source for and builds'
	@echo '                         all required binaries that are not'
	@echo '                         a part of the Debian/unstable distro'
	@echo '                         (binaries that are in Debian/unstable'
	@echo '                         are just copied over from the local'
	@echo '                         system)'
	@echo ''
	@echo ' make <binary>           downloads the source for and builds'
	@echo '                         a single required binary that is not'
	@echo '                         a part of the Debian/unstable distro'
	@echo '                         (binaries that are in Debian/unstable'
	@echo '                         are just copied over from the local'
	@echo '                         system)'
	@echo ''
	@echo ' make get_source         download the source for all binaries'
	@echo '                         that are required, but not a part'
	@echo '                         of Debian/unstable.'
	@echo ''
	@echo ' make help               print this message'
	@echo ''
	@echo ' make helpless           pipe this message through less'
	@echo ''
	@echo ' make clean              execute the clean rule in the source'
	@echo '                         tree for each utility, remove editor'
	@echo '                         backup files and files that have'
	@echo '                         already been built.'
	@echo ''
	@echo ' make distclean          make clean + remove all downloaded'
	@echo '                         tarballs & their build trees.'
	@echo ''
	@echo ' Please read the README.initrd for more build and customization'
	@echo ' details.'

helpless:
	$(MAKE) help | less

clean:
	-$(MAKE) -C $(BUSYBOX_ROOT) clean
	-$(MAKE) -C $(BEEP_ROOT) clean
	-find . -name "*~" -exec rm -f {} \;
	-$(SUDO) rm -rf initrd initrd.gz skel.tmp
	-rm -rf binary-build-stamp
distclean:	clean
	-rm -rf $(SRC_DIR)
