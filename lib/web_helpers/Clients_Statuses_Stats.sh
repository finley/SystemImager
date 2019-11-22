!/bin/bash

CLIENTS_PATH=$(cat /etc/systemimager/systemimager.json|jq -r .monitor.clients_db_dir)

if test -d "$CLIENTS_PATH"
then
	cat $CLIENTS_PATH/*_def.json|jq -s 'map({"Status": .status})|group_by(.Status)|map({Status: .[0].Status, Count: length})|.' # Add [] to remove master table.
else
	echo "{}"
fi
