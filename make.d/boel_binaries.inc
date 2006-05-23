#
#	$Id: bc.rul 3304 2005-12-16 04:35:34Z finley $
#   vi: set filetype=make:
#
# 	Perhaps there could be problems here in building multiple arch's from
# 	a single source directory, but we'll deal with that later...  Perhaps use
# 	$(TOPDIR)/tmp/$(ARCH)/ instead of just $(TOPDIR)/tmp/. -BEF-
#

BOEL_BINARIES_DIR 		= $(TOPDIR)/tmp/boel_binaries
BOEL_BINARIES_TARBALL 	= $(BOEL_BINARIES_DIR).tar.gz


PHONY += install_boel_binaries_tarball
install_boel_binaries_tarball:	$(BOEL_BINARIES_TARBALL)
	$(SI_INSTALL) -m 644 $(BOEL_BINARIES_TARBALL) $(BOOT_BIN_DEST)


PHONY += boel_binaries_tarball
boel_binaries_tarball:	$(BOEL_BINARIES_TARBALL)


$(BOEL_BINARIES_TARBALL):	$(BC_DIR).build \
							$(TAR_DIR).build \
							$(GZIP_BINARY) \
							$(DISCOVER_DIR).build \
							$(DISCOVER_DATA_DIR).build \
							$(HFSUTILS_BINARY) \
							$(DOSFSTOOLS_DIR).build \
							$(MKE2FS_BINARY) \
							$(TUNE2FS_BINARY) \
							$(PARTED_BINARY) \
							$(UTIL_LINUX_DIR).build \
							$(MDADM_BINARIES) \
							$(MKREISERFS_BINARY) \
							$(MKJFS_BINARY) \
							$(MKXFS_BINARY) \
							$(CTCS_BINARY) \
							$(OPENSSH_BINARIES) \
							$(OPENSSH_CONF_FILES) \
							$(LVM_BINARY) \
							$(SRC_DIR)/modules_build-stamp
	#
	# Put binaries in the boel_binaries_tarball...
	#
	mkdir -m 755 -p $(BOEL_BINARIES_DIR)/bin
	install -m 755 --strip $(BC_BINARY) 			$(BOEL_BINARIES_DIR)/bin/
	install -m 755 --strip $(TAR_BINARY) 			$(BOEL_BINARIES_DIR)/bin/
	install -m 755 --strip $(GZIP_BINARY) 			$(BOEL_BINARIES_DIR)/bin/
	mkdir -m 755 -p $(BOEL_BINARIES_DIR)/sbin
	install -m 755 --strip $(DISCOVER_BINARY) 		$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(HFSUTILS_BINARY) 		$(BOEL_BINARIES_DIR)/sbin/
	# XXX change these to be like: $(DOSFSTOOLS_DIR).install
	install -m 755 --strip $(MKDOSFS_BINARY) 		$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(MKE2FS_BINARY) 		$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(TUNE2FS_BINARY) 		$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(PARTED_BINARY)			$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(UTIL_LINUX_BINARIES)	$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(MDADM_BINARIES) 		$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(MKREISERFS_BINARY) 	$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(MKJFS_BINARY) 			$(BOEL_BINARIES_DIR)/sbin/
	install -m 755 --strip $(OPENSSH_BINARIES) 		$(BOEL_BINARIES_DIR)/sbin/
	mkdir -m 755 -p $(BOEL_BINARIES_DIR)/etc/ssh
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
	output=`find /lib/ -name libnss_dns*`
	test ! -n "$(output)" || cp -a /lib/libnss_dns*   $(BOEL_BINARIES_DIR)/lib
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
	output=`find /lib/ -name ld*`
	test ! -n "$(output)" || cp -a /lib/ld*   $(BOEL_BINARIES_DIR)/lib
	test ! -d /lib64 || cp -a /lib64/ld* $(BOEL_BINARIES_DIR)/lib64
endif

	TGTLIBDIR=lib ; \
	test ! -d /lib64 || TGTLIBDIR=lib64 ; \
	cd $(BOEL_BINARIES_DIR) \
		&& $(PYTHON) $(TOPDIR)/initrd_source/mklibs -L $(SRC_DIR)/$(PARTED_DIR)/libparted/.libs:$(DISCOVER_DIR)/lib/.libs:$(SRC_DIR)/$(DEVMAPPER_DIR)/lib/ioctl:$(SRC_DIR)/$(E2FSPROGS_DIR)/lib:/lib64:/usr/lib64:/usr/kerberos/lib64:/lib:/usr/lib:/usr/kerberos/lib -v -d $$TGTLIBDIR bin/* sbin/*
	#
	# Include other files required by openssh that apparently aren't 
	# picked up by mklibs for some reason. -BEF-
	#
	tar -cv $(OPENSSH_OTHER_FILES) | tar -C $(BOEL_BINARIES_DIR) -xv
	#
	#
	# install kernel modules. -BEF-
	#
	$(MAKE) -C $(LINUX_SRC) modules_install INSTALL_MOD_PATH="$(BOEL_BINARIES_DIR)"
	
	#
	# If the build system doesn't have module-init-tools installed, and
	# our modules need it, we need to use the depmod we built.  For now we'll
	# just say, you need to have module-init-tools installed for building.
	#
	# We could get fancy at some point, and test for it with something like this:
	#
	# 	depmod --version | grep -q module-init-tools
	#
	# and build it if it's not there.
	#
	# The find command is to figure out the kernel version string
	#
	BOEL_KERNEL_VERSION=`find $(BOEL_BINARIES_DIR)/lib/modules -type d -mindepth 1 -maxdepth 1 -printf "%f"` ; \
	depmod -b $(BOEL_BINARIES_DIR) $$BOEL_KERNEL_VERSION
	#
	
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


PHONY += boel_binaries_clean
boel_binaries_clean:
	rm -rf $(BOEL_BINARIES_DIR)
	rm -f  $(BOEL_BINARIES_DIR).prep
	rm -f  $(BOEL_BINARIES_TARBALL)
	



