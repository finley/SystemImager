package SystemImager::Config;

#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
 
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
 
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#  Sean Dague <sean@dague.net>

#  $Id$

use strict;
use Carp;
use AppConfig;
use base qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

my $DEFAULT_CONFIG = "/etc/systemimager/systemimager.conf";

$VERSION = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw(get_config);
%EXPORT_TAGS = ('all' => [@EXPORT_OK]);

#  get_config is an exported function that has all the config file parsing
#  options set in it.  All systemimager commands and modules should
#  use get_config to get the default systemimager config variables.

sub get_config {
    
    my $config = AppConfig->new(
                                'autoinstall_script_dir' => { ARGCOUNT => 1 },
                                'autoinstall_boot_dir' => { ARGCOUNT => 1 },
                                'default_imagedir' => { ARGCOUNT => 1 },
                                'rsyncd_conf' => { ARGCOUNT => 1 },
                                'config_dir' => { ARGCOUNT => 1 },
                               );
    my $file = $ENV{SYSTEMIMAGER_CONFIG} || $DEFAULT_CONFIG;
    $config->file($file);
    return $config;
}

42; # Just for fun... it has to be non zero


