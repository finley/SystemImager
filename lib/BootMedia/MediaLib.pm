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
#   BootMedia tranformation by dann frazier <dannf@dannf.org>
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
package BootMedia::MediaLib;

use strict;
use Carp;
use File::Temp;

use lib qw(/usr/lib/systemconfig);
use Util::Log qw(:all);

use vars qw($VERBOSE);

sub my_system {
    my $cmd = shift;

    $cmd .= " > /dev/null 2>&1" unless 
    verbose("Executing: $cmd.");
    
    return !system($cmd);
}

sub init_disk_image {
    my $size = shift;
    my $outfile = shift;

    verbose("Creating an empty $outfile.\n");

    my $cmd = "dd if=/dev/zero of=$outfile bs=1k count=$size";
    !my_system($cmd) or return 1;

    return 0;
}

sub mount_ramdisk {
    my $image = shift;
    my $mount_point = shift;

    mkdir($mount_point);
    my $mount_cmd = "sudo mount $image $mount_point -t vfat -o loop";

    !my_system($mount_cmd) or return 1;
    
    return 0;
}	

sub umount_ramdisk {
    my $mount_point = shift;

    my $umount_cmd = "sudo umount $mount_point";
    
    !my_system($umount_cmd) or return 1;

    return 0;
}	

sub mkfs_disk_image {
    my $ramdisk = shift;

    my $mkfs_cmd = "/sbin/mkdosfs $ramdisk";
    !my_system($mkfs_cmd) or return 1;

    return 0;
}

sub populate_disk_image {
    my $files = shift;
    my $image = shift;

    verbose("Populating $image");
    my $mount_point = File::Temp::tempdir("/tmp/systemimager.tmp.XXXXX", 
					  CLEANUP => 1);
    my $status = 0;

    ## don't do anything if no files were given
    return $status unless %$files;

    ## Verify that all source files exist before preceding
    foreach my $file (keys %$files) {
	verbose("Checking to see if $file exists and is a regular file.\n");
	if (! -f $file) {
	    return 1;
	}
    }
    verbose("Attempting to mount ramdisk.\n");
    mount_ramdisk($image, "$mount_point");
    my $cp_cmd;
    foreach my $file (keys %$files) {
	$cp_cmd = "sudo cp $file $mount_point/$$files{$file}" or $status = undef;
	!my_system($cp_cmd) or $status = 2;
    }
    verbose("Attempting to unmount ramdisk.\n");
    umount_ramdisk("$mount_point") or $status = 3;
    rmdir("$mount_point") or warn "Couldn't remove $mount_point.";
    return $status;
}

sub run_mkisofs {
    my $dir = shift;
    my $arch = shift;
    my $extra_opts = shift;
    my $outfile = shift;

    my $version = "FAKE_VERSION";
    
    my $mkisofs_cmd = "mkisofs";
    $mkisofs_cmd .= " -A \"SystemImager $arch autoinstallcd v$version\"";
    $mkisofs_cmd .= " -V \"SystemImager $arch Boot CD\"";
    $mkisofs_cmd .= ' -p "Created by mkbootmedia -- part of SystemImager.';
    $mkisofs_cmd .= ' http://systemimager.org/"';
    $mkisofs_cmd .= " -J -r -T -v -pad";
    $mkisofs_cmd .= " $extra_opts";
    $mkisofs_cmd .= " -o $outfile $dir";
    !my_system($mkisofs_cmd) or return 0;

    return 1;
}

1;
