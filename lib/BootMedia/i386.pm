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
package BootMedia::i386;

use strict;
use Carp;
use File::Temp;

use lib qw(/home/dannf/cvs/systemimager.head/lib);

use BootMedia::MediaLib;

use lib qw(/usr/lib/systemconfig);
use Util::Log qw(:all);


$boot_image_size = 1440;

sub build_floppy_image {
    my $spec = shift;
    my $outfile = shift;

    BootMedia::MediaLib::init_disk_image($boot_image_size, $outfile) or
	return 1;
    BootMedia::MediaLib::mkfs_disk_image($outfile) or return 2;
    (my $syslinux_fh, my $syslinux_path) =
	File::Temp::tempfile("/tmp/systemimager.tmp.XXXXX", CLEANUP => 1);
    verbose("Generating a syslinux config file in $syslinux_path");
    write_syslinux_conf($$spec{append}, $syslinux_fh) or return 3;
    my %files = ( $$spec{kernel} => "kernel",
		  $$spec{initrd} => "initrd.img",
		  $$spec{message} => "message.txt",
		  $syslinux_path => "syslinux.cfg",
		  );
    
    BootMedia::MediaLib::populate_disk_image(\%files, $outfile) or return 4;
    run_syslinux($outfile) or return 5;
    
    return 0;
}

sub build_iso_image {
    my $spec = shift;
    my $outfile = shift;

    my $isodir = File::Temp::tempdir("/tmp/systemimager.tmp.XXXXX", 
				     CLEANUP => 1);

    mkdir $isodir . "/boot" or verbose("mkdir $isodir failed: $!") and return 1;

    $eltorito_path = "$isodir/boot/siboot.img";

    build_floppy_image($spec, $eltorito_path) or return 3;
    my $mkisofs_extra = "-b boot/siboot.img -c boot/boot.catalog";
    BootMedia::MediaLib::run_mkisofs($isodir, "i386", $mkisofs_extra,
				     $outfile) or return 4;

    return 0;
				     
}

sub run_syslinux {
    my $image = shift;

    -f $image or return 1;

    my $cmd = "sudo syslinux -s $image";

    BootMedia::MediaLib::my_system($cmd) or return 2;

    return 0;
}

sub write_syslinux_conf {
    my $append = shift;
    my $out = shift;

    verbose("Writing a syslinux.cfg file...");

    my $default_config = "/etc/systemimager/pxelinux.cfg/syslinux.cfg";
    my $retval = open(DEFAULT, "<$default_config");
    if (!$retval) {
	verbose("Couldn't open $default_config.");
	return 1;
    }
    
    while (<DEFAULT>) {
	if (/^\s*APPEND.*/) { 
	    chomp;
	    print $out $_ . " " . $append . "\n";
	}
	else {
	    print $out $_;
	}
    }

    close(DEFAULT) or verbose("Closing $default_config failed.");
}
