#
# "SystemImager" - Copyright (C) 1999-2001 Brian Elliott Finley <brian@systemimager.org> 
#
#   $Id$
#
#   Written by Dann Frazier <dannf@ldl.fc.hp.com>
#
#   Others who have contributed to this code:
#     Brian Finley <brian@systemimager.org>
#     Sean Dague <sean@dague.net>
#
#

### Editing this file ###
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

### File Locations ###
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

### Pre-defined rsync modules ###
#   o scripts                       autoinstallscripts/symlinks
#   o <arch>-boot (Ie., i386-boot -- dynamically determined in rcS)
#

### Packaging ###
# SystemImager package names and contents (non-tarball forms of packaging will # use the same base names):
#
#  o systemimager-server            all of the arch-independent components
#                                   needed only by an image server
#
#  o systemimager-client            all of the arch-independent components
#                                   needed only by a golden client (there are
#                                   no arch-dependent components at the moment)
#
#  o systemimager-common            all of the arch-independent components
#                                   shared by both the image server and the
#                                   golden client
#
#  o systemimager-kernel-<arch>     arch-specific kernel package.  the package
#                                   itself is arch-any as it can reside on a
#                                   server of any arch, so the arch is included
#                                   in the package name.
#
#  o systemimager-initrd-<arch>     arch-specific ramdisk package.  the package
#                                   itself is arch-any as it can reside on a
#                                   server of any arch, so the arch is included
#                                   in the package name.
#
#  o systemimager-bin-<arch>        arch-specific binary package.  the package
#                                   itself is arch-any as it can reside on a
#                                   server of any arch, so the arch is included
#                                   in the package name.
#
#  o systemimager-doc               documentation (manual, etc).
#
# There will be fewer SystemImager tarballs.  Currently, we have:
#   o systemimager-server           all components that reside on the server
#   o systemimager-client           all components that reside on the client
#   o systemimager-source           the source - duh.
#
# Justification for the inconsistency between tarballs and RPM/deb packaging:
#   o Package management allows us to enforce file dependencies.  We can
#     specify that systemimager-server shouldn't be installed until
#     systemimager-kernel-i386 is.  Including the kernel in the server package
#     thus gets rid of the FAQs such as:
#     "mkautoinstalldiskette fails - it claims it can't find
#      /usr/local/share/systemimager/i386-boot/kernel, what's wrong?"
#   o Package management allows us to enforce versioned dependencies in a
#     straightforward way.  We can require that systemimager-server version X
#     also has systemimager-initrd-i386 version X.  Tarballs don't have this
#     feature.  Using a newer systemimager-server with an older, incompatible
#     systemimager-initrd-i386 could cause installs to fail in mysterious ways.
#     
#   Sure, all of these issues could be fixed with smarter install scripts.
#   But we would essentially be writing our own package manager, and I don't
#   want to do that.  -dann
#         

DESTDIR =
VERSION = $(shell cat VERSION)

# RELEASE_DOCS are toplevel files that should be included with all posted
# tarballs, but aren't installed onto the destination machine by default
RELEASE_DOCS = CHANGE.LOG COPYING CREDITS ERRATA README TODO VERSION

PATH = /sbin:/bin:/usr/sbin:/usr/bin:/usr/bin/X11:/usr/local/sbin:/usr/local/bin
ARCH = $(shell uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/)
SUDO = $(shell if [ `id -u` != 0 ]; then echo -n "sudo"; fi)

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
TFTP_BIN          = prepareclient updateclient
TFTP_ROOT	  = $(USR)/share/systemimager
TFTP_BIN_DEST     = $(TFTP_ROOT)/$(ARCH)-boot

PXE_CONF_SRC      = tftpstuff/pxelinux.cfg
PXE_CONF_DEST     = $(TFTP_BIN_DEST)/pxelinux.cfg

BINARIES := mkautoinstallcd mkautoinstalldiskette
SBINARIES := addclients cpimage getimage mkdhcpserver mkdhcpstatic mkautoinstallscript mkbootserver mvimage pushupdate rmimage
CLIENT_SBINARIES  := updateclient prepareclient
COMMON_BINARIES   = lsimage

IMAGESRC    = ./var/spool/systemimager/images
IMAGEDEST   = $(DESTDIR)/var/lib/systemimager/images
WARNING_FILES = $(IMAGEDEST)/README $(IMAGEDEST)/DO_NOT_TOUCH_THESE_DIRECTORIES $(IMAGEDEST)/CUIDADO $(IMAGEDEST)/ACHTUNG
AUTOINSTALL_SCRIPT_DIR = $(DESTDIR)/var/lib/systemimager/scripts

