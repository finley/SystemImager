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
use AppConfig;

my $ft_config = AppConfig->new(

    { 
        CREATE => 1,
        GLOBAL => {
            ARGCOUNT => 1,
        },
    },

    # No need to define any variables here, unless we come up with one
    # that has attributes, such as ARGCOUNT, that are different from 
    # the GLOBAL default.
    #
    # Ie:
    #'my_other_var' => { ARGCOUNT => 2 },
    
);

$ft_config->file('/etc/systemimager/flamethrower.conf');

$::main::ft_config = $ft_config;

