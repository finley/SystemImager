package SystemImager::InstallScript;

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

#  Copyright (C) 1999-2001 Brian Elliott Finley <brian@systemimager.org>
#  Copyright (C) 2002 International Business Machines
#                     Sean Dague <sean@dague.net>
#
#  Based on SystemImager::Server in SystemImager 2.0

#  $Id$

use strict;
use Carp;
use SystemImager::Config qw(get_config);
use base qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

$VERSION = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw(create_installscript);
%EXPORT_TAGS = ('all' => [@EXPORT_OK]);

# Here is the big top level function call.  We are going to have many
# sub calls to make this work right.

sub create_installscript {
    my ($image, $ipmethod, $postinstall, $arch) = @_;
    my $script = "";
    
    $script .= _check_for_mounts();
    
    
    return $script;
}

sub _check_for_mounts {
    my $script = <<END;

### BEGIN Check to be sure this not run from a working machine ###
# test for mounted SCSI or IDE disks
mount | grep [hs]d[a-z][1-9] > /dev/null 2>&1
[ $? -eq 0 ] &&  echo Sorry.  Must not run on a working machine... && shellout

# test for mounted software RAID devices
mount | grep md[0-9] > /dev/null 2>&1
[ $? -eq 0 ] &&  echo Sorry.  Must not run on a working machine... && shellout

# test for mounted hardware RAID disks
mount | grep c[0-9]+d[0-9]+p > /dev/null 2>&1
[ $? -eq 0 ] &&  echo Sorry.  Must not run on a working machine... && shellout
### END Check to be sure this not run from a working machine ###

# Pull in variables left behind by the linuxrc script.
# This information is passed from the linuxrc script on the autoinstall media via /tmp/variables.txt
# Apparently the shell on the autoinstall media is not intelligent enough to take a "set -a" parameter
. /tmp/variables.txt || shellout

### BEGIN Stop RAID devices before partitioning begins ###
# Why did they get started in the first place?  So we can pull a local.cfg
# file off a root mounted RAID system.  We do this even if a system does not
# use RAID, in case you are using a disk that was previously part of a RAID
# array.

# find running raid devices
RAID_DEVICES=`cat /proc/mdstat | grep ^md | mawk '{print "/dev/" $1}'`

# raidstop will not run unless a raidtab file exists
touch /etc/raidtab || shellout

# turn dem pesky raid devices off!
for RAID_DEVICE in ${RAID_DEVICES}
do
  # we don't do a shellout here because, well I forgot why, but we don't.
  echo "raidstop ${RAID_DEVICE}" && raidstop ${RAID_DEVICE}
done
### END Stop RAID devices before partitioning begins ###

END

  return $script;
}



42;

__END__

=head1 NAME

Autoinstall Script Process

=head1 EXECUTION TIME

In SystemImager 2.3 and beyond the autoinstall process will go
something like follows.

=over 4

=item 1)

Boot the kernel and initrd.gz

This may happen via floppy, cd, local hd, or network boot

=item 2)

Bring up network.

This is done either via local.cfg (if it exists and has enough info)
or via dhclient in the initrd.gz

=item 3)

Contact Image Server.

The Image Server network address is either provided via dhcp option
XXXXX or via IMAGESERVER variable in local.cfg.

=item 4)

rsync over autoinstallscript, and execute that script

=back

The rest of this documents the proposed logical steps of the 
autoinstall script.

=head1 STAGES OF INSTALL SCRIPT

=over 4

=item 1)

Make a second ramdisk at /dev/ram1 and mount as /stage2

This needs to be as big as stage2 plus some breathing room.

=item 2)

Fetch the appropriate stage2 tarball from the server

Possible options for stage2 tarballs:

  * normal
  * secure - ssh enabled
  * multicast - mrsync enabled

=item 3)

Untar stage2 at /stage2

=item 4)

Copy any required files from / to /stage2

Known files we need to carry with us:

  * /etc/resolv.conf

=item 5)

pivot_root to /stage2

=item 6)

partition drives

(Note: we need to think about ways to make this more flexible)

=item 7)

format partitions

All of the fs utilities should be included in the stage2 tarball

=item 8)

mount partitions

=item 9)

the big rsync

This is where the whole image comes down. 

If we are doing multicast or ssh this might have to be different commands 
here.

=item 10)

run systemconfigurator

This sets up networking and bootstrapping

=item 11)

unmount drives

=item 12)

run postinstall(s)

I think we need to think of a generalized way to do
postinstalls.  We may also want to have a phase 10.5 postinstall
that the user could specify incase they wanted to run
some code on the client after install.

=back

