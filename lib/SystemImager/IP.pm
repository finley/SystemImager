package SystemImager::IP;

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
use Net::Netmask;
use SystemImager::Config;
use base qw(Exporter);
use vars qw($VERSION @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw(iplist);
%EXPORT_TAGS = ('all' => [@EXPORT_OK]);


sub iplist {
    my ($startip, $endip) = @_;
    if($endip =~ /\./) {
        return _iplist_start_end($startip, $endip);
    } else {
        return _iplist_start_num($startip, $endip);
    }
}

sub _valid_ip {
    my $ip = shift;
    foreach my $octet (split(/\./,$ip)) {
        unless($octet >= 0 and $octect <= 255) {
            return undef;
        }
    }
    return 1;
}

sub _iplist_start_num {
    my ($startip, $num) = @_;
    my @ips;
    my $block = new Net::Netmask($startip, '255.255.255.0');
    my $index = _find_index($startip, $block);

    # This is a hack.  It is here because we want to increment before
    # pushing to ensure our rollover takes place at the right point.  So
    # before we start, we decrement 1.
    
    $index--; 
    while($num) {
        $index++;
        $num--;
        push @ips, $block->nth($index);
        if($block->nth($index) eq $block->nth(-2)) {
            $block = new Net::Netmask($block->next, '255.255.255.0');
            $index = -1;
        }
    }
    return @ips;
}

sub _find_index {
    my ($startip, $block) = @_;
    my $count = 0;
    while($block->nth($count) ne $startip) {
        $count++;
    }
    return $count;
}

sub _iplist_start_end {
    my ($startip, $endip) = @_;
    my @ips;
    my @blocks = range2cidrlist($startip, $endip);
    for my $block (@blocks) {
        my @temps = $block->enumerate();
        foreach my $temp (@temps) {
            if($temp !~ /\.255$/) {
                push @ips, $temp;
            }
        }
    }
    return @ips;
}

1;
