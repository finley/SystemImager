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


