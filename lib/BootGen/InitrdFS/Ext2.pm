#  
#  Copyright (C) 2004 dann frazier <dannf@dannf.org>
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
package BootGen::InitrdFS::Ext2;

use strict;
use Carp;

use lib qw(/usr/lib/systemconfig);
use SystemConfig::Util::Log qw(:all);
use SystemConfig::Util::Cmd; # for which()

use vars qw ($VERBOSE);

push @BootGen::InitrdFS::fstypes, qw(BootGen::InitrdFS::Ext2);

sub footprint {
    my $self = shift;
    my $config = shift;

    verbose("Checking $config for ext2 support.");
    open(CONFIG, "<$config") or return 0;

    while (<CONFIG>) {
	if (/^CONFIG_EXT2=y$/) {
	    verbose("ext2 appears to be statically linked, returning success.");
	    return $_;
	}
    }
    
    return 0;
}

sub build {
    my ($self, $tree, $outfile) = @_;

    ## we should get this name from File::Temp
    my $tmpimg = $outfile . ".tmp";

    if (! -d $tree) {
	verbose("$tree is not a directory");
	return 0;
    }

    ## this code will be shared among most filesystem types
    ## maybe we should have a
    ##   InitrdFS::Generic::build_generic($fs, $size, $inodes, $mkfs);

    ## broken out of mkbootpackage
    # loopback file
    chomp(my $size = `du -ks $tree`);
    $size =~ s/\s+.*$//;
    my $breathing_room = 100;
    $size = $size + $breathing_room;
    my_system("dd if=/dev/zero of=$tmpimg bs=1024 count=$size");

    # fs creation
    chomp(my $inodes = `find $tree -printf "%i\n" | sort -u | wc -l`);
    $inodes = $inodes + 10;
    system("mke2fs -m 0 -N $inodes -F $tmpimg");

    # mount
    ## we should get a temp mount point with File::Temp
    system("sudo mount $tmpimg /tmp/mnt -o loop -t ext2");

    # copy from staging dir to new initrd
    system("tar -C $tree -cf - . | tar -C /tmp/mnt -xf -");

    # umount and gzip up
    system("sudo umount $tmpimg");
    system("gzip -9 < $tmpimg > $outfile");

    # return what my_system() returned
}

sub my_system {
    my $cmd = shift;

    $cmd .= " > /dev/null 2>&1" unless $VERBOSE;
    verbose("Executing: $cmd.");
    
    return !system($cmd);
}

1;

