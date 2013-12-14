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
package BootGen::InitrdFS::Cramfs;

use strict;
use Carp;

use lib qw(/usr/lib/systemconfig);
use SystemConfig::Util::Log qw(:all);
use SystemConfig::Util::Cmd; # for which()

use vars qw ($VERBOSE);

push @BootGen::InitrdFS::fstypes, qw(BootGen::InitrdFS::Cramfs);

sub footprint {
    my $self = shift;
    my $config = shift;

    verbose("Checking $config for cramfs support.");
    open(CONFIG, "<$config") or return 0;

    while (<CONFIG>) {
	if (/^CONFIG_CRAMFS=y$/) {
	    verbose("Cramfs appears to be statically linked, returning success.");
	    verbose("However, it cannot be determined if this kernel supports cramfs initrds.");
	    verbose("This requires a patch that some distributions provide (e.g., Debian.");
	    return $_;
	}
    }
    
    return 0;
}

sub build {
    my ($self, $tree, $outfile) = @_;

    my $mkcramfs = Util::Cmd::which("mkcramfs");

    unless ($mkcramfs) {
	verbose("Couldn't find mkcramfs.");
	return 0;
    }

    if (! -d $tree) {
	verbose("$tree is not a directory");
	return 0;
    }
    
    my_system("$mkcramfs $tree $outfile");
    
    # return what my_system() returned
}

sub my_system {
    my $cmd = shift;

    $cmd .= " > /dev/null 2>&1" unless $VERBOSE;
    verbose("Executing: $cmd.");
    
    return !system($cmd);
}

1;

