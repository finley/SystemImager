#
#   "SystemImager"
#
#   Copyright (C) 2002 Bald Guy Software 
#                      Brian Elliott Finley <brian@bgsw.net>
#
#   $Id$
#

package SystemImager::Flamethrower_Config;

use strict;
use AppConfig qw(:argcount);

my $file = '/etc/systemimager/flamethrower.conf';

my $ft_config = AppConfig->new(

    { 
        CREATE => 1,
        GLOBAL => {
            ARGCOUNT => ARGCOUNT_ONE,
        },
    },

    # No need to define any variables here, unless we come up with one
    # that has attributes, such as ARGCOUNT, that are different from 
    # the GLOBAL default.
    #
    # Ie:
    #'my_other_var' => { ARGCOUNT => 2 },
    'modules' => { ARGCOUNT => ARGCOUNT_LIST },
    
);

$ft_config->file($file);

#
# Get a list of specified modules (don't know how to make appconfig give
# us this.)
#
open(FILE, "<$file") or die("Couldn't open $file");
    while (<FILE>) {
        if (m/^[[:space:]]*\[.*\][[:space:]]*$/) {
            s/[[:space:]]+//g;
            s/\[//g;
            s/\]//g;
            $ft_config->modules($_);
        }
    }
close(FILE);

$::main::ft_config = $ft_config;

