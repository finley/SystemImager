#
#   "SystemImager"
#
#   Copyright (C) 2002 Bald Guy Software 
#                      Brian Elliott Finley <brian@bgsw.net>
#
#   $Id$
#

package SystemImager::Flamethrower;

################################################################################
#
# Subroutines in this module include:
#
#   process_modules
#   read_config
#
#
################################################################################

use strict;
use AppConfig qw(:argcount :expand);

my $ft_config = AppConfig->new();

# Usage: Flamethrower->read_config($file);
sub read_config {

    my ($class, $file) = (@_);

    my $ft_config = AppConfig->new(
    
        { 
            CREATE => 1,
            GLOBAL => {
                ARGCOUNT => ARGCOUNT_ONE,
                DEFAULT => '',
                EXPAND => EXPAND_VAR,
            },
        },
    
        # No need to define any variables here, unless we come up with one
        # that has attributes, such as ARGCOUNT, that are different from 
        # the GLOBAL default.
        #
        # Ie:
        #'my_other_var' => { ARGCOUNT => 2 },
        
        'modules' => { ARGCOUNT => ARGCOUNT_LIST },

        'start_flamethrower_daemon'         => { ARGCOUNT => ARGCOUNT_ONE },
        'flamethrower_directory_portbase'   => { ARGCOUNT => ARGCOUNT_ONE },
        'flamethrower_directory_dir'        => { ARGCOUNT => ARGCOUNT_ONE },
        'flamethrower_state_dir'            => { ARGCOUNT => ARGCOUNT_ONE },
        'min_clients'                       => { ARGCOUNT => ARGCOUNT_ONE },
        'max_wait'                          => { ARGCOUNT => ARGCOUNT_ONE },
        'min_wait'                          => { ARGCOUNT => ARGCOUNT_ONE },
        'async'                             => { ARGCOUNT => ARGCOUNT_ONE },
        'autostart'                         => { ARGCOUNT => ARGCOUNT_ONE },
        'blocksize'                         => { ARGCOUNT => ARGCOUNT_ONE },
        'broadcast'                         => { ARGCOUNT => ARGCOUNT_ONE },
        'fec'                               => { ARGCOUNT => ARGCOUNT_ONE },
        'interface'                         => { ARGCOUNT => ARGCOUNT_ONE },
        'log'                               => { ARGCOUNT => ARGCOUNT_ONE },
        'max_bitrate'                       => { ARGCOUNT => ARGCOUNT_ONE },
        'full_duplex'                       => { ARGCOUNT => ARGCOUNT_ONE },
        'mcast_addr'                        => { ARGCOUNT => ARGCOUNT_ONE },
        'mcast_all_addr'                    => { ARGCOUNT => ARGCOUNT_ONE },
        'min_slice_size'                    => { ARGCOUNT => ARGCOUNT_ONE },
        'slice_size'                        => { ARGCOUNT => ARGCOUNT_ONE },
        'pointopoint'                       => { ARGCOUNT => ARGCOUNT_ONE },
        'rexmit_hello_interval'             => { ARGCOUNT => ARGCOUNT_ONE },
        'ttl'                               => { ARGCOUNT => ARGCOUNT_ONE },
        
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

        #
        # Be sure to include the flamethrower_directory in the list.
        # This allows us to make the buid_command subroutine more
        # generic, as $ft_config->get(${module}_dir) will work for
        # flamethrower_directory as well as all the "normal" modules.
        #
        $ft_config->modules('flamethrower_directory');

    close(FILE);
    
    $::main::ft_config = $ft_config;
}