LINUX_SRC = $(SRC_DIR)/linux

# Now we do multi architecture defines for kernel building

ifeq ($(ARCH),i386)
	 LINUX_VERSION = 2.4.14
	 LINUX_MD5SUM = dc03387783a8f58c90ef7b1ec6af252a
	 LINUX_IMAGE = $(LINUX_SRC)/arch/i386/boot/bzImage
	 LINUX_PATCH = $(PATCH_DIR)/linux.patch
	 LINUX_CONFIG = $(PATCH_DIR)/linux.config
	 LINUX_TARGET = bzImage
endif
ifeq ($(ARCH),ia64)
	 LINUX_VERSION = 2.4.9
	 LINUX_MD5SUM = 991c485866bd4c52504ec4721337b46c
	 LINUX_IMAGE = $(LINUX_SRC)/arch/ia64/boot/vmlinux
	 LINUX_PATCH = $(PATCH_DIR)/linux.ia64.patch
	 LINUX_CONFIG = $(PATCH_DIR)/linux.ia64.config
	 LINUX_TARGET = vmlinux
endif
ifeq ($(ARCH),s390)
	 LINUX_VERSION = 2.4.7
	 LINUX_MD5SUM = 5890ac5273402635e6fc7a804a3b5d7d
	 LINUX_IMAGE = $(LINUX_SRC)/arch/s390/boot/image
	 LINUX_PATCH = $(PATCH_DIR)/linux.s390.patch
	 LINUX_CONFIG = $(PATCH_DIR)/linux.s390.config
	 LINUX_TARGET = image
endif

LINUX_TARBALL = linux-$(LINUX_VERSION).tar.bz2
LINUX_URL = http://www.kernel.org/pub/linux/kernel/v2.4/$(LINUX_TARBALL)

RAMDISK_DIR = initrd_source

WGET = wget --passive-ftp

#@all:
#@  build everything, install nothing
#@ 
all:	kernel ramdisks docs manpages

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
	### install files in $(USR)/bin ###
	mkdir -p $(BIN)
	$(foreach binary, $(BINARIES), \
	  sed s/SYSTEMIMAGER_VERSION_STRING/"$(VERSION)"/ \
	    < $(BINARY_SRC)/$(binary) > $(BIN)/$(binary) && \
	  chmod 755 $(BIN)/$(binary);)

	### install files in $(USR)/sbin ###
	mkdir -p $(SBIN)
	$(foreach binary, $(SBINARIES), \
	  sed s/SYSTEMIMAGER_VERSION_STRING/"$(VERSION)"/ \
	    < $(BINARY_SRC)/$(binary) > $(SBIN)/$(binary) && \
	  chmod 755 $(SBIN)/$(binary);)

	install -d -m 755 $(PXE_CONF_DEST)
	$(foreach file, message.txt syslinux.cfg, \
	  sed s/SYSTEMIMAGER_VERSION_STRING/"$(VERSION)"/ \
	    < $(PXE_CONF_SRC)/$(file) > $(PXE_CONF_DEST)/$(file) && \
	  chmod 644 $(PXE_CONF_DEST)/$(file);)
	cp -a $(PXE_CONF_DEST)/syslinux.cfg $(PXE_CONF_DEST)/default

	install -d -m 755 $(TFTP_BIN_DEST)
	$(foreach binary, prepareclient updateclient, \
	  sed s/SYSTEMIMAGER_VERSION_STRING/"$(VERSION)"/ \
	    < $(TFTP_BIN_SRC)/$(binary) > $(TFTP_BIN_DEST)/$(binary) && \
	  chmod 755 $(TFTP_BIN_DEST)/$(binary);)

	install -d -m 755 $(IMAGEDEST)
	$(foreach file, $(WARNING_FILES), \
		install -m 644 $(IMAGESRC)/README $(file);)

	install -d -m 755 $(LOG_DIR)
	install -d -m 755 $(AUTOINSTALL_SCRIPT_DIR)

