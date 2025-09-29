#!/usr/bin/perl -w

#
#    vi:set filetype=perl:
#
#    This file is part of SystemImager.
#
#    SystemImager is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    SystemImager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with SystemImager. If not, see <https://www.gnu.org/licenses/>.
#
#    Copyright (C) 2025 Olivier Lahaye <olivier.lahaye1@free.fr>
#
#    Others who have contributed to this code (in alphabetical order):
#     Grok 3 https://grok.com
#
#    See http://www.iana.org/assignments/bootp-dhcp-parameters for info on
#    custom option numbers.
#

package SystemImager::IpUtils;

use strict;
use IO::Socket::INET;
use IO::Interface::Simple;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(valid_ip valid_fqdn valid_hostname ip_to_int first_usable_ip is_ip_in_network is_ip_in_range get_subnet_ip_range is_range_overlap get_network_interfaces get_local_ip);

# valid_ip: Validate an IPv4 address
# Input: IP address string
# Output: 1 if valid, 0 if invalid
sub valid_ip {
    my ($ip) = @_;
    return 0 unless defined $ip;
    return 1 if $ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ &&
                $1 >= 0 && $1 <= 255 &&
                $2 >= 0 && $2 <= 255 &&
                $3 >= 0 && $3 <= 255 &&
                $4 >= 0 && $4 <= 255;
    return 0;
}

# valid_fqdn: Validate a fully qualified domain name
# Input: FQDN string
# Output: 1 if valid, 0 if invalid
sub valid_fqdn {
    my ($fqdn) = @_;
    return 0 unless defined $fqdn;
    return 1 if $fqdn =~ /^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.?$/ && $fqdn =~ /\./;
    return 0;
}

# valid_hostname: Validate a simple hostname (no domain)
# Input: hostname string
# Output: 1 if valid, 0 if invalid
sub valid_hostname {
    my ($hostname) = @_;
    return 0 unless defined $hostname;
    return 1 if $hostname =~ /^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/ && $hostname !~ /\./;
    return 0;
}

# ip_to_int: Convert IP address to integer
# Input: IP address string
# Output: Integer representation or undef if invalid
sub ip_to_int {
    my ($ip) = @_;
    return undef unless valid_ip($ip);
    my ($a, $b, $c, $d) = split /\./, $ip;
    return ($a << 24) + ($b << 16) + ($c << 8) + $d;
}

# first_usable_ip: Get the first usable IP in a subnet
# Input: Subnet (ip/mask)
# Output: First usable IP address or undef if invalid
sub first_usable_ip {
    my ($subnet) = @_;
    my ($ip, $mask) = split /\//, $subnet;
    return undef unless valid_ip($ip) && $mask >= 0 && $mask <= 32;
    my $ip_int = ip_to_int($ip);
    my $mask_int = (2 ** 32 - 1) << (32 - $mask);
    my $network = $ip_int & $mask_int;
    return join(".", ($network >> 24, ($network >> 16) & 255, ($network >> 8) & 255, $network & 255)) if $mask == 32;
    return join(".", ($network >> 24, ($network >> 16) & 255, ($network >> 8) & 255, ($network & 255) + 1));
}

# is_ip_in_network: Check if IP is in subnet
# Input: IP address, subnet (ip/mask)
# Output: 1 if in network, 0 otherwise
sub is_ip_in_network {
    my ($ip, $subnet) = @_;
    my ($net_ip, $mask) = split /\//, $subnet;
    return 0 unless valid_ip($ip) && valid_ip($net_ip) && $mask >= 0 && $mask <= 32;
    my $ip_int = ip_to_int($ip);
    my $net_int = ip_to_int($net_ip);
    my $mask_int = (2 ** 32 - 1) << (32 - $mask);
    return ($ip_int & $mask_int) == ($net_int & $mask_int);
}

# is_ip_in_range: Check if IP is in range
# Input: IP address, start IP, end IP
# Output: 1 if in range, 0 otherwise
sub is_ip_in_range {
    my ($ip, $start_ip, $end_ip) = @_;
    return 0 unless valid_ip($ip) && valid_ip($start_ip) && valid_ip($end_ip);
    my $ip_int = ip_to_int($ip);
    my $start_int = ip_to_int($start_ip);
    my $end_int = ip_to_int($end_ip);
    return $ip_int >= $start_int && $ip_int <= $end_int;
}

