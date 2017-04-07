#!/bin/bash

if test -d /etc/cmdline.d/
then 
    test -d /etc/persistent-cmdline.d && cp /etc/persistent-cmdline.d/* /etc/cmdline.d/
else
    for FILE in /etc/persistent-cmdline.d/*
    do
        echo >> /etc/cmdline
        cat $FILE >> /etc/cmdline
    done
fi
