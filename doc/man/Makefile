SECTION = 8

compress:	prepareclient.8.gz updateclient.8.gz addclients.8.gz getimage.8.gz makeautoinstallcd.8.gz makeautoinstalldiskette.8.gz makedhcpserver.8.gz makedhcpstatic.8.gz

manpages:	prepareclient.8 updateclient.8 addclients.8 getimage.8 makeautoinstallcd.8 makeautoinstalldiskette.8 makedhcpserver.8 makedhcpstatic.8

prepareclient.8.gz:	prepareclient.8
	gzip -9 < prepareclient.8 > prepareclient.8.gz

prepareclient.8:	prepareclient.sgml
	docbook-to-man prepareclient.sgml > prepareclient.8

updateclient.8.gz:	updateclient.8
	gzip -9 < updateclient.8 > updateclient.8.gz

updateclient.8:	updateclient.sgml
	docbook-to-man updateclient.sgml > updateclient.8

addclients.8.gz:	addclients.8
	gzip -9 < addclients.8 > addclients.8.gz

addclients.8:	addclients.sgml
	docbook-to-man addclients.sgml > addclients.8

getimage.8.gz:	getimage.8
	gzip -9 < getimage.8 > getimage.8.gz

getimage.8:	getimage.sgml
	docbook-to-man getimage.sgml > getimage.8

makeautoinstallcd.8.gz:	makeautoinstallcd.8
	gzip -9 < makeautoinstallcd.8 > makeautoinstallcd.8.gz

makeautoinstallcd.8:	makeautoinstallcd.sgml
	docbook-to-man makeautoinstallcd.sgml > makeautoinstallcd.8

makeautoinstalldiskette.8.gz:	makeautoinstalldiskette.8
	gzip -9 < makeautoinstalldiskette.8 > makeautoinstalldiskette.8.gz

makeautoinstalldiskette.8:	makeautoinstalldiskette.sgml
	docbook-to-man makeautoinstalldiskette.sgml > makeautoinstalldiskette.8

makedhcpstatic.8.gz:	makedhcpstatic.8
	gzip -9 < makedhcpstatic.8 > makedhcpstatic.8.gz

makedhcpstatic.8:	makedhcpstatic.sgml
	docbook-to-man makedhcpstatic.sgml > makedhcpstatic.8

makedhcpserver.8.gz:	makedhcpserver.8
	gzip -9 < makedhcpserver.8 > makedhcpserver.8.gz

makedhcpserver.8:	makedhcpserver.sgml
	docbook-to-man makedhcpserver.sgml > makedhcpserver.8

clean:
	rm -f *~ \#*\# *.8 *.gz

