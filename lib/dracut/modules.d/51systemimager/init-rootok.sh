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
# It's aim is to make dracut-cmdline happy when it has finisshed processing cmdline hooks
# dracut-cmdline hook expect root= and rootok= to be set after all scripts are run.
#
# We don't know yet the device of the real root (will know that when disks layout will have been processed)
# For now, we just put some values that will make dracut happy.

test -z "$root" && export root="UNSET"
export rootok="1"
