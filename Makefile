#
# "SystemImager" - Copyright (C) 1999-2001 Brian Elliott Finley <brian@systemimager.org> 
#
#   $Id$
#
#   Written by Dann Frazier <dannf@ldl.fc.hp.com>
#
#   Others who have contributed to this code:
#     Brian Finley <brian@systemimager.org>
#
#
#
# Editing this file:
#   When adding a rule to this makefile, you should also add a properly
#   formatted comment just above.  This is so that the 'help' rules can parse
#   this file and print out a short description of the various rules.
#   Comments that begin with '#@' describe rules for use by end-users
#   (install_server, get_source, clean, etc.)  Comments that begin
#   with '#@@' describe rules that aren't intended for use by end-users, but
#   might be useful for others. Rules that aren't intended to be executed
#   directly shouldn't be commented with the '#@' notation - the assumption is
#   that if you're messing with these rules, you've opened up this file anyway,
#   so normal comments are fine.
#
# SystemImager file location standards:
#   o images will be stored in: /var/lib/systemimager/images/
#   o autoinstall scripts:      /var/lib/systemimager/scripts/
#
#   o web gui pages:            /usr/share/systemimager/web-gui/
#
#   o autoinstall kernels:      /usr/share/systemimager/`arch`-boot/
#   o initial ram disks:        /usr/share/systemimager/`arch`-boot/
#   o autoinstall binaries:     /usr/share/systemimager/`arch`-boot/
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
#   
#   o tftp files will be copied to the appropriate destination (as determined
#     by the local SysAdmin when running "mkbootserver".
#
#   o user visible binaries:    /usr/local/bin (default)
#     (lsimage, mkautoinstalldiskette, mkautoinstallcd)
#   o sysadmin binaries:        /usr/local/sbin (default)
#     (all other binaries)
#
# Standards for pre-defined rsync modules:
#   o scripts
#   o <arch>-boot (Ie., i386-boot -- dynamically determine in rcS)
#     (do an 
#       ARCH=`uname -m | sed 's/i[3-6]86/i386/'`
#     in the rcS script)
#
# Where should the server side exclude file be stored?
# currently it is the only file in /usr/lib/systemimager/systemimager
# maybe /etc/systemimager/systemimager.exclude?
#

DESTDIR = 
PATH = /sbin:/bin:/usr/sbin:/usr/bin:/usr/bin/X11:/usr/local/sbin:/usr/local/bin
ARCH = $(shell uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/)

TEMP_DIR = systemimager.initrd.temp.dir/
TARBALL_BUILD_DIR = autoinstallbin/

MANUAL_DIR = doc/manual_source/
MANPAGE_DIR = doc/man/
PATCH_DIR = patches/
LIB_SRC = lib/SystemImager/
SRC_DIR = src/
BINARY_SRC = sbin/
CLIENT_BINARY_SRC = tftpstuff/systemimager
COMMON_BINARY_SRC = $(BINARY_SRC)

# destination directories
ETC  = $(DESTDIR)/etc
INITD = $(ETC)/init.d
USR = $(DESTDIR)/usr/local
DOC  = $(USR)/share/doc/systemimager-doc
BIN = $(USR)/bin
SBIN = $(USR)/sbin
MAN8 = $(USR)/share/man/man8
LIB_DEST = $(USR)/lib/systemimager/perl/SystemImager
LOG_DIR = $(DESTDIR)/var/log/systemimager

INITSCRIPT_NAME = systemimager

TFTP_BIN_SRC      = tftpstuff/systemimager
TFTP_BIN         := raidstart mkraid mkreiserfs prepareclient updateclient
TFTP_ROOT	  = $(USR)/share/systemimager
TFTP_BIN_DEST     = $(TFTP_ROOT)/$(ARCH)-boot

PXE_CONF_SRC      = tftpstuff/pxelinux.cfg
PXE_CONF_DEST     = $(TFTP_BIN_DEST)/pxelinux.cfg

AUTOINSTALL_TARBALL = autoinstallbin.tar.gz

BINARIES := makeautoinstallcd makeautoinstalldiskette
SBINARIES := addclients cpimage getimage makedhcpserver makedhcpstatic mkautoinstallscript mkbootserver mvimage pushupdate rmimage
CLIENT_SBINARIES  := updateclient prepareclient
COMMON_BINARIES   = lsimage

