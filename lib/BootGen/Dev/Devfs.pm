#  
#  Copyright (C) 2003-2004 dann frazier <dannf@dannf.org>
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
package BootGen::Dev::Devfs;

use strict;
use Carp;

use lib qw(/usr/lib/systemconfig);
use SystemConfig::Util::Log qw(:all);
use SystemConfig::Util::Cmd; # for which()

use vars qw ($VERBOSE);

push @BootGen::Dev::devstyles, qw(BootGen::Dev::Devfs);

sub new {
    my $class = shift;
    my %this = (
		);

    bless \%this, $class;
}

sub footprint {
    my $config = shift;

    verbose("Checking $config for cramfs support.");
    open(CONFIG, "<$config") or return 0;

    while (<CONFIG>) {
	if (/^CONFIG_DEVFS=y$/) {
	    verbose("Detected enabled CONFIG_DEVFS");
	}
    }

    open(MOUNTS, "</proc/mounts") or croak("Couldn't open /proc/mounts");
    while (<MOUNTS>) {
	if (/^devfs\s/) {
	    verbose("devfs is mounted");
	}
    }

    return 0;
}

sub build {
    my ($self, $tree) = @_;

    ## probably just want to make some mark in
    ## the tree, so the initrd knows what to do.
}

sub my_system {
    my $cmd = shift;

    $cmd .= " > /dev/null 2>&1" unless $VERBOSE;
    verbose("Executing: $cmd.");
    
    return !system($cmd);
}

1;
