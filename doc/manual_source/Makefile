#
# "SystemImager" - Copyright (C) 1999-2001 Brian Elliott Finley <brian@systemimager.org>
#
# This file is: Makefile
#               (Create documentation from SGML source)
#
#               Written by: Dann Frazier <dannf@ldl.fc.hp.com>
#

NAME	= systemimager-manual
SRC	= $(NAME).sgml
HTMLDIR = html
SGMLTOOLS = $(shell which sgmltools)

all:    html ps pdf dvi rtf

dvi:	$(NAME).dvi
pdf:    $(NAME).pdf
ps:	$(NAME).ps
rtf:	$(NAME).rtf

html:	$(SGMLTOOLS) $(SRC)
	$(SGMLTOOLS) -b html $(SRC)
	mkdir $(HTMLDIR)
	mv $(NAME)/* $(HTMLDIR)
	rmdir $(NAME)
	cp -a images/ $(HTMLDIR)/images

$(NAME).dvi:	$(SGMLTOOLS) $(SRC)
	$(SGMLTOOLS) -b dvi $(SRC)
$(NAME).pdf:	$(SGMLTOOLS) $(SRC)
	# workaround for broken something or other (tetex-bin, i think)
	# see http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=130504
	cp --parents \
	  /usr/share/sgml/docbook/stylesheet/dsssl/modular/images/note.pdf .
	cp --parents \
	  /usr/share/sgml/docbook/stylesheet/dsssl/modular/images/warning.pdf .
	$(SGMLTOOLS) -b pdf $(SRC)
$(NAME).ps:	$(SGMLTOOLS) $(SRC)
	$(SGMLTOOLS) -b ps $(SRC)
$(NAME).rtf:	$(DB2RTF) $(SRC)
	$(SGMLTOOLS) -b rtf $(SRC)
clean:
	find . -name "*~" -exec rm -f {} \;
	find . -name "#*#" -exec rm -f {} \;
	rm -rf $(NAME).aux $(NAME).dvi $(NAME).log $(NAME).out $(NAME).pdf \
	  $(NAME).ps $(NAME).rtf $(NAME).tex $(HTMLDIR) $(NAME) \
	  DBTOHTML_OUTPUT_DIR*
	rm -rf ./usr/

