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
package Media;

use strict;
use Carp;

use lib "/usr/lib/systemimager/perl/Media";

#use Media::ia64;
use Media::i386;
use File::Temp;

sub my_system {
    my $cmd = shift;
    my $verbose = shift;

    $cmd .= " > /dev/null 2>&1" unless $verbose;
    if ($verbose) { print "Executing: $cmd.\n"; }
    
    return system($cmd);
}

sub create_floppy_image {
    my $arch = shift;
    my $outfile = shift;
    my @files = @_;

    init_boot_image($arch, $outfile) or return undef;
}

sub init_boot_image {
    my $outfile = shift;
    my $arch = shift;
    my $verbose = shift;

    my $count;

    ## FIXME: can this if/else mess be replaced with a
    ## reference similar to $Media::$arch::boot_image_size?
    if ($arch == "i386") {
	$count = $Media::i386::boot_image_size;
    }
    elsif ($arch == "ia64") {
	$count = $Media::ia64::boot_image_size;
    }
    else { 
	return undef;
    }
	
    return undef unless $count;
    
    if ($verbose) {
	print "Creating an empty $outfile.\n";
    }

    my $cmd = "dd if=/dev/zero of=$outfile bs=1k count=$count";
    !my_system($cmd, $verbose) or return undef;
}

sub mount_ramdisk {
    my $image = shift;
    my $mount_point = shift;
    my $verbose = shift;

    mkdir($mount_point);
    my $mount_cmd = "sudo mount $image $mount_point -t vfat -o loop";

    !my_system($mount_cmd, $verbose) or return undef;
}	

sub umount_ramdisk {
    my $mount_point = shift;
    my $verbose = shift;

    my $umount_cmd = "sudo umount $mount_point";
    
    !my_system($umount_cmd, $verbose) or return undef;
}	

sub create_ramdisk_fs {
    my $ramdisk = shift;
    my $verbose = shift;

    my $mkfs_cmd = "/sbin/mkdosfs $ramdisk";
    !my_system($mkfs_cmd, $verbose) or return undef;
}

sub populate_ramdisk {
    my $image = shift;
    my $verbose = shift;
    my %files = @_;
    
    my $mount_point = File::Temp::tempdir("systemimager.tmp.XXXXX", 
					  CLEANUP => 1);
    my $status = "ok";

    ## don't do anything if no files were given
    return $status unless %files;

    ## Verify that all source files exist before preceding
    foreach my $file (keys %files) {
	if ($verbose) {
	    print "Checking to see if $file exists and is a regular file.\n";
	}
	if (! -f $file) {
	    return undef;
	}
    }
    if ($verbose) { print "Attempting to mount ramdisk.\n"; }
    mount_ramdisk($image, "$mount_point", $verbose);
    my $cp_cmd;
    foreach my $file (keys %files) {
	$cp_cmd = "sudo cp $file $mount_point/$files{$file}" or $status = undef;
	!my_system($cp_cmd, $verbose) or $status = undef;
    }
    if ($verbose) { print "Attempting to unmount ramdisk.\n"; }
    umount_ramdisk("$mount_point", $verbose) or $status = undef;
    rmdir("$mount_point") or warn "Couldn't remove $mount_point.";
    return $status;
}

sub make_ramdisk_bootable {
    my $ramdisk = shift;
    my $arch = shift;
    my $verbose = shift;

    if ($arch eq "i386") {
	Media::i386::make_ramdisk_bootable($ramdisk, $verbose);
      }
    else {
	return undef;
    } 
}

sub create_bootloader_conf {
    my $ramdisk = shift;
    my $arch = shift;
    my $append = shift;
    my $verbose = shift;

    my $mount_point = File::Temp::tempdir("systemimager.tmp.XXXXX", 
					  CLEANUP => 1);
    my $file = $mount_point;

    SWITCH: {
	if ($arch eq "i386") { $file .= "/syslinux.cfg"; last SWITCH; }
	if ($arch eq "ia64") { $file .= "/elilo.conf"; last SWITCH; }
	warn "Unknown arch: $arch.";
	return undef;
    }
    
    my $status = "ok";
    mkdir($mount_point);
    mount_ramdisk($ramdisk, $mount_point, $verbose) 
	or warn "Unable to mount $ramdisk" and return undef;
    open(my $OUT, ">$file") or warn "Unable to open $file" and $status = undef;
    Media::i386::create_syslinux_conf($OUT, $append, $verbose) 
	or $status = undef;
    close($OUT);
    umount_ramdisk($mount_point, $verbose) or $status = undef;
    rmdir($mount_point) or warn "Couldn't remove $mount_point";
    return $status;
}

sub make_boot_iso {
    my $ramdisk = shift;
    my $arch = shift;
    my $outfile = shift;
    my $version = shift;
    my $verbose = shift;
    
    my $tempdir = File::Temp::tempdir("systemimager.tmp.XXXXX", CLEANUP => 1);
    mkdir($tempdir . "/boot");
    !my_system("cp $ramdisk $tempdir/boot/siboot.img", $verbose) 
	or return undef;
    my $mkisofs_cmd = "mkisofs";
    $mkisofs_cmd .= " -A \"SystemImager $arch autoinstallcd v$version\"";
    $mkisofs_cmd .= " -V \"SystemImager $arch Boot CD\"";
    $mkisofs_cmd .= ' -p "Created by mkbootmedia -- part of SystemImager.';
    $mkisofs_cmd .= ' http://systemimager.org/"';
    $mkisofs_cmd .= " -J -r -T -v -pad";
    $mkisofs_cmd .= " -b boot/siboot.img -c boot/boot.catalog";
    $mkisofs_cmd .= " -o $outfile $tempdir";
    !my_system($mkisofs_cmd, $verbose) or return undef;
    return "ok";
}
1;
