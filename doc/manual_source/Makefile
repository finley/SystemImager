#
# "VA SystemImager" - Copyright (C) 1999-2001 Brian Elliott Finley <brian@thefinleys.com>
#
# This file is: Makefile
#               (Create documentation from SGML source)
#
#               Written by: Dann Frazier <daniel_frazier@hp.com>
#

DB2HTML = /usr/bin/db2html
DB2PS   = /usr/bin/db2ps
DB2PDF	= /usr/bin/db2pdf
DB2DVI	= /usr/bin/db2dvi
DB2RTF	= /usr/bin/db2rtf

NAME	= systemimager-manual
SRC	= $(NAME).sgml
DEST	= ../manual

HTMLDIR = html
PSDIR   = ps
PDFDIR	= pdf
DVIDIR	= dvi
RTFDIR	= rtf

all:    html ps pdf dvi rtf

html:	$(DB2HTML) $(SRC) clean_html
	$(DB2HTML) $(SRC)
	mkdir -p $(DEST)
	mv -f $(NAME) $(DEST)/$(HTMLDIR)
	cp -a images/ $(DEST)/$(HTMLDIR)/images
	cp -a $(SRC) $(DEST)/$(HTMLDIR)
	@echo
	@echo "You can now find the manual in `cd $(DEST); pwd`/$(HTMLDIR)/"
	@echo "  (also known as $(DEST)/$(HTMLDIR)/)"
	@echo

ps:	$(DB2PS) $(SRC) clean_ps
	$(DB2PS) $(SRC)
	mkdir -p $(DEST)/$(PSDIR)
	mv $(NAME).aux $(NAME).dvi $(NAME).log $(NAME).tex $(NAME).ps $(DEST)/$(PSDIR)
	cp -a $(SRC) $(DEST)/$(PSDIR)
	@echo
	@echo "You can now find the manual in `cd $(DEST); pwd`/$(PSDIR)/"
	@echo "  (also known as $(DEST)/$(PSDIR)/)"
	@echo

pdf:	$(DB2PDF) $(SRC) clean_pdf
	$(DB2PDF) $(SRC)
	mkdir -p $(DEST)/$(PDFDIR)
	mv $(NAME).aux $(NAME).log $(NAME).tex $(NAME).pdf $(DEST)/$(PDFDIR)
	cp -a $(SRC) $(DEST)/$(PDFDIR)
	@echo
	@echo "You can now find the manual in `cd $(DEST); pwd`/$(PDFDIR)/"
	@echo "  (also known as $(DEST)/$(PDFDIR)/)"
	@echo

dvi:	$(DB2DVI) $(SRC) clean_dvi
	$(DB2DVI) $(SRC)
	mkdir -p $(DEST)/$(DVIDIR)
	mv $(NAME).aux $(NAME).dvi $(NAME).log $(NAME).tex $(DEST)/$(DVIDIR)
	cp -a $(SRC) $(DEST)/$(DVIDIR)
	@echo
	@echo "You can now find the manual in `cd $(DEST); pwd`/$(DVIDIR)/"
	@echo "  (also known as $(DEST)/$(DVIDIR)/)"
	@echo

rtf:	$(DB2RTF) $(SRC) clean_rtf
	$(DB2RTF) $(SRC)
	mkdir -p $(DEST)/$(RTFDIR)
	mv $(NAME).rtf $(DEST)/$(RTFDIR)
	cp -a $(SRC) $(DEST)/$(RTFDIR)
	@echo
	@echo "You can now find the manual in `cd $(DEST); pwd`/$(RTFDIR)/"
	@echo "  (also known as $(DEST)/$(RTFDIR)/)"
	@echo

clean:
	find . -name "*~" -exec rm -f {} \;
	find . -name "#*#" -exec rm -f {} \;
	rm -f $(NAME).aux $(NAME).dvi $(NAME).log $(NAME).tex $(NAME).out

clean_html:
	rm -rf $(DEST)/$(HTMLDIR) $(NAME)

clean_ps:
	rm -rf $(DEST)/$(PSDIR)

clean_pdf:
	rm -rf $(DEST)/$(PDFDIR)

clean_dvi:
	rm -rf $(DEST)/$(DVIDIR)

clean_rtf:
	rm -rf $(DEST)/$(RTFDIR)

clean_all:	clean clean_html clean_ps clean_pdf clean_rtf clean_dvi
	rm -rf $(DEST)

