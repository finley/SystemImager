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

LINUX_SRC = ../src/linux

EXTRA_BLOCKS_STAGE1 = 100       # number of 1KB blocks in ramdisk.
EXTRA_INODES_STAGE1 = 50        # number of inodes available on ramdisk

EXTRA_BLOCKS_STAGE2 = 100       # number of 1KB blocks in ramdisk.
EXTRA_INODES_STAGE2 = 50        # number of inodes available on ramdisk

########## BEGIN definitions for binaries built from source ##########

BEEP_VERSION = 1.2.1
BEEP_ROOT = $(SRC_DIR)/beep-$(BEEP_VERSION)
BEEP_BINARY = $(BEEP_ROOT)/beep
BEEP_TARBALL = beep-$(BEEP_VERSION).tar.gz
BEEP_URL = http://www.johnath.com/beep/$(BEEP_TARBALL)
BEEP_PATCH = $(PATCH_DIR)/beep.patch

BUSYBOX_VERSION = 0.60.0
BUSYBOX_TARBALL = busybox-$(BUSYBOX_VERSION).tar.gz
BUSYBOX_URL = ftp://opensource.lineo.com/busybox/$(BUSYBOX_TARBALL)
BUSYBOX_ROOT = $(SRC_DIR)/busybox-$(BUSYBOX_VERSION)
BUSYBOX_ROOT_STAGE1 = $(SRC_DIR)/busybox-$(BUSYBOX_VERSION)-stage1
BUSYBOX_ROOT_STAGE2 = $(SRC_DIR)/busybox-$(BUSYBOX_VERSION)-stage2
BUSYBOX_BINARY_STAGE1 = $(BUSYBOX_ROOT_STAGE1)/busybox
BUSYBOX_BINARY_STAGE2 = $(BUSYBOX_ROOT_STAGE2)/busybox

########## END definitions for binaries built from source ##########

###### BEGIN binaries that will be copied over from the local system #####

LOCAL_BINARIES_STAGE1 := /sbin/dhclient-2.2.x /sbin/mke2fs /bin/ash /usr/bin/mawk /usr/bin/rsync /usr/bin/snarf 

LOCAL_BINARIES_STAGE2 := $(LOCAL_BINARIES_STAGE1) /sbin/devfsd /sbin/discover /sbin/mkfs.jfs /sbin/mkfs.xfs /sbin/insmod /sbin/mkreiserfs /sbin/mkraid /sbin/modprobe /sbin/raidstart /sbin/raidstop /sbin/rmmod /sbin/sfdisk /usr/bin/host

ifeq ($(ARCH),s390)
	LOCAL_BINARIES_STAGE2 := $(LOCAL_BINARIES_STAGE1) /sbin/devfsd /sbin/discover /sbin/mkfs.jfs /sbin/insmod /sbin/mkreiserfs /sbin/modprobe /sbin/rmmod /usr/bin/host /sbin/fdasd /sbin/dasdfmt
endif

LOCAL_BINARIES_STAGE2_SSH := $(LOCAL_BINARIES_STAGE2) /usr/bin/ssh /usr/sbin/sshd /usr/bin/scp /usr/bin/ssh-keygen

###### END binaries that will be copied over from the local system #####

all:	initrd.gz stage2rd.gz

initrd.gz:	initrd
	gzip -9 < initrd > initrd.gz

