package SystemImager::Media;

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

#  Sean Dague <sean@dague.net>

#  $Id$

use strict;
use Carp;
use SystemImager::Config qw(get_config);
use base qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION $AUTOLOAD $ARCH);
use POSIX qw(uname);

$VERSION = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw(create_bootdisk create_bootcd create_netboot);
%EXPORT_TAGS = ('all' => [@EXPORT_OK]);

$ARCH = (uname())[4]; 
$ARCH =~ s/i.86/i386/;

print "Arch = $ARCH\n";

sub create_bootdisk {
    _do_boot_loader_things('i386');
}

#sub _do_boot_loader_things {
#
#}


sub AUTOLOAD {
    $AUTOLOAD =~ /.*::(\w+)/
      or croak("No such method: $AUTOLOAD");
    
    my $var = $1;
    my $return = "";
    eval {
        $return = "SystemImager::Media::$ARCH"->$var(@_);
    };
    if($@) {
        eval {
            $return = "SystemImager::Media::Base"->$var(@_);
        };
    }
    return $return;
}

package SystemImager::Media::Base;

sub _do_boot_loader_things {
    print "I am the base\n";
}

package SystemImager::Media::s390;
use base qw(SystemImager::Media::Base);



package SystemImager::Media::i386;

sub _do_boot_loader_things {
    print "I am i386\n";
}

package SystemImager::Media::ia64;

sub _do_boot_loader_things {
    print "I am ia64\n";
}



42;


