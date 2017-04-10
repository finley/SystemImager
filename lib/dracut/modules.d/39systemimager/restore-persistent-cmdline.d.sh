#!/bin/bash

if test -d /etc/cmdline.d/
then
    test -d /etc/persistent-cmdline.d && cp /etc/persistent-cmdline.d/* /etc/cmdline.d/
    echo "rd.shell=1" > /etc/cmdline.d/90-systemimager-rdshell.conf
else
    for FILE in /etc/persistent-cmdline.d/*
    do
        echo >> /etc/cmdline
        cat $FILE >> /etc/cmdline
    done
    echo "rdshell" >> /etc/cmdline
fi

