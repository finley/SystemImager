SECTION = 8

compress:	prepareclient.8.gz updateclient.8.gz addclients.8.gz getimage.8.gz mkautoinstallcd.8.gz mkautoinstalldiskette.8.gz mkautoinstallscript.8.gz mkdhcpserver.8.gz mkdhcpstatic.8.gz lsimage.8.gz pushupdate.8.gz cpimage.8.gz mvimage.8.gz rmimage.8.gz mkbootserver.8.gz

manpages:	prepareclient.8 updateclient.8 addclients.8 getimage.8 mkautoinstallcd.8 mkautoinstalldiskette.8 mkautoinstallscript.8 mkdhcpserver.8 mkdhcpstatic.8 lsimage.8 pushupdate.8 cpimage.8 mvimage.8 rmimage.8 mkbootserver.8

prepareclient.8.gz:	prepareclient.8
	gzip -9 < prepareclient.8 > prepareclient.8.gz

prepareclient.8:	prepareclient.sgml prepareclient.content.sgml
	docbook-to-man prepareclient.sgml > prepareclient.8

pushupdate.8.gz:	pushupdate.8
	gzip -9 < pushupdate.8 > pushupdate.8.gz

pushupdate.8:	pushupdate.sgml pushupdate.content.sgml
	docbook-to-man pushupdate.sgml > pushupdate.8

lsimage.8.gz:	lsimage.8
	gzip -9 < lsimage.8 > lsimage.8.gz

lsimage.8:	lsimage.sgml lsimage.content.sgml
	docbook-to-man lsimage.sgml > lsimage.8

updateclient.8.gz:	updateclient.8
	gzip -9 < updateclient.8 > updateclient.8.gz

updateclient.8:	updateclient.sgml updateclient.content.sgml
	docbook-to-man updateclient.sgml > updateclient.8

addclients.8.gz:	addclients.8
	gzip -9 < addclients.8 > addclients.8.gz

addclients.8:	addclients.sgml addclients.content.sgml
	docbook-to-man addclients.sgml > addclients.8

getimage.8.gz:	getimage.8
	gzip -9 < getimage.8 > getimage.8.gz

getimage.8:	getimage.sgml getimage.content.sgml
	docbook-to-man getimage.sgml > getimage.8

mkautoinstallcd.8.gz:	mkautoinstallcd.8
	gzip -9 < mkautoinstallcd.8 > mkautoinstallcd.8.gz

mkautoinstallcd.8:	mkautoinstallcd.sgml mkautoinstallcd.content.sgml
	docbook-to-man mkautoinstallcd.sgml > mkautoinstallcd.8

mkautoinstalldiskette.8.gz:	mkautoinstalldiskette.8
	gzip -9 < mkautoinstalldiskette.8 > mkautoinstalldiskette.8.gz

mkautoinstalldiskette.8:	mkautoinstalldiskette.sgml mkautoinstalldiskette.content.sgml
	docbook-to-man mkautoinstalldiskette.sgml > mkautoinstalldiskette.8

mkautoinstallscript.8.gz:	mkautoinstallscript.8
	gzip -9 < mkautoinstallscript.8 > mkautoinstallscript.8.gz

mkautoinstallscript.8:	mkautoinstallscript.sgml mkautoinstallscript.content.sgml
	docbook-to-man mkautoinstallscript.sgml > mkautoinstallscript.8

mkdhcpstatic.8.gz:	mkdhcpstatic.8
	gzip -9 < mkdhcpstatic.8 > mkdhcpstatic.8.gz

mkdhcpstatic.8:	mkdhcpstatic.sgml mkdhcpstatic.content.sgml
	docbook-to-man mkdhcpstatic.sgml > mkdhcpstatic.8

mkdhcpserver.8.gz:	mkdhcpserver.8
	gzip -9 < mkdhcpserver.8 > mkdhcpserver.8.gz

mkdhcpserver.8:	mkdhcpserver.sgml mkdhcpserver.content.sgml
	docbook-to-man mkdhcpserver.sgml > mkdhcpserver.8

cpimage.8.gz:	cpimage.8
	gzip -9 < cpimage.8 > cpimage.8.gz

cpimage.8:	cpimage.sgml cpimage.content.sgml
	docbook-to-man cpimage.sgml > cpimage.8

mvimage.8.gz:	mvimage.8
	gzip -9 < mvimage.8 > mvimage.8.gz

mvimage.8:	mvimage.sgml mvimage.content.sgml
	docbook-to-man mvimage.sgml > mvimage.8

rmimage.8.gz:	rmimage.8
	gzip -9 < rmimage.8 > rmimage.8.gz

rmimage.8:	rmimage.sgml rmimage.content.sgml
	docbook-to-man rmimage.sgml > rmimage.8

mkbootserver.8.gz:	mkbootserver.8
	gzip -9 < mkbootserver.8 > mkbootserver.8.gz

mkbootserver.8:	mkbootserver.sgml mkbootserver.content.sgml
	docbook-to-man mkbootserver.sgml > mkbootserver.8

clean:
	rm -f *~ \#*\# *.8 *.gz

