package SystemImager::Client;

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

#   Sean Dague <sean@dague.net>
#   $Id$

use strict;
use File::Basename;
use Carp;
use SystemImager::Config qw(get_config);
use base qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

$VERSION = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw(client_exists addclient removeclient);
%EXPORT_TAGS = ('all' => [@EXPORT_OK]);

sub client_exists {
    my ($name) = @_;
    return _client_exists_link($name);
}

sub _client_exists_hosts {
    my ($name) = @_;
    return (_client_ip($name)) ? 1 : 0;
}

######################################################
#
#  _client_ip - given a host name that should be in the hosts file
#               return the ip address.  This uses the perl builtin
#               function gethostent which parses /etc/hosts for you.
#
######################################################

sub _client_ip {
    my ($name) = @_;
    my $ip;
    while(my ($fullname, $aliases, $addrtype, $length, @addrs) = gethostent()) {
        my @aliases = split(/\s+/, $aliases);
        if($name eq $fullname or _in($name, @aliases)) {
            # Ok... known issue already... this only grabs the first ip address.  Maybe not
            # a bad solution for now, but we have to think about this.
            # The unpack is taken from pg 721 Camel 3
            $ip = join '.', unpack('C4',$addrs[0]);
            last;
        }
    }
    return $ip;
}

######################################################
#
#   _in - this just takes an scalar and an array and tells you if the
#         the scalar is in the array.  It would be nice if this was a builtin.
#
######################################################

sub _in {
    my ($item, @array) = @_;
    foreach my $a (@array) {
        return 1 if($item eq $a) 
    }
    return undef;
}

sub _client_exists_link {
    my ($name) = @_;
    return (_client_image($name)) ? 1 : 0;
}

#################################
#
#  Not actually sure if we need to look for $name.master here, or if
#  it would be better somewhere else.
#
#################################

sub _client_image {
    my ($name) = @_;
    my $config = get_config();
    my $image = "";
    my $link = $config->autoinstall_script_dir . "/$name.sh";
    if(-l $link) {
        my $linkcontents = readlink $link or (carp($!), return undef);
        my $filename = basename($linkcontents);
        $filename =~ s/\.master$//;
        $image = $filename;
    } elsif (-f ($config->autoinstall_script_dir . "/$name.master")) {
        $image = $name;
    }
    return $image;
}

sub addclient {
    my ($name, $ip, $image) = @_;
}

sub _addclient_hosts {
    my ($name, $ip) = @_;
}

sub _addclient_link {
    my ($name, $image) = @_;
    
}

sub removeclient {
    my ($name) = @_;
}

sub _removeclient_hosts {
    my ($name) = @_;
}

sub _removeclient_link {
    my ($name) = @_;
}

1;
