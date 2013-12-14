#  
#  Copyright (C) 2003 dann frazier <dannf@dannf.org>
#
#  $Id$
# 
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
# 
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
# 
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
package BootGen::Dev::Static;

use strict;
use Carp;

use lib qw(/usr/lib/systemconfig);
use SystemConfig::Util::Log qw(:all);
use SystemConfig::Util::Cmd; # for which()

use vars qw ($VERBOSE);

push @BootGen::Dev::devstyles, qw(BootGen::Dev::Static);

sub new {
    my $class = shift;
    my %this = (
		);

    bless \%this, $class;
}

sub footprint {
    my $config = shift;
    
    my $dev = "/dev";
    ## not much of a test - more a sanity check
    if ( -d "$dev" ) {	
	return 1;
    }
    
    return 0;
}

sub build {
    my ($self, $tree) = @_;

    my $devsrc = "/dev";
    my $devdest = "$tree/dev";

    unless ( -d "$devdest" ) {
	verbose("Creating $devdest");
	my_system("mkdir $devdest") or return 0;
    }

    my_system("cp -a $devsrc/* $devdest");

    # return what my_system() returned
}

sub my_system {
    my $cmd = shift;

    $cmd .= " > /dev/null 2>&1" unless $VERBOSE;
    verbose("Executing: $cmd.");
    
    return !system($cmd);
}

1;
