#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# "SystemImager" 
#
#  Copyright (C) 1999-2018 Brian Elliott Finley <brian@thefinleys.com>
#                2017-2018 Olivier Lahaye <olivier.lahaye@cea.fr>
#
#  $Id$
#
#  Code written by Olivier LAHAYE.
#
# This file is run by cmdline hook from dracut-cmdline service
# It is called before parsing SIS command line options
# It makes sure $CMDLINE is not already set (otherwize, getarg would use this variable without checking if /etc/cmdline* exists).

type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

logdebug "==== init cmdline ===="

unset CMDLINE

# Now restore /etc/cmdline or /etc/cmdline.d/* (dracut will clean this up by default).

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

