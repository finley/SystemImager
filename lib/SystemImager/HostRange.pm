#
#   Copyright (C) 2007 Andrea Righi <a.righi@cineca.it>
#
#   $Id$
#    vi: set filetype=perl:
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

package SystemImager::HostRange;

use strict;
use Socket;
use XML::Simple;

# Maximum number of concurrent sessions (public).
our $concurrents = 32;

# Number of active concurrent sessions.
my $workers = 0;

# Cluster topology.
our $database = "/etc/systemimager/cluster.xml";

# Usage:
# thread_pool_spawn($prog, $opts, $cmd, @hosts);
# Description:
#       Spawn the pool of sessions to the target hosts.
sub thread_pool_spawn
{
	my ($prog, $opts, $cmd, @hosts) = @_;

	foreach my $host (@hosts) {
		do_cmd($prog, $opts, $cmd, $host);
		$workers++;
		if ($workers >= $concurrents) {
			wait;
			$workers--;
		}
	}

	# Wait for children to finish.
	while ($workers) {
		last if (wait == -1);
		$workers--;
	}
	$workers = 0;
}

# Usage:
# do_cmd($prog, $opts, $host, $cmd);
# Description:
#       Run a command on a single remote host.
sub do_cmd
{
	my ($prog, $opts, $cmd, $host) = @_;

	my $pid;
	if ($pid = fork) {
		return;
	} elsif (defined $pid) {
		# print "$prog $opts $host $cmd\n";
		my @out = `exec 2>&1 $prog $opts $host $cmd`;
		if ($?) {
			select(STDERR);
		}
		$| = 1;
		foreach (@out) {
			print $host . ': ' . $_;
		}
		exit(0);
	} else {
		print STDERR "$host: couldn't fork session!\n";
	}
}

# Usage:
# my @hosts = expand_gruops($host_groups_string)
# Description:
#       Expand host groups and host ranges into the list of hostnames identified
#       by the $host_groups_string and the group definitions in
#       /etc/systemimager/cluster.xml.
sub expand_groups
{
	my $grouplist = shift;

	# Parse XML database.
	my $xml = XMLin($database, ForceArray => 1);

	my $global_image = $xml->{'base_image'}[0];
	unless (defined($global_image)) {
		die("ERROR: global base image undefined in cluster.xml!\n");
	}

        # Resolve the list of groups or nodenames.
	my @ret = ();
	foreach my $in (split(/,| |\n/, $grouplist)) {
		my $found = 0;
	        foreach my $group (@{$xml->{'group'}}) {
			if (($group->{'name'}[0] eq $in) or ($in eq $global_image)) {
				$found = 1;
				push(@ret, expand_range_list(join(' ', @{$group->{'node'}})));
			}
		}
		unless ($found) {
			# Group not found, probably it's a single host or a host
			# range.
			push(@ret, expand_range_list(join(' ', $in)));
		}
	}
	return sort_unique(@ret);
}

# Usage:
# my @hosts = expand_range_list($range_string)
# Description:
#       Expand host ranges identified by the $range_string into the
#       @hosts list.
sub expand_range_list {
	my $clients = shift;
	my @hosts = split(/,| |\n/, $clients);

	# Expand host or IP ranges.
	my %expanded_hosts = ();
	foreach my $range (@hosts) {
	        expand_range(\%expanded_hosts, $range);
	}

	# Convert into a list.
	return sort(keys(%expanded_hosts));
}