# get_subnet_ip_range: Get IP range for subnet
# Input: Subnet (ip/mask)
# Output: Array of (min_ip, max_ip) or (undef, undef) if invalid
sub get_subnet_ip_range {
    my ($subnet) = @_;
    my ($ip, $mask) = split /\//, $subnet;
    return (undef, undef) unless valid_ip($ip) && $mask >= 0 && $mask <= 32;
    my $ip_int = ip_to_int($ip);
    my $mask_int = (2 ** 32 - 1) << (32 - $mask);
    my $network = $ip_int & $mask_int;
    my $broadcast = $network + (2 ** (32 - $mask) - 1);
    my $min_ip = ($mask == 32) ? $ip : join(".", ($network >> 24, ($network >> 16) & 255, ($network >> 8) & 255, ($network & 255) + 1));
    my $max_ip = ($mask == 32) ? $ip : join(".", ($broadcast >> 24, ($broadcast >> 16) & 255, ($broadcast >> 8) & 255, ($broadcast & 255) - 1));
    return ($min_ip, $max_ip);
}

# is_range_overlap: Check if two IP ranges overlap
# Input: start1, end1, start2, end2
# Output: 1 if overlap, 0 otherwise
sub is_range_overlap {
    my ($start1, $end1, $start2, $end2) = @_;
    return 0 unless valid_ip($start1) && valid_ip($end1) && valid_ip($start2) && valid_ip($end2);
    my $start1_int = ip_to_int($start1);
    my $end1_int = ip_to_int($end1);
    my $start2_int = ip_to_int($start2);
    my $end2_int = ip_to_int($end2);
    return ($start1_int <= $end2_int && $start2_int <= $end1_int);
}

# get_network_interfaces: Get list of network interfaces
# Output: Array of interface names
sub get_network_interfaces {
    my @interfaces;
    for my $if (IO::Interface::Simple->interfaces) {
        push @interfaces, $if->name if $if->is_running && $if->address;
    }
    return @interfaces;
}

# get_local_ip: Get IP address for an interface
# Input: Interface name
# Output: IP address or undef if not found
sub get_local_ip {
    my ($ifname) = @_;
    my $if = IO::Interface::Simple->new($ifname);
    return $if->address if $if && $if->is_running;
    return undef;
}

1;

__END__

=pod

=head1 NAME

SystemImager::IpUtils - IP and network utility functions for SystemImager

=head1 SYNOPSIS

use SystemImager::IpUtils qw(valid_ip valid_fqdn ip_to_int first_usable_ip is_ip_in_network is_ip_in_range get_subnet_ip_range is_range_overlap get_network_interfaces get_local_ip);

=head1 DESCRIPTION

This module provides utility functions for IP address and network manipulation
used by SystemImager tools.

=head1 FUNCTIONS

=over 4

=item B<valid_ip>($ip)

Returns 1 if the IP address is valid, 0 otherwise.

=item B<valid_fqdn>($fqdn)

Returns 1 if the FQDN is valid, 0 otherwise.

=item B<ip_to_int>($ip)

Converts an IP address to its integer representation.

=item B<first_usable_ip>($subnet)

Returns the first usable IP address in a subnet (ip/mask).

=item B<is_ip_in_network>($ip, $subnet)

Returns 1 if the IP is in the subnet, 0 otherwise.

=item B<is_ip_in_range>($ip, $start_ip, $end_ip)

Returns 1 if the IP is in the range, 0 otherwise.

=item B<get_subnet_ip_range>($subnet)

Returns the minimum and maximum IP addresses for a subnet.

=item B<is_range_overlap>($start1, $end1, $start2, $end2)

Returns 1 if the two IP ranges overlap, 0 otherwise.

=item B<get_network_interfaces>()

Returns a list of running network interface names.

=item B<get_local_ip>($interface)

Returns the IP address of the specified interface.

=back

=head1 AUTHOR

Olivier Lahaye <olivier.lahaye1@free.fr>

=head1 COPYRIGHT

Copyright (C) 2025 Olivier Lahaye
Licensed under the GNU General Public License v2 or later.

=cut
