#
# Creates documentation from SGML source
# This file is: Makefile
#

DB2HTML = /usr/bin/db2html
SRC     = manual.sgml
DEST	= ..

all:    manual

manual:    $(DB2HTML) $(SRC) rm_old
	$(DB2HTML) $(SRC)
	mv -f manual $(DEST)
	cp -a images/ $(DEST)/manual/images
	@echo
	@echo "You can now find the manual in `cd $(DEST); pwd`/manual/"
	@echo "  (also known as $(DEST)/manual)"
	@echo

rm_old:
	rm -rf manual $(DEST)/manual

clean:	rm_old
	find . -name "*~" -exec rm {} \;
	find . -name "#*#" -exec rm {} \;

