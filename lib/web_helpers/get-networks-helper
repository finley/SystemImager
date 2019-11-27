#!/bin/bash
#
# SystemImager
#
# WebGUI Helper to list configured interfaces with associateds network.
echo -n "[ "
ip route|grep src|while read IP FOO DEV FOO
do
	echo -n "{ \"interface\": \"$DEV\", \"network\": \"$IP\" },"
done|sed 's/,$//g'
echo " ]"

