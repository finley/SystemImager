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
use SystemImager::JConfig qw($jconfig);

# Maximum number of concurrent sessions (public).
our $concurrents = 32;

# Number of active concurrent sessions.
my $workers = 0;

# Cluster topology.
our $database = "/etc/systemimager/cluster.xml";

# Evaluate the maximum integer for this architecture.
my $MAXINT = unpack("I", pack("I", -1));

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
# my @hosts = expand_groups($host_groups_string)
# Description:
#       Expand host groups and host ranges into the list of hostnames identified
#       by the $host_groups_string and the group definitions in
#       /etc/systemimager/cluster.xml.
sub expand_groups
{
	my $grouplist = shift;

	# Parse XML database.
	my $xml = XMLin($database, ForceArray => 1);
	return expand_groups_xml($xml, $grouplist);
}

# Usage:
# my @hosts = expand_groups_xml($xml, $host_groups_string)
# Description:
#       Expand host groups and host ranges into the list of hostnames identified
#       by the $host_groups_string and the group definitions in the $xml
#       structure.
sub expand_groups_xml
{
	my $xml = shift;
	my $grouplist = shift;

	my $global_name = $xml->{'name'}[0];
	unless (defined($global_name)) {
		die("ERROR: no global name defined in cluster.xml!\n");
	}

        # Resolve the list of groups or nodenames.
	my @ret = ();
	foreach my $in (expand_range_list($grouplist)) {
		my $found = 0;
	        foreach my $group (@{$xml->{'group'}}) {
			if (($group->{'name'}[0] eq $in) or ($in eq $global_name)) {
				$found = 1;
				if ($group->{'node'}) {
					push(@ret, expand_range_list(join(' ', @{$group->{'node'}})));
				}
				foreach (@{$group->{'dynamic_node'}}) {
					unless (open(IN, "$_|")) {
						next;
					}
					chomp(my @dyn_list = <IN>);
					close(IN);
					push(@ret, expand_range_list(join(' ', @dyn_list)));
				}
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
# my @sorted_list = sort_group(@group_list);
# Description:
#       Sort a list of host group entries. Try to sort groups by priority, if
#       undefined or if two groups have the same value of priority use the
#       group name (alphabetical order).
sub sort_group
{
	return sort {
		($a->{'priority'}[0] or $MAXINT) <=> ($b->{'priority'}[0] or $MAXINT) ||
		lc($a->{'name'}[0]) cmp lc($b->{'name'}[0])
	} @_;
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
# my $ret = add_hosts_entries($ip_range, $domain_name, @all_hosts);
# Description:
#       Add host definitions in /etc/hosts.
sub add_hosts_entries {
    my ($ip_range, $domain_name, @all_hosts) = @_;

    $domain_name = lc $domain_name;

    my $autoinstall_script_dir = $jconfig->get('imager','scripts_dir');
    unless ($autoinstall_script_dir) {
        die "FATAL: parameter imager.scripts_dir is not defined in ".$jconfig->fileName()."\n";
    }

    my @all_ips = expand_range_list($ip_range);
    unless ($#all_ips == $#all_hosts) {
        print "error: different number of IPs and hostnames!\n";
        print 'IPs = ' . ($#all_ips + 1) . "\n" . 'Hosts = ' . ($#all_hosts + 1) . "\n";
        return -1;
    }

    ### BEGIN test to be sure /etc/hosts exists and create if it doesn't ###
    my $file = "/etc/hosts";
    if ( ! -f "$file" ) {
        open(ETC_HOSTS, ">> $file") or die "Couldn't open $file for writing: $!\n";
        print ETC_HOSTS "127.0.0.1  localhost\n";
        close(ETC_HOSTS);
        system('chmod 644 /etc/hosts');
    }
    ### END test to be sure /etc/hosts exists and create if it doesn't ###

    ### BEGIN read in /etc/hosts and create a hash of lines by ip address and a hash of lines by number
    my %etc_hosts_lines_by_ip = ();
    my %etc_hosts_lines_by_number = ();
    my $line_number = "1";

    open(ETC_HOSTS, "< /etc/hosts") or die "Couldn't open /etc/hosts for reading: $!\n";
    while (<ETC_HOSTS>) {
        chomp;
        my @fields = split;
        my $ip_quad = $fields[0];
        my $line = $_;
        if ($ip_quad) {
            $etc_hosts_lines_by_ip{$ip_quad} = $line;
        }
        $etc_hosts_lines_by_number{$line_number} = $line;
        $line_number = $line_number + 1;
    }
    close(ETC_HOSTS);
    ### END read in /etc/hosts and create a hash of lines by ip address and a hash of lines by number

    ### create a hash of new hostnames by ip address
    @all_hosts = sort(@all_hosts);
    my %new_hostnames_by_ip;
    my $i = 0;
    foreach (sort_ip(@all_ips)) {
        $new_hostnames_by_ip{$_} = $all_hosts[$i++];
    }
    ### create a hash of new hostnames by ip address

    ### munge new ips and hostname info into %etc_hosts_lines_by_ip
    my @new_ip_addresses = sort (keys %new_hostnames_by_ip);
    foreach my $new_ip_address (@new_ip_addresses) {
        if ($domain_name) {
            $etc_hosts_lines_by_ip{$new_ip_address} =
                "$new_ip_address\t" .
                "$new_hostnames_by_ip{$new_ip_address}.$domain_name\t".
                "$new_hostnames_by_ip{$new_ip_address}";
        } else {
            $etc_hosts_lines_by_ip{$new_ip_address} =
                "$new_ip_address\t" .
                "$new_hostnames_by_ip{$new_ip_address}";
        }
    }
    ### munge new ips and hostname info into %etc_hosts_lines_by_ip

    ### BEGIN open temporary /etc/hosts for writing
    my $temp_file = "/tmp/.hosts.systemimager";
    open(NEW_ETC_HOSTS, "> $temp_file") or die "Couldn't open $temp_file for writing: $!\n";
    ### END open temporary /etc/hosts for writing

    ### BEGIN replace entries as necessary in numbered /etc/hosts lines and print numbered lines
    foreach my $line_number ( sort {$a <=> $b} ( keys %etc_hosts_lines_by_number )) {
        $_ = $etc_hosts_lines_by_number{$line_number};
        my @words = split;
        my $ip_quad = $words[0];
        if ($ip_quad) {
            $etc_hosts_lines_by_number{$line_number} = $etc_hosts_lines_by_ip{$ip_quad};
            delete $etc_hosts_lines_by_ip{$ip_quad};
        }
        # print numbered hosts entries
        print NEW_ETC_HOSTS "$etc_hosts_lines_by_number{$line_number}\n";
    }
    ### END replace entries as necessary in numbered /etc/hosts lines and print numbered lines

    ### create hash of entries by decimal ip (for sorting purposes)
    my %etc_hosts_lines_by_ip_decimal;
    my $ip_decimal;
    foreach my $ip_quad ( keys %etc_hosts_lines_by_ip ) {
        $ip_decimal = ip2int($ip_quad);
        $etc_hosts_lines_by_ip_decimal{$ip_decimal} = $etc_hosts_lines_by_ip{$ip_quad};
    }
    ### create hash of entries by decimal ip (for sorting purposes)

    ### print remaining entries
    foreach my $ip_decimal ( sort( keys %etc_hosts_lines_by_ip_decimal )) {
        print NEW_ETC_HOSTS "$etc_hosts_lines_by_ip_decimal{$ip_decimal}\n";
    }
    ### print remaining entries

    ### close temporary /etc/hosts after writing
    close(NEW_ETC_HOSTS);
    ### close temporary /etc/hosts after writing

    ### move new hosts file in to place
    system('mv', '-f', $temp_file, '/etc/hosts');
    if($? != 0) { die "Couldn't move $temp_file to /etc/hosts!\n", "Is the filesystem that contains /etc/ full?"; }
    ### move new hosts file in to place

    return 0;
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
