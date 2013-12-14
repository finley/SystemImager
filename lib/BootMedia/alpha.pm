#  
#  Copyright (C) 1999-2001 Brian Elliott Finley <brian.finley@baldguysoftware.com>
#  Copyright (C) 2002 Bald Guy Software <brian.finley@baldguysoftware.com>
#  Copyright (C) 2001 Sean Dague <sean@dague.net>
#  Copyright (C) 2003 dann frazier <dannf@danf.org>
#
#  $Id$
# 
#   Based on the original mkautoinstallcd by Brian Elliott Finley <brian.finley@baldguysoftware.com>
#   New version by Sean Dague <sean@dague.net>
#   Media.pm tranformation by dann frazier <dannf@dannf.org>
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
package BootMedia::alpha;

use strict;
use Carp;
use File::Temp;

#use lib qw(/home/dannf/cvs/systemimager.head/lib);

use BootMedia::MediaLib;

#use lib qw(/usr/lib/systemconfig);
use SystemConfig::Util::Log qw(:all);
    
sub build_floppy_image {
    my $spec = shift;
    my $outfile = shift;

    verbose("I don't know how to make a floppy image for alpha - please teach me.");
    return 1;
}

sub build_iso_image {
    my $spec = shift;
    my $outfile = shift;

    my $bootlx = "/boot/bootlx";
    if (! -f $bootlx) {
	verbose("$bootlx not found.");
	return undef;
    }
	
    my $isodir = File::Temp::tempdir("/tmp/systemimager.tmp.XXXXX", 
				     CLEANUP => 1);

    mkdir($isodir);
    mkdir($isodir . "/boot");
    mkdir($isodir . "/etc");

    foreach my $file ($$spec{kernel}, $$spec{initrd}, $bootlx) {
	if (! -f $file) {
	    verbose("$file does not exist.");
	    return undef;
	}
	my $cp_cmd = "cp $file $isodir/boot";
	BootMedia::MediaLib::my_system($cp_cmd) or return 3;
    }
    open(my $OUT, ">$isodir/aboot.conf");
    write_aboot_conf($OUT, $$spec{append_string});
    BootMedia::MediaLib::run_mkisofs($isodir, "alpha", "", $outfile) or return 4;
    run_isomarkboot($outfile) or return 5;

    return 0;
}

sub write_aboot_conf {
    my $out_fd = shift;
    my $append_string = shift;
    print $out_fd "0:boot/kernel root=/dev/ram initrd=boot/initrd.img";
    if ($append_string) {
	print $out_fd " $append_string";
    }
    print $out_fd "\n";
}

sub run_isomarkboot {
    my $iso = shift;
    my $verbose = shift;

    my $bootlx = "boot/bootlx";
    
    if (! -f $iso) {
	if ($verbose) {
	    print "$iso does not exist.\n";
	}
	return undef;
    }

    my $cmd = "sudo isomarkboot $iso $bootlx";
    $cmd .= " > /dev/null 2>&1" unless $verbose;

    if ($verbose) { print "Executing: $cmd.\n"; }
    !system($cmd) or return undef;

    return 0;
}

1;
