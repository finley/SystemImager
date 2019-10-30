#!/bin/bash
#
# SystemImager clients.xml migration tool.
#
# (c) Olivier LAHAYE <olivier.lahaye@cea.fr>
#
# Converts:
# /var/lib/systemimager/clients.xml
# to
# /var/lib/systemimager/clients/<MAC>_def.json
#

CONCAT="concat('{ ',"

for param in host status os speed ip name ncpus cpu kernel mem time first_timestamp timestamp
do
   CONCAT="${CONCAT}'\"$param\": \"',@${param},'\",',"
done
CONCAT="${CONCAT::-3} }')"
xmlstarlet sel -t -m "opt/client" -v "${CONCAT}" -n /var/lib/systemimager/clients.xml| while read CLIENT
do
	echo $CLIENT|jq . > /var/lib/systemimager/clients/$(echo $CLIENT|jq -r .name)_def.json
done