IMAGESRC    = ./var/spool/systemimager/images
IMAGEDEST   = $(DESTDIR)/var/lib/systemimager/images
WARNING_FILES = $(IMAGEDEST)/README $(IMAGEDEST)/DO_NOT_TOUCH_THESE_DIRECTORIES $(IMAGEDEST)/CUIDADO $(IMAGEDEST)/ACHTUNG
AUTOINSTALL_SCRIPT_DIR = $(DESTDIR)/var/lib/systemimager/scripts

LINUX_SRC = $(SRC_DIR)/linux
LINUX_VERSION = 2.2.18
LINUX_TARBALL = linux-$(LINUX_VERSION).tar.bz2
LINUX_URL = http://www.kernel.org/pub/linux/kernel/v2.2/$(LINUX_TARBALL)
LINUX_MD5SUM = 9a8f4b1003ff6b096678d193fd438467
LINUX_IMAGE = $(LINUX_SRC)/arch/i386/boot/bzImage
LINUX_PATCH = $(PATCH_DIR)/linux.patch
LINUX_CONFIG = $(PATCH_DIR)/linux.config

INITRD_DIR = initrd_source
INITRD = $(INITRD_DIR)/initrd.gz

RAIDTOOLS_DIR = $(SRC_DIR)/raidtools-0.90
RAIDTOOLS_TARBALL = raidtools-19990824-0.90.tar.bz2
RAIDTOOLS_URL = http://www.kernel.org/pub/linux/daemons/raid/alpha/$(RAIDTOOLS_TARBALL)
RAIDTOOLS_PATCH = $(PATCH_DIR)/raidtools.patch
RAIDTOOLS_MD5SUM = 8a8460ae6731fa4debd912297c2402ca
REISERFSPROGS_DIR = $(LINUX_SRC)/fs/reiserfs/utils

#@all:
#@  build everything, install nothing
#@ 
all:	raidtools reiserfsprogs kernel initrd docs manpages

#@install_server_all:
#@  a complete server install
#@ 
install_server_all:	install_server install_common install_binaries

#@install_client_all:
#@  a complete client install
#@ 
install_client_all:	install_client install_common

#@@install_server:
#@@  install server-only architecture independent files
#@@ 
install_server:	install_manpages install_configs install_server_libs
	mkdir -p $(BIN)
	mkdir -p $(SBIN)
	$(foreach binary, $(BINARIES), \
		install -m 755 $(BINARY_SRC)/$(binary) $(BIN);)
	$(foreach binary, $(SBINARIES), \
		install -m 755 $(BINARY_SRC)/$(binary) $(SBIN);)
	install -d -m 755 $(LOG_DIR)
	install -d -m 755 $(TFTP_BIN_DEST)
	install -d -m 755 $(AUTOINSTALL_SCRIPT_DIR)
	install -d -m 755 $(PXE_CONF_DEST)
	install -m 644 --backup $(PXE_CONF_SRC)/message.txt \
		$(PXE_CONF_DEST)/message.txt
	install -m 644 --backup $(PXE_CONF_SRC)/syslinux.cfg \
		$(PXE_CONF_DEST)/syslinux.cfg
	install -m 644 --backup $(PXE_CONF_SRC)/syslinux.cfg \
		$(PXE_CONF_DEST)/default
	install -d -m 755 $(TFTP_ROOT)/systemimager
	install -m 644 tftpstuff/systemimager/updateclient.local.exclude \
		$(TFTP_ROOT)/systemimager
	install -m 755 $(TFTP_BIN_SRC)/prepareclient $(TFTP_BIN_DEST)
	install -m 755 $(TFTP_BIN_SRC)/updateclient $(TFTP_BIN_DEST)
	install -d -m 755 $(IMAGEDEST)
	$(foreach file, $(WARNING_FILES), \
		install -m 644 $(IMAGESRC)/README $(file);)

#@@install_client:
#@@  install client-only files
#@@ 
install_client: install_client_manpages
	mkdir -p $(ETC)/systemimager
	install -m 644 tftpstuff/systemimager/updateclient.local.exclude \
		$(ETC)/systemimager
	mkdir -p $(SBIN)

	$(foreach binary, $(CLIENT_SBINARIES), \
		install -m 755 $(CLIENT_BINARY_SRC)/$(binary) $(SBIN);)

#@@install_common:
#@@  install files common to both the server and client
#@@ 
install_common:	install_common_manpages
	mkdir -p $(BIN)
	$(foreach binary, $(COMMON_BINARIES), \
		install -m 755 $(COMMON_BINARY_SRC)/$(binary) $(BIN);)

