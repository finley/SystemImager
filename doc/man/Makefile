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

MANPAGES = $(SERVER_MAN) $(CLIENT_MAN) $(COMMON_MAN)

SERVER_MAN = addclients.8 getimage.8 install_siboot.8 mkautoinstallcd.8 mkautoinstalldiskette.8 mkautoinstallscript.8 mkdhcpserver.8 mkdhcpstatic.8 pushupdate.8 cpimage.8 mvimage.8 rmimage.8 mkbootserver.8 systemimager.conf.5 systemimager-rsyncd.conf.5 mkrsyncd_conf.8

CLIENT_MAN = prepareclient.8 updateclient.8

COMMON_MAN = autoinstallscript.conf.5 lsimage.8

.SUFFIXES: .5 .8 .8.gz .5.gz .pod .sgml

all:	compress

%.gz:	%
	gzip -9 < $< > $@

systemimager.conf.5:	systemimager.conf.pod
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 5 -c "SystemImager" $< $@

systemimager-rsyncd.conf.5:	systemimager-rsyncd.conf.pod
	pod2man --release=$(SYSTEMIMAGER_VERSION) -s 5 -c "SystemImager" $< $@

%.5 %.8:	%.sgml %.content.sgml
	docbook2man $< > $@

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
