#
# "VA SystemImager" - Copyright (C) 1999-2001 Brian Elliott Finley <brian@thefinleys.com>
#
# This file is: Makefile
#               (Create documentation from SGML source)
#
#               Written by: Dann Frazier <daniel_frazier@hp.com>
#

DB_BIN_DIR = /usr/bin
DB2DVI	= $(DB_BIN_DIR)/db2dvi
DB2HTML = $(DB_BIN_DIR)/db2html
DB2PDF	= $(DB_BIN_DIR)/db2pdf
DB2PS   = $(DB_BIN_DIR)/db2ps
DB2RTF	= $(DB_BIN_DIR)/db2rtf

NAME	= systemimager-manual
SRC	= $(NAME).sgml

CREDITS = ../../CREDITS

HTMLDIR = html

all:    html ps pdf dvi rtf

dvi:	$(NAME).dvi
pdf:    $(NAME).pdf
ps:	$(NAME).ps
rtf:	$(NAME).rtf

html:	$(DB2HTML) $(SRC)
	$(DB2HTML) $(SRC)
	rm -rf $(HTMLDIR)
	mv -f $(NAME) $(HTMLDIR)
	cp -a images/ $(HTMLDIR)/images
	cp -a systemimager-manual.sgml $(HTMLDIR)

$(NAME).dvi:	$(DB2DVI) $(SRC)
	$(DB2DVI) $(SRC)
$(NAME).pdf:	$(DB2PDF) $(SRC)
	$(DB2PDF) $(SRC)
$(NAME).ps:	$(DB2PS) $(SRC)
	$(DB2PS) $(SRC)
$(NAME).rtf:	$(DB2RTF) $(SRC)
	$(DB2RTF) $(SRC)
clean:
	find . -name "*~" -exec rm -f {} \;
	find . -name "#*#" -exec rm -f {} \;
	rm -rf $(NAME).aux $(NAME).dvi $(NAME).log $(NAME).out $(NAME).pdf \
	  $(NAME).ps $(NAME).rtf $(NAME).tex $(HTMLDIR) DBTOHTML_OUTPUT_DIR*
