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
#    "apt-get install jadetex docbook-utils"
#
#  to get all of the proper tools installed. -BEF-
#


NAME	        = systemimager-manual
BOOK            = $(NAME).sgml
SRC	        = $(shell echo *.sgml)
HTMLDIR         = html
MANPAGE_CONTENT = $(shell ls ../man/*.sgml)
MANUAL_DEPS     = $(SRC) $(MANPAGE_CONTENT)

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
	# workaround for broken something or other (tetex-bin, i think)
	# see http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=130504
	#cp --parents \
	#  /usr/share/sgml/docbook/stylesheet/dsssl/modular/images/note.pdf .
	#cp --parents \
	#  /usr/share/sgml/docbook/stylesheet/dsssl/modular/images/warning.pdf .
	docbook2pdf $(BOOK)

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