initrd:	binary-build-stamp $(LOCAL_BINARIES_STAGE1)
	# create a temporary skeleton directory
	cp -a skel skel.tmp

	# clear out CVS cruft
	find skel.tmp -type d -name CVS -depth | xargs rm -rf

	# copy over files from local system
	cp -a $(LOCAL_BINARIES_STAGE1) skel.tmp/bin
	cd skel.tmp && ln ./bin/ash ./bin/sh
	mv skel.tmp/bin/dhclient-2.2.x skel.tmp/bin/dhclient

	$(SUDO) chown 0 -R skel.tmp/*
	$(SUDO) chgrp 0 -R skel.tmp/*

	$(SUDO) ./mkboel.sh -busybox $(BUSYBOX_BINARY_STAGE1) -d dev_ls-lR \
	  -s skel.tmp -eb $(EXTRA_BLOCKS_STAGE1) -ei \
	  $(EXTRA_INODES_STAGE1) -fs ext2 -o initrd

	$(SUDO) rm -rf skel.tmp

stage2rd.gz:	stage2rd
	gzip -9 < stage2rd > stage2rd.gz

stage2rd:	binary-build-stamp $(LOCAL_BINARIES_STAGE2)
	# create a temporary skeleton directory
	cp -a skel skel2.tmp

	# clear out CVS cruft
	find skel2.tmp -type d -name CVS -depth | xargs rm -rf

	# copy over files from local system
	cp -a $(BEEP_BINARY) $(LOCAL_BINARIES_STAGE2) skel2.tmp/bin
	cd skel2.tmp && ln ./bin/ash ./bin/sh
	mv skel2.tmp/bin/dhclient-2.2.x skel2.tmp/bin/dhclient

	# copy over needed libs that aren't automatically
	# pulled in by mklibs.sh
	mkdir skel2.tmp/lib
	cp -a /lib/libnss_dns* skel2.tmp/lib

	# copy over the discover data
	mkdir -p skel2.tmp/usr/share/discover
	cp -a /usr/share/discover/* skel2.tmp/usr/share/discover

	# copy over kernel modules
	$(MAKE) -C .. patched_kernel
	$(MAKE) -C $(LINUX_SRC) modules modules_install \
	  INSTALL_MOD_PATH=$(PWD)/initrd_source/skel2.tmp

	$(SUDO) chown 0 -R skel2.tmp/*
	$(SUDO) chgrp 0 -R skel2.tmp/*

	$(SUDO) ./mkboel.sh -busybox $(BUSYBOX_BINARY_STAGE2) -d dev_ls-lR \
	  -s skel2.tmp -eb $(EXTRA_BLOCKS_STAGE2) \
	  -ei $(EXTRA_INODES_STAGE2) -fs ext2 -o stage2rd

	$(SUDO) rm -rf skel2.tmp

stage2rd-ssh.gz:	stage2rd-ssh
	gzip -9 < stage2rd-ssh > stage2rd-ssh.gz

stage2rd-ssh:	binary-build-stamp $(LOCAL_BINARIES_STAGE2_SSH)
	# create a temporary skeleton directory
	cp -a skel skel2-ssh.tmp

	# clear out CVS cruft
	find skel2-ssh.tmp -type d -name CVS -depth | xargs rm -rf

	# copy over files from local system
	cp -a $(BEEP_BINARY) $(LOCAL_BINARIES_STAGE2_SSH) skel2-ssh.tmp/bin
	cd skel2-ssh.tmp && ln ./bin/ash ./bin/sh
	mv skel2-ssh.tmp/bin/dhclient-2.2.x skel2-ssh.tmp/bin/dhclient

	# copy over needed libs that aren't automatically
	# pulled in by mklibs.sh
	mkdir skel2-ssh.tmp/lib
	cp -a /lib/libnss_dns* skel2-ssh.tmp/lib

	# copy over the discover data
	mkdir -p skel2-ssh.tmp/usr/share/discover
	cp -a /usr/share/discover/* skel2-ssh.tmp/usr/share/discover

	# copy over kernel modules
	$(MAKE) -C .. patched_kernel
	$(MAKE) -C $(LINUX_SRC) modules modules_install \
	  INSTALL_MOD_PATH=$(PWD)/initrd_source/skel2-ssh.tmp

	$(SUDO) chown 0 -R skel2-ssh.tmp/*
	$(SUDO) chgrp 0 -R skel2-ssh.tmp/*

	$(SUDO) ./mkboel.sh -busybox $(BUSYBOX_BINARY_STAGE2) -d dev_ls-lR \
	  -s skel2-ssh.tmp -eb $(EXTRA_BLOCKS_STAGE2) \
	  -ei $(EXTRA_INODES_STAGE2) -fs ext2 -o stage2rd-ssh

	$(SUDO) rm -rf skel2-ssh.tmp

install:	initrd.gz stage2rd.gz stage2rd-ssh.gz
	mkdir -p $(INSTALL_DIR)
	install -m 644 initrd.gz $(INSTALL_DIR)
	install -m 644 stage2rd.gz $(INSTALL_DIR)
	install -m 644 stage2rd-ssh.gz $(INSTALL_DIR)

# binaries that we build from source
binaries:	binary-build-stamp

binary-build-stamp:
	$(MAKE) beep $(BUSYBOX_BINARY_STAGE1) $(BUSYBOX_BINARY_STAGE2)
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
	cd $(SRC_DIR) && ([ -f /usr/src/$(BEEP_TARBALL) ] && \
	  ln -s /usr/src/$(BEEP_TARBALL) .) || $(WGET) $(BEEP_URL)

########## END beep rules ##########

########## BEGIN busybox rules ##########

$(BUSYBOX_BINARY_STAGE1):
	$(MAKE) $(SRC_DIR)/$(BUSYBOX_TARBALL)
	[ -d $(BUSYBOX_ROOT_STAGE1) ] || \
		( cd $(SRC_DIR) && tar xvfz $(BUSYBOX_TARBALL) && \
		  mv $(shell basename $(BUSYBOX_ROOT)) \
		  $(shell basename $(BUSYBOX_ROOT_STAGE1)) )
	cp -a busybox-1.Config.h $(BUSYBOX_ROOT_STAGE1)/Config.h
	$(MAKE) -C $(BUSYBOX_ROOT_STAGE1) busybox
	strip $(BUSYBOX_BINARY_STAGE1)

$(BUSYBOX_BINARY_STAGE2):
	$(MAKE) $(SRC_DIR)/$(BUSYBOX_TARBALL)
	[ -d $(BUSYBOX_ROOT_STAGE2) ] || \
		( cd $(SRC_DIR) && tar xvfz $(BUSYBOX_TARBALL) && \
		  mv $(shell basename $(BUSYBOX_ROOT)) \
		  $(shell basename $(BUSYBOX_ROOT_STAGE2)) )
	cp -a busybox-2.Config.h $(BUSYBOX_ROOT_STAGE2)/Config.h
	$(MAKE) -C $(BUSYBOX_ROOT_STAGE2) busybox
	strip $(BUSYBOX_BINARY_STAGE2)

$(SRC_DIR)/$(BUSYBOX_TARBALL):
	[ -d $(SRC_DIR) ] || mkdir -p $(SRC_DIR)
	cd $(SRC_DIR) && ([ -f /usr/src/$(BUSYBOX_TARBALL) ] && \
	  ln -s /usr/src/$(BUSYBOX_TARBALL) .) || $(WGET) $(BUSYBOX_URL)

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
	rm -rf stage2rd.gz stage2rd-ssh.gz stage2rd stage2rd-ssh
	rm -rf initrd initrd.gz busybox-1 busybox-2
	$(SUDO) rm -rf skel.tmp skel2.tmp skel2-ssh.tmp
	rm -rf binary-build-stamp

distclean:	clean
	-rm -rf $(SRC_DIR)
