COMMANDS := prepareclient updateclient
SECTION = 8

manpages:	prepareclient.8 updateclient.8

prepareclient.8:	prepareclient.sgml
	docbook-to-man prepareclient.sgml > prepareclient.8

updateclient.8:	updateclient.sgml
	docbook-to-man updateclient.sgml > updateclient.8
