#
# "SystemImager" 
#
#  Copyright (C) 1999-2001 Brian Elliott Finley <brian.finley@baldguysoftware.com>
#  Copyright (C) 2001 Dann Frazier <dannf@ldl.fc.hp.com>
#
#  $Id$
#
#  Function: Create documentation from SGML source.
#
#  If you get errors when running make, and you are fortunate enough to be
#  building on a Debian box, just run: 
# 
#    "apt-get install sgmltools-lite jadetex"
#
#  to get all of the proper tools installed. -BEF-
#


NAME	        = systemimager-manual
BOOK            = $(NAME).sgml
SRC	        = $(shell echo *.sgml)
HTMLDIR         = html
SGMLTOOLS       = $(shell which sgmltools)
MANPAGE_CONTENT = $(shell ls ../man/*.sgml)
MANUAL_DEPS     = $(SRC) $(SGMLTOOLS) $(MANPAGE_CONTENT)

all:    html ps pdf dvi rtf txt

dvi:	$(NAME).dvi
pdf:    $(NAME).pdf
ps:	$(NAME).ps
rtf:	$(NAME).rtf
txt: 	$(NAME).txt

html:	$(MANUAL_DEPS)
	$(SGMLTOOLS) -b html $(BOOK)
	[ -d $(HTMLDIR) ] || mkdir $(HTMLDIR)
	mv $(NAME)/* $(HTMLDIR)
	rmdir $(NAME)
	[ -d $(HTMLDIR)/images ] || mkdir $(HTMLDIR)/images
	cp -a images/* $(HTMLDIR)/images

$(NAME).dvi:	$(MANUAL_DEPS)
	$(SGMLTOOLS) -b dvi $(BOOK)

$(NAME).pdf:	$(MANUAL_DEPS)
	# workaround for broken something or other (tetex-bin, i think)
	# see http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=130504
	cp --parents \
	  /usr/share/sgml/docbook/stylesheet/dsssl/modular/images/note.pdf .
	cp --parents \
	  /usr/share/sgml/docbook/stylesheet/dsssl/modular/images/warning.pdf .
	$(SGMLTOOLS) -b pdf $(BOOK)

$(NAME).ps:	$(MANUAL_DEPS)
	$(SGMLTOOLS) -b ps $(BOOK)

$(NAME).rtf:	$(MANUAL_DEPS)
	$(SGMLTOOLS) -b rtf $(BOOK)

$(NAME).txt:	$(MANUAL_DEPS)
	$(SGMLTOOLS) -b txt $(BOOK)

clean:
	find . -name "*~" -exec rm -f {} \;
	find . -name "#*#" -exec rm -f {} \;
	rm -rf $(NAME).aux $(NAME).dvi $(NAME).log $(NAME).out $(NAME).pdf \
	  $(NAME).ps $(NAME).rtf $(NAME).tex $(NAME).txt $(HTMLDIR) $(NAME) \
	  DBTOHTML_OUTPUT_DIR*
	rm -rf ./usr/