#@@install_client:
#@@  install client-only files
#@@ 
install_client: install_client_manpages install_client_libs
	mkdir -p $(ETC)/systemimager
	install -b -m 644 tftpstuff/systemimager/updateclient.local.exclude \
	  $(ETC)/systemimager
	mkdir -p $(SBIN)

	$(foreach binary, $(CLIENT_SBINARIES), \
	  sed s/SYSTEMIMAGER_VERSION_STRING/"$(VERSION)"/ \
	    < $(CLIENT_BINARY_SRC)/$(binary) > $(SBIN)/$(binary) && \
	    chmod 755 $(SBIN)/$(binary);)

#@@install_common:
#@@  install files common to both the server and client
#@@ 
install_common:	install_common_manpages install_common_libs
	mkdir -p $(BIN)
	$(foreach binary, $(COMMON_BINARIES), \
	  sed s/SYSTEMIMAGER_VERSION_STRING/"$(VERSION)"/ \
	    < $(COMMON_BINARY_SRC)/$(binary) > $(BIN)/$(binary) && \
	  chmod 755 $(BIN)/$(binary);)

#@@install_common_libs:
#@@  install libraries common to the server and client
#@@ 
install_common_libs:
	mkdir -p $(LIB_DEST)
	sed s/SYSTEMIMAGER_VERSION_STRING/"$(VERSION)"/ \
	  < $(LIB_SRC)/Common.pm > $(LIB_DEST)/Common.pm

#@@install_server_libs:
#@@  install server-only libraries
#@@ 
install_server_libs:
	mkdir -p $(LIB_DEST)
	cp $(LIB_SRC)/Server.pm $(LIB_DEST)

#@@install_client_libs:
#@@  install client-only libraries
#@@ 
install_client_libs:
	mkdir -p $(LIB_DEST)
	cp $(LIB_SRC)/Client.pm $(LIB_DEST)

#@@install_binaries:
#@@  install architecture-dependent files
#@@ 
install_binaries:	install_kernel install_ramdisks

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
	$(MAKE) -C $(LINUX_SRC) $(LINUX_TARGET)
	touch kernel-build-stamp

patched_kernel:	patched_kernel-stamp

patched_kernel-stamp:
	$(MAKE) $(SRC_DIR)/$(LINUX_TARBALL)
	[ -d $(LINUX_SRC) ] || \
		( cd $(SRC_DIR) && bzcat $(LINUX_TARBALL) | tar xv && \
		  [ ! -f ../$(LINUX_PATCH) ] || \
		    (cd linux && patch -p1 < ../../$(LINUX_PATCH)))
	cp -a $(LINUX_CONFIG) $(LINUX_SRC)/.config
	cd $(LINUX_SRC) && make oldconfig dep
	touch patched_kernel-stamp

$(SRC_DIR)/$(LINUX_TARBALL):
	[ -d $(SRC_DIR) ] || mkdir -p $(SRC_DIR)
	cd $(SRC_DIR) && ([ -f /usr/src/$(LINUX_TARBALL) ] && \
	  ln -s /usr/src/$(LINUX_TARBALL) .) || $(WGET) $(LINUX_URL)
	[ "$(LINUX_MD5SUM)" == \
		`md5sum $(SRC_DIR)/$(LINUX_TARBALL) | cut -d " " -f 1` ] || \
		exit 1

########## END kernel ##########

########## BEGIN ramdisks ##########

#@@install_ramdisks:
#@@  install the autoinstall ramdisks - the initial ramdisk used by autoinstall
#@@  clients when beginning an autoinstall, and the second stage ramdisk
#@@ 
install_ramdisks:
	$(MAKE) -C $(RAMDISK_DIR) install

#@@ramdisks:
#@@  build the autoinstall ramdisk
#@@ 
ramdisks:	ramdisks-build-stamp

ramdisks-build-stamp:
	make -C $(RAMDISK_DIR) all
	touch ramdisks-build-stamp

#@@install_configs:
#@@  install the initscript & config files
#@@ 
install_configs:
	mkdir -p $(ETC)/systemimager
	install -b -m 644 etc/rsyncd.conf $(ETC)/systemimager
	install -b -m 644 etc/systemimager.conf $(ETC)/systemimager
	[ "$(INITD)" != "" ] || exit 1
	mkdir -p $(INITD)
	install -b -m 755 etc/init.d/rsync $(INITD)/$(INITSCRIPT_NAME)