# Usage:
# expand_range(\%expanded_hosts, $range_string)
# Description:
#       Expand host ranges identified by the $range_string into the
#       %expaned_hosts hash.
sub expand_range {
	my ($expanded_hosts, $node) = @_;
	my ($start_root, $start_domain, $start_num, $end_root, $end_domain, $end_num);
	if ($node =~ /(?<!\\)-/) {
		my ($front, $end) = split(/(?<!\\)-/, $node, 2);

		# IP range.
		if ((my $ip_start = ip2int($front)) && (my $ip_end = ip2int($end))) {
			for (my $i = $ip_start; $i <= $ip_end; $i++) {
				$$expanded_hosts{int2ip($i)}++;
			}
			return;
		}
		# Hostname range.
		($start_root, $start_num, $start_domain) = ($front =~ /^(.*?)(\d+)(\..+)?$/);
		($end_root, $end_num, $end_domain) = ($end =~ /^(.*?)(\d+)(\..+)?$/);
		if (!defined($start_domain)) {
			$start_domain = '';
		}
		if (!defined($end_domain)) {
			$end_domain = '';
		}


		if (!defined($start_num) || !defined($end_num)
			|| ($start_num > $end_num)
			|| ($end_root ne $start_root)
			|| ($end_domain ne $start_domain)) {
				#Strip escape characters
				$node =~ s/\\-/-/g;

				$$expanded_hosts{$node}++;
			return;
		}
	} else {
		# Single host.

		#Strip escape characters
		$node =~ s/\\-/-/g;

		$$expanded_hosts{$node}++;
		return;
	}

	#Strip escape characters
	$start_root =~ s/\\-/-/g;

	foreach my $suffix ($start_num .. $end_num) {
		my $zeros = (length($start_num) - length($suffix));
		my $prefix = '0' x $zeros;
		$$expanded_hosts{"$start_root$prefix$suffix$start_domain"}++;
	}
}

# Usage:
# my @sorted_list = sort_ip(@ip_list)
# Description:
#       Sort a list of IPv4 addresses.
sub sort_ip
{
	return sort {
		my @a = ($a =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/);
		my @b = ($b =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/);
		$a[0] <=> $b[0] ||
		$a[1] <=> $b[1] ||
		$a[2] <=> $b[2] ||
		$a[3] <=> $b[3]
	} @_;
}

# Usage:
# my @sorted_unique_list = sort_unique(@redundand_unsorted_list);
# Description:
#       Sort and extract unique elements from an array.
sub sort_unique
{
	my @in = @_;
	my %saw;
	@saw{@_} = ();
	return sort keys %saw;
}

# Usage:
# my $ip = hostname2ip($hostname);
# Description:
#       Convert hostname into the IPv4 address.
sub hostname2ip
{
       my $ip = (gethostbyname(shift))[4] || "";
       return $ip ? inet_ntoa( $ip ) : "";
}

# Usage:
# my $valid = valid_ip_quad($ip_address);
# if (valid_ip_quad($ip_address)) { then; }
# Description:
#       Check if $ip_address is a valid IPv4 address.
sub valid_ip_quad {
        my @bytes = split(/\./, $_[0]);

        return 0 unless @bytes == 4 && ! grep {!(/\d+$/ && ($_ <= 255) && ($_ >= 0))} @bytes;
	return 1;
}

# Usage:
# my $int = ip2int($ip)
# Description:
#       Convert an IPv4 address into the equivalent integer value.
sub ip2int {
	my @bytes = split(/\./, $_[0]);

	return 0 unless @bytes == 4 && ! grep {!(/\d+$/ && ($_ <= 255) && ($_ >= 0))} @bytes;

	return unpack("N", pack("C4", @bytes));
}

# Usage:
# my $ip = int2ip($int)
# Description:
#       Convert an integer into the the equivalent IPv4 address.
sub int2ip {
	return join('.', unpack('C4', pack("N", $_[0])));
}

# Usage:
# my $ip_hex = ip2hex($ip_address);
# Description:
#       Convert an IPv4 address into the the equivalent hex value.
sub ip2hex {
	my @bytes = split(/\./, $_[0]);

	return 0 unless @bytes == 4 && ! grep {!(/\d+$/ && ($_ <= 255) && ($_ >= 0))} @bytes;

	return sprintf("%02X%02X%02X%02X", @bytes);
}

# Usage:
# my $ip = hex2ip($int)
# Description:
#       Convert a hex value into the the equivalent IPv4 address.
sub hex2ip {
	return join('.', unpack('C4', pack('N', hex("0x" . $_[0]))));
}

1;
