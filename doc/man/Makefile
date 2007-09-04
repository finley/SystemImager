#
# "SystemImager"
#
#  Copyright (C) 2002 Hewlett-Packard Company <dannf@fc.hp.com>
#  Copyright (C) 2002 Bald Guy Software <brian.finley@baldguysoftware.com>
#
#    $Id$
#


DESTDIR = 
PREFIX = /usr
USR = $(DESTDIR)$(PREFIX)

SYSTEMIMAGER_VERSION = $(shell cat ../../VERSION)

MANPAGES = $(SERVER_MAN) $(SERVER_POD_MAN) $(CLIENT_MAN) $(COMMON_MAN)

SERVER_MAN = si_addclients.8 				\
			si_getimage.8					\
			si_mkautoinstallcd.8			\
			si_mkautoinstallscript.8		\
			si_mkdhcpserver.8				\
			si_mkdhcpstatic.8				\
			si_cpimage.8					\
			si_mvimage.8					\
			si_rmimage.8					\
			si_mkbootserver.8				\
			systemimager.conf.5			\
			systemimager-rsyncd.conf.5	\
			si_mkrsyncd_conf.8				\
			si_pushupdate.8				\
			si_mkclientnetboot.8				\
			si_mkbootpackage.8		\
			\
			si_installbtimage.8		\
			si_monitor.8			\
			si_monitortk.8			\
			si_pcp.8			\
			si_psh.8			\
			si_pushinstall.8		\
			si_pushoverrides.8		\
			si_mkautoinstalldisk.8		\
			si_netbootmond.8		\
			si_clusterconfig.8

CLIENT_MAN = si_prepareclient.8 si_updateclient.8

COMMON_MAN = autoinstallscript.conf.5 si_lsimage.8

.SUFFIXES: .5 .8 .8.gz .5.gz .pod .sgml

all:	compress

%.gz:	%
	gzip -9 < $< > $@

systemimager.conf.5:	systemimager.conf.pod
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 5 -c "SystemImager" $< $@

systemimager-rsyncd.conf.5:	systemimager-rsyncd.conf.pod
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 5 -c "SystemImager" $< $@

si_installbtimage.8: $(TOPDIR)/sbin/si_installbtimage
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 8 -c "SystemImager" $< $@

si_monitor.8: $(TOPDIR)/sbin/si_monitor
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 8 -c "SystemImager" $< $@

si_monitortk.8: $(TOPDIR)/sbin/si_monitortk
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 8 -c "SystemImager" $< $@

si_pcp.8: $(TOPDIR)/sbin/si_pcp
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 8 -c "SystemImager" $< $@

si_psh.8: $(TOPDIR)/sbin/si_psh
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 8 -c "SystemImager" $< $@

si_pushinstall.8: $(TOPDIR)/sbin/si_pushinstall
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 8 -c "SystemImager" $< $@

si_pushoverrides.8: $(TOPDIR)/sbin/si_pushoverrides
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 8 -c "SystemImager" $< $@

si_mkautoinstalldisk.8: $(TOPDIR)/sbin/si_mkautoinstalldisk
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 8 -c "SystemImager" $< $@

si_netbootmond.8: $(TOPDIR)/sbin/si_netbootmond
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 8 -c "SystemImager" $< $@

si_clusterconfig.8: $(TOPDIR)/sbin/si_clusterconfig
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 8 -c "SystemImager" $< $@

%.5 %.8:	%.sgml %.content.sgml
	docbook2man $<
	mv $(shell echo $@ | tr '[:lower:]' '[:upper:]') $@

install_all:	install_common_man install_server_man install_client_man

manpages:	$(MANPAGES)

compress:	$(foreach file, $(MANPAGES), $(file).gz)

install_common_man:	$(foreach file, $(COMMON_MAN), $(file).gz)
	$(foreach manpage, $(COMMON_MAN), \
	  install -D -m 644 $(manpage).gz \
	    $(USR)/share/man/man`echo $(manpage) | \
	    sed 's/.*\(.\)$$/\1/'`/$(manpage).gz ;)

install_server_man:	$(foreach file, $(SERVER_MAN), $(file).gz)
	$(foreach manpage, $(SERVER_MAN), \
	  install -D -m 644 $(manpage).gz \
	    $(USR)/share/man/man`echo $(manpage) | \
	    sed 's/.*\(.\)$$/\1/'`/$(manpage).gz ;)

install_client_man:	$(foreach file, $(CLIENT_MAN), $(file).gz)
	$(foreach manpage, $(CLIENT_MAN), \
	  install -D -m 644 $(manpage).gz \
	    $(USR)/share/man/man`echo $(manpage) | \
	    sed 's/.*\(.\)$$/\1/'`/$(manpage).gz ;)

clean:
	rm -f *~ \#*\# *.8 *.5 *.gz manpage.links manpage.refs
