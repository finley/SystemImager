#
# "SystemImager"
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
package Media::i386;

$boot_image_size = 1440;

sub make_ramdisk_bootable {
    my $ramdisk = shift;
    my $verbose = shift;

    -f $ramdisk or return undef;

    my $cmd = "sudo syslinux -s $ramdisk";
    $cmd .= " > /dev/null 2>&1" unless $verbose;

    if ($verbose) { print "Executing: $cmd.\n"; }
    !system($cmd) or return undef;
}

sub create_syslinux_conf {
    my $out = shift;
    my $append = shift;
    my $verbose = shift;
    
    my $default_config = "/etc/systemimager/pxelinux.cfg/syslinux.cfg";
    open(DEFAULT, "<$default_config") 
	or warn "Couldn't open $default_config." and return undef;
    
    while (<DEFAULT>) {
	if (/^\s*APPEND.*/) { 
	    chomp;
	    print $out $_ . " " . $append . "\n";
	}
	else {
	    print $out $_;
	}
    }
    close(DEFAULT);
}
