COMMANDS := prepareclient updateclient
SECTION = 8

manpages:	compress

compress:	prepareclient.8.gz updateclient.8.gz addclients.8.gz getimage.8.gz

prepareclient.8.gz:	prepareclient.8
	gzip -9 < prepareclient.8 > prepareclient.8.gz

updateclient.8.gz:	updateclient.8
	gzip -9 < updateclient.8 > updateclient.8.gz

addclients.8.gz:	addclients.8
	gzip -9 < addclients.8 > addclients.8.gz

getimage.8.gz:	getimage.8
	gzip -9 < getimage.8 > getimage.8.gz

prepareclient.8:	prepareclient.sgml
	docbook-to-man prepareclient.sgml > prepareclient.8

updateclient.8:	updateclient.sgml
	docbook-to-man updateclient.sgml > updateclient.8

addclients.8:	addclients.sgml
	docbook-to-man addclients.sgml > addclients.8

getimage.8:	getimage.sgml
	docbook-to-man getimage.sgml > getimage.8

clean:
	rm -f *~ \#*\# *.8 *.gz