#@@install_server_libs:
#@@  install server-only libraries
#@@ 
install_server_libs:
	mkdir -p $(LIB_DEST)
	cp $(LIB_SRC)/*.pm $(LIB_DEST)

#@@install_binaries:
#@@  install architecture-dependent files
#@@ 
install_binaries:	install_raidtools install_reiserfsprogs install_kernel install_initrd


########## BEGIN raidtools ##########

#@@install_raidtools:
#@@  install the raidtools binaries (pulled by some autoinstall clients)
#@@ 
install_raidtools:	raidtools
	mkdir -p $(TFTP_BIN_DEST)
	install -m 755 $(RAIDTOOLS_DIR)/mkraid $(TFTP_BIN_DEST)
	install -m 755 $(RAIDTOOLS_DIR)/raidstart $(TFTP_BIN_DEST)
	cp -a $(TFTP_BIN_DEST)/raidstart $(TFTP_BIN_DEST)/raidstop

#@@raidtools:
#@@  build the raidtools binaries
#@@ 
raidtools:
	$(MAKE) $(SRC_DIR)/$(RAIDTOOLS_TARBALL)
	[ -d $(RAIDTOOLS_DIR) ] || \
		( cd $(SRC_DIR) && bzcat $(RAIDTOOLS_TARBALL) | tar xv && \
		  [ ! -f ../$(RAIDTOOLS_PATCH) ] || \
		  patch -p0 < ../$(RAIDTOOLS_PATCH) )
	( cd $(RAIDTOOLS_DIR) && ./configure )
	$(MAKE) -C $(RAIDTOOLS_DIR)

# download the raidtools tarball
$(SRC_DIR)/$(RAIDTOOLS_TARBALL):
	[ -d $(SRC_DIR) ] || mkdir -p $(SRC_DIR)
	cd $(SRC_DIR) && wget $(RAIDTOOLS_URL)
	[ "$(RAIDTOOLS_MD5SUM)" == \
		`md5sum $(SRC_DIR)/$(RAIDTOOLS_TARBALL) | cut -d " " -f 1` ] \
		|| exit 1
########## END raidtools ##########

######### BEGIN reiserfsprogs ##########

#@@install_reiserfsprogs:
#@@  install a statically linked mkreiserfs binary - this is retrieved by
#@@  autoinstall clients that use the reiser filesystem
#@@ 
install_reiserfsprogs:	reiserfsprogs
	mkdir -p $(TFTP_BIN_DEST)
	install -m 755 $(REISERFSPROGS_DIR)/bin/mkreiserfs $(TFTP_BIN_DEST)

#@@reiserfsprogs:
#@@  build statically-linked reiserfsprogs	
#@@ 
reiserfsprogs:	patched_kernel
	make -C $(REISERFSPROGS_DIR)

######### END reiserfsprogs ##########

########## BEGIN kernel ##########
#@@install_kernel:
#@@  install the kernel that autoinstall clients will boot from during
#@@  autoinstallation
#@@ 
install_kernel:	kernel
	mkdir -p $(TFTP_BIN_DEST)
	cp -a $(LINUX_IMAGE) $(TFTP_BIN_DEST)/kernel

#@@kernel:
#@@  build the kernel that autoinstall clients will boot from during
#@@  autoinstallation
#@@ 
kernel:	kernel-build-stamp

kernel-build-stamp:
	$(MAKE) patched_kernel
	$(MAKE) -C $(LINUX_SRC) oldconfig dep bzImage
	touch kernel-build-stamp

patched_kernel:	patched_kernel-stamp

patched_kernel-stamp:
	$(MAKE) $(SRC_DIR)/$(LINUX_TARBALL)
	[ -d $(LINUX_SRC) ] || \
		( cd $(SRC_DIR) && bzcat $(LINUX_TARBALL) | tar xv && \
		  [ ! -f ../$(LINUX_PATCH) ] || \
		  patch -p0 < ../$(LINUX_PATCH) || /bin/true )
	cp -a $(LINUX_CONFIG) $(LINUX_SRC)/.config
	touch patched_kernel-stamp

$(SRC_DIR)/$(LINUX_TARBALL):
	[ -d $(SRC_DIR) ] || mkdir -p $(SRC_DIR)
	cd $(SRC_DIR) && wget $(LINUX_URL)
	[ "$(LINUX_MD5SUM)" == \
		`md5sum $(SRC_DIR)/$(LINUX_TARBALL) | cut -d " " -f 1` ] || \
		exit 1

########## END kernel ##########

########## BEGIN initrd ##########

#@@install_initrd:
#@@  install the autoinstall ramdisk - the initial ramdisk used by autoinstall
#@@  clients when beginning an autoinstall
#@@ 
install_initrd:
	$(MAKE) initrd
	mkdir -p $(TFTP_BIN_DEST)
	install -m 644 $(INITRD_DIR)/initrd.gz $(TFTP_BIN_DEST)

#@@initrd:
#@@  build the autoinstall ramdisk
#@@ 
initrd:
	make -C $(INITRD_DIR)

#@@install_configs:
#@@  install the initscript & config files
#@@ 
install_configs:
	mkdir -p $(ETC)/systemimager
	install -m 644 etc/rsyncd.conf $(ETC)/systemimager
	install -m 644 etc/systemimager.conf $(ETC)/systemimager
	mkdir -p $(INITD)
	install -m 755 etc/init.d/rsync $(INITD)/$(INITSCRIPT_NAME)

########## END initrd ##########

########## BEGIN man pages ##########

#@@install_manpages
#@@  install the manpages for the server
#@@ 
install_manpages:	manpages
	mkdir -p $(MAN8)
	$(foreach binary, $(BINARIES) $(SBINARIES), \
		cp -a $(MANPAGE_DIR)/$(binary).8.gz $(MAN8); )

#@@install_client_manpages
#@@  install the manpages for the client
#@@ 
install_client_manpages:	manpages
	mkdir -p $(MAN8)
	$(foreach binary, $(CLIENT_SBINARIES), \
		cp -a $(MANPAGE_DIR)/$(binary).8.gz $(MAN8); )

#@@install_common_manpages:
#@@  installs the manpages that are common to both the server and client
#@@ 
install_common_manpages:	manpages
	mkdir -p $(MAN8)
	$(foreach binary, $(COMMON_BINARIES), \
		cp -a $(MANPAGE_DIR)/$(binary).8.gz $(MAN8); )
#@@manpages
#@@  builds the man pages from SGML source
#@@ 
manpages:
	$(MAKE) -C $(MANPAGE_DIR)
########## END man pages ##########

#@install_docs:
#@  installs the manual and some examples
#@ 
install_docs: docs
	mkdir -p $(DOC)
	cp -a $(MANUAL_DIR)/html $(DOC)
	cd $(MANUAL_DIR) && cp *.ps *.pdf $(DOC)
	mkdir -p $(DOC)/examples
	install -m 644 etc/rsyncd.conf $(DOC)/examples
	install -m 644 etc/init.d/rsync $(DOC)/examples

#@docs:
#@  builds the manual from SGML source
#@ 
docs:
	$(MAKE) -C $(MANUAL_DIR) html ps pdf

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

#@get_source:
#@  pre-download the source to other packages that may be needed by other
#@  rules
#@ 
get_source:	$(SRC_DIR)/$(LINUX_TARBALL) $(SRC_DIR)/$(RAIDTOOLS_TARBALL)

#@help:
#@  prints a short description of the rules that are useful in most cases
#@ 
help:
	@echo 'This Makefiles provides targets to build and install the'
	@echo 'SystemImager packages.  Here are descriptions of the targets'
	@echo 'that are useful in most cases.'
	@echo ''
	@grep -e "^#@[^@]" Makefile | sed s/"#@"/""/

#@help_all:
#@  prints a short description of all rules, except those that aren't meant
#@  to be called directly
#@ 
help_all:
	@echo 'This Makefiles provides targets to build and install the'
	@echo 'SystemImager packages.  Here are descriptions of all the'
	@echo 'targets that should be called directly.'
	@echo ''
	@grep -e "^#@[^@]" Makefile | sed s/"#@"/""/
	@grep -e "^#@@" Makefile | sed s/"#@@"/""/

#@helpless:
#@  pipes the output of 'make help' through less
#@ 
install: 
	@echo 'To install the server, type:'
	@echo '  "make install_server_all"'
	@echo ''
	@echo 'To install the client, type:'
	@echo '  "make install_client_all"'
	@echo ''
	@echo 'Try "make help" for more options.'
	@echo ''

helpless:
	$(MAKE) help | less

#@helpless_all:
#@  pipes the output of 'make help_all' through less
#@ 
helpless_all:
	$(MAKE) help_all | less

#@clean:
#@  removes object files, docs, editor backup files, etc.
#@ 
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
	-umount $(TEMP_DIR)
	-rm -rf $(TEMP_DIR) ./modules $(TARBALL_BUILD_DIR)
	-rm $(AUTOINSTALL_TARBALL)

#@distclean:
#@  same as clean, but also removes downloaded source, stamp files, etc.
#@ 
distclean:	clean
	-rm patched_kernel-stamp kernel-build-stamp
	-rm -rf $(SRC_DIR)
	-$(MAKE) -C $(INITRD_DIR) distclean
