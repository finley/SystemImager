#!/bin/bash
#
#    vi:set filetype=bash et ts=4:
#
#    This file is part of SystemImager.
#
#    SystemImager is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    SystemImager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with SystemImager. If not, see <https://www.gnu.org/licenses/>.
#
#    Copyright (C) 2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#    Purpose:
#      SystemImager clients.xml migration tool.
#
#    Converts:
#      /var/lib/systemimager/clients.xml
#    to a bunch of
#      /var/lib/systemimager/clients/<MAC>_def.json
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
