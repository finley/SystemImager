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
use Carp;
use SystemImager::Config qw(get_config);
use base qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

$VERSION = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw(client_exists addclient removeclient);
%EXPORT_TAGS = ('all' => [@EXPORT_OK]);

sub client_exists {
    my ($name) = @_;
}

sub _client_exists_hosts {
    my ($name) = @_;
    
}

sub _client_exists_link {
    my ($name) = @_;
    
}

sub _client_link {
    my ($name) = @_;
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