########## END ramdisks ##########

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
	cp $(MANUAL_DIR)/*.ps $(MANUAL_DIR)/*.pdf $(DOC)
	mkdir -p $(DOC)/examples
	install -m 644 etc/rsyncd.conf $(DOC)/examples
	install -m 644 etc/init.d/rsync $(DOC)/examples

#@docs:
#@  builds the manual from SGML source
#@ 
docs:
	$(MAKE) -C $(MANUAL_DIR) html ps pdf

#@get_source:
#@  pre-download the source to other packages that may be needed by other
#@  rules
#@ 
get_source:	$(SRC_DIR)/$(LINUX_TARBALL)

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

#@install:
#@ prints short message with installation instructions
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

#@helpless:
#@  pipes the output of 'make help' through less
#@ 
helpless:
	$(MAKE) help | less

#@helpless_all:
#@  pipes the output of 'make help_all' through less
#@ 
helpless_all:
	$(MAKE) help_all | less

#@source_tarball:
#@  create a source tarball
#@
source_tarball: ./tmp/systemimager-source-$(VERSION).tar.bz2

./tmp/systemimager-source-$(VERSION).tar.bz2:
	mkdir -p tmp/systemimager-source-$(VERSION)
	find . -maxdepth 1 -not -name . -not -name tmp \
	  -exec cp -a {} tmp/systemimager-source-$(VERSION) \;
	rm -rf `find tmp/systemimager-source-$(VERSION) -name CVS \
	  -type d -printf "%p "`
	$(MAKE) -C tmp/systemimager-source-$(VERSION) distclean
	cd tmp && tar -c systemimager-source-$(VERSION) | bzip2 > \
	  systemimager-source-$(VERSION).tar.bz2
	@echo
	@echo "server tarball has been created in ./tmp"
	@echo

#@client_tarball:
#@  create a user-distributable tarball for the client
#@ 
client_tarball:	./tmp/systemimager-client-$(VERSION).tar.bz2

./tmp/systemimager-client-$(VERSION).tar.bz2:
	mkdir -p ./tmp/systemimager-client-$(VERSION)
	$(MAKE) install_client_all DESTDIR=./tmp/systemimager-client-$(VERSION)
	$(MAKE) install_docs DESTDIR=./tmp/systemimager-client-$(VERSION)
	cp $(RELEASE_DOCS) installclient install_lib ./tmp/systemimager-client-$(VERSION)
	cd tmp && tar -c systemimager-client-$(VERSION) | bzip2 > \
		systemimager-client-$(VERSION).tar.bz2
	@echo
	@echo "client tarball has been created in ./tmp"
	@echo

#@server_tarball:
#@  create a user-distributable tarball for the server
#@ 
server_tarball:	./tmp/systemimager-server-$(VERSION).tar.bz2

./tmp/systemimager-server-$(VERSION).tar.bz2:
	mkdir -p ./tmp/systemimager-server-$(VERSION)
	$(MAKE) install_server_all DESTDIR=./tmp/systemimager-server-$(VERSION)
	$(MAKE) install_docs DESTDIR=./tmp/systemimager-server-$(VERSION)
	cp $(RELEASE_DOCS) installserver install_lib ./tmp/systemimager-server-$(VERSION)
	cd tmp && tar -c systemimager-server-$(VERSION) | bzip2 > \
		systemimager-server-$(VERSION).tar.bz2
	@echo
	@echo "server tarball has been created in ./tmp"
	@echo

#@tarballs:
#@  create user-distributable tarballs for the server and the client
#@ 
tarballs:
	$(MAKE) source_tarball client_tarball server_tarball
	@ echo -e "\ntarballs have been created in ./tmp\n"

debs:	all
	dpkg-buildpackage -r$(SUDO)

rpm:
	echo "I don't know how to build an RPM - will you please teach me?"
	echo "see debian/rules to see how the debs are built"
	echo "My .spec file is out of date" && exit 1
	# rpm -ba systemimager.spec

#@clean:
#@  removes object files, docs, editor backup files, etc.
#@ 
clean:
	-$(MAKE) -C $(LINUX_SRC) mrproper
	-$(MAKE) -C $(MANPAGE_DIR) clean
	-$(MAKE) -C $(MANUAL_DIR) clean
	-$(MAKE) -C $(RAMDISK_DIR) clean
	-find . -name "*~" -exec rm -f {} \;
	-find . -name "#*#" -exec rm -f {} \;
	-rm doc/manual_source/images

#@distclean:
#@  same as clean, but also removes downloaded source, stamp files, etc.
#@ 
distclean:	clean
	-rm *stamp
	-rm -rf $(SRC_DIR)
	-rm -rf tmp
	-$(MAKE) -C $(RAMDISK_DIR) distclean
