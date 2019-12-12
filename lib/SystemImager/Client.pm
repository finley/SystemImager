package SystemImager::Client;

#
# "SystemImager"
#
#  Copyright (C) 2001-2014 Brian E. Finley <brian@thefinleys.com>
#  Copyright (C) 2001-2002 Sean Dague <sean@dague.net>
#  Copyright (C) 2015-2019 Olivier Lahaye <olivier.lahaye@cea.fr>
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

use strict;
use File::Basename;
use File::Copy;
use Carp;
use SystemImager::JConfig;
use base qw(Exporter);
use vars qw($jconfig @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

$VERSION = "SYSTEMIMAGER_VERSION_STRING";

@EXPORT_OK = qw(client_exists client_info addclient removeclient);
%EXPORT_TAGS = ('all' => [@EXPORT_OK]);

########################################
#
#  client_exists - return a 1 if client exists, 0 if it doesn't
#
########################################

sub client_exists {
    my ($name) = @_;
    return _client_exists_link($name);
}

sub client_info {
    my ($name) = @_;
    my $hash = {
                ip => _client_ip($name),
                image => _client_image($name),
               };
    return $hash;
}

sub listclients {
    my ($image) = @_;
    my @clients;
    my $scriptdir = $jconfig->get('imager','scripts_dir')."/main-install";
    opendir(IN,$scriptdir) or (carp($!), return undef);
    while(my $file = <IN>) {
        if($image and (-d $jconfig->get('imager','images_dir') . "/$image")) {
            if(readlink("$scriptdir/$file") eq "$image.master") {
                my $clientname = $file;
                $clientname =~ s/\.sh//g;
                push @clients, $clientname;
            }
        } else {
            if(readlink("$scriptdir/$file") =~ /\.master$/) {
                my $clientname = $file;
                $clientname =~ s/\.sh//g;
                push @clients, $clientname;
            }
        }
    }
    closedir(IN);
    return @clients;
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
        return 1 if($item eq $a); 
    }
    return undef;
}

sub _client_exists_link {
    my ($name) = @_;
    return (_client_image($name)) ? 1 : 0;
}

#################################
#
#  _client_image - this returns the name of the image that the
#                  client uses to install.
#
#################################

sub _client_image {
    my ($name) = @_;
    my $image = "";
    my $link = $jconfig->get('imager','scripts_dir') . "/main-install/$name.sh";
    if(-l $link) {
        my $linkcontents = readlink $link or (carp($!), return undef);
        my $filename = basename($linkcontents);
        $filename =~ s/\.master$//;
        $image = $filename;
    } elsif (-f ($jconfig->get('imager','scripts_dir') . "/main-install/$name.master")) {
        $image = $name;
    }
    return $image;
}

sub addclient {
    my ($name, $ip, $image) = @_;
    if(!_addclient_link($name, $image)) {
        carp("Couldn't add link for client $name to image $image");
        return undef;
    }
    if(!_addclient_hosts($name, $ip)) {
        _removeclient_link($name);
        carp("Couldn't add client $name to hosts file");
        return undef;
    }
    return 1;
}

sub _addclient_hosts {
    my ($name, $ip) = @_;
    my $currentip = _client_ip($name);
    return 1 if($ip eq $currentip); 
    
    my ($shortname, @other) = split(/\./,$name);
    open(OUT,">>/etc/hosts") or (carp($!), return undef);
    print OUT "$ip $name";
    if($shortname ne $name) {
        print OUT " $shortname";
    }
    print OUT "\n";
    close(OUT) or (carp($!), return undef);
    return _sync_hosts();
}

sub _addclient_link {
    my ($name, $image) = @_;
    my $currentimage = _client_image($name);
    return 1 if ($image eq $currentimage);

    my $clientlink = $jconfig->get('imager','scripts_dir') . "/main-install/$name.sh";
    return symlink "$image.master", $clientlink;
}

sub removeclient {
    my ($name) = @_;
    return _removeclient_link($name) and _removeclient_hosts($name);
}

#########################################
#
#  TODO:
#  _removeclients_host should have locking eventually
#
#########################################

sub _removeclient_hosts {
    my ($name) = @_;
    open(IN,"</etc/hosts") or (carp($!), return 0);
    my @lines = <IN>;
    close(IN);
    open(OUT,">/etc/hosts") or (carp($!), return 0);
    foreach my $line (@lines) {
        if($line =~ /\b$name\b/) {
            next;
        } else {
            print OUT $line;
        }
    }
    close(OUT);

    return _sync_hosts();
}

sub _removeclient_link {
    my ($name) = @_;
    my $clientlink = $jconfig->get('imager','scripts_dir') . "/main-install/$name.sh";
    
    if(-l $clientlink) {
        return unlink $clientlink;
    }
    return 1;
}

############################################################
#
#  _sync_hosts - syncs the global hosts file with the rsyncable one
#
############################################################

sub _sync_hosts {
    my $rsynchosts = $jconfig->get('imager','scripts_dir') . "/hosts";
    copy("/etc/hosts",$rsynchosts) or (carp($!), return undef);
    return 1;
}



1;
