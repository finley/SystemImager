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
package BootMedia::BootMedia;

use strict;
use Carp;
use File::Temp;

#use lib qw(/usr/lib/systemconfig);
use SystemConfig::Util::Log qw(:all);

use vars qw($VERBOSE);

#use lib qw(/home/dannf/cvs/systemimager.head/lib);
use BootMedia::alpha;
use BootMedia::i386;

sub build_floppy_image {
    my $spec = shift;
    my $arch = shift;
    my $out = shift;

    if ($arch eq "i386") {
	BootMedia::i386::build_floppy_image($spec, $out);
      }
    elsif ($arch eq "alpha") {
	BootMedia::alpha::build_floppy_image($spec, $out);
      }
}

sub build_iso_image {
    my $spec = shift;
    my $arch = shift;
    my $out = shift;

    if ($arch eq "i386") {
	BootMedia::i386::build_iso_image($spec, $out);
      }
    elsif ($arch eq "alpha") {
	BootMedia::alpha::build_iso_image($spec, $out);
      }
}

1;
