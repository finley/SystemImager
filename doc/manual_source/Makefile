#
# Creates documentation from SGML source
# This file is: Makefile
#

DB2HTML = /usr/bin/db2html
SRC     := manual.sgml

all:    doc

doc:    $(DB2HTML) $(SRC)
	$(DB2HTML) manual.sgml
	mv manual ..
	cp -a images/ ../manual/images
	@echo
	@echo "You can now find the manual in `cd ..; pwd`/doc/manual/"
	@echo "  (also known as ../manual)"
	@echo

clean:
	rm -rf manual
	rm -rf ../manual
	find . -name "*~" -exec rm {} \;
	find . -name "#*#" -exec rm {} \;

