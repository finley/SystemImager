#
# Creates documentation from SGML source
# This file is: Makefile
#

DB2HTML = /usr/bin/db2html
NAME	= systemimager-manual
SRC	= $(NAME).sgml
DEST	= ..

all:    html

html:	$(DB2HTML) $(SRC) rm_old
	$(DB2HTML) $(SRC)
	mkdir -p $(DEST)
	mv -f $(NAME) $(DEST)
	cp -a images/ $(DEST)/$(NAME)/images
	@echo
	@echo "You can now find the manual in `cd $(DEST); pwd`/$(NAME)/"
	@echo "  (also known as $(DEST)/$(NAME))"
	@echo

rm_old:
	rm -rf $(NAME) $(DEST)/$(NAME)

clean:	rm_old
	find . -name "*~" -exec rm {} \;
	find . -name "#*#" -exec rm {} \;

