#
# "SystemImager" 
#
#  Copyright (C) 1999-2001 Brian Elliott Finley <brian.finley@baldguysoftware.com>
#  Copyright (C) 2001-2003 Dann Frazier <dannf@hp.com>
#
#  $Id$
#
#  Function: Create documentation from SGML source.
#
#  If you get errors when running make, and you are fortunate enough to be
#  building on a Debian box, do the following to get all the proper tools 
#  installed:
# 
#    "apt-get install jadetex docbook-utils sgmltools-lite"
#
#
#  It may also be prefereable to do a "make USE_SGMLTOOLS=1 <target>" if you are on Debian.
#


NAME	        = systemimager-manual
BOOK            = $(NAME).sgml
SRC	        = $(shell echo *.sgml)
HTMLDIR         = html
MANPAGE_CONTENT = $(shell ls ../man/*.sgml)
MANUAL_DEPS     = $(SRC) $(MANPAGE_CONTENT) dedosify

all:    html ps pdf dvi rtf txt

dvi:	$(NAME).dvi
pdf:    $(NAME).pdf
ps:	$(NAME).ps
rtf:	$(NAME).rtf
txt: 	$(NAME).txt

html:	$(MANUAL_DEPS)
	docbook2html -o $(HTMLDIR) $(BOOK)
	[ -d $(HTMLDIR)/images ] || mkdir $(HTMLDIR)/images
	cp -a images/* $(HTMLDIR)/images

$(NAME).dvi:	$(MANUAL_DEPS)
	docbook2dvi $(BOOK)

$(NAME).pdf:	$(MANUAL_DEPS)
	# sgmltools makes better pdfs (e.g., page numbers, less cruft on
	# the cover), but using docbook-utils is more portable across distros
ifeq ($(USE_SGMLTOOLS),1)
	# workaround for broken something or other (tetex-bin, i think)
	# see http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=130504
	cp --parents \
	  /usr/share/sgml/docbook/stylesheet/dsssl/modular/images/note.pdf .
	cp --parents \
	  /usr/share/sgml/docbook/stylesheet/dsssl/modular/images/warning.pdf .
	sgmltools -b pdf $(BOOK)
else
	docbook2pdf $(BOOK)
endif

$(NAME).ps:	$(MANUAL_DEPS)
	docbook2ps $(BOOK)

$(NAME).rtf:	$(MANUAL_DEPS)
	docbook2rtf $(BOOK)

$(NAME).txt:	$(MANUAL_DEPS)
	docbook2txt $(BOOK)

clean:
	find . -name "*~" -exec rm -f {} \;
	find . -name "#*#" -exec rm -f {} \;
	rm -f $(NAME).aux
	rm -f $(NAME).dvi
	rm -f $(NAME).log
	rm -f $(NAME).out
	rm -f $(NAME).pdf
	rm -f $(NAME).ps
	rm -f $(NAME).rtf
	rm -f $(NAME).tex
	rm -f $(NAME).txt
	rm -rf $(NAME)
	rm -rf $(HTMLDIR)
	rm -rf DBTOHTML_OUTPUT_DIR*
	rm -rf ./usr/

dedosify:
	dos2unix *.sgml

.PHONY:	dedosify
