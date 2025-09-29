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

package SystemImager::KeaConfUtils;

use strict;
use JSON::PP;
use File::Copy;
use POSIX qw(strftime);
use Text::Table;
use SystemImager::IpUtils qw(valid_ip ip_to_int first_usable_ip is_ip_in_network is_ip_in_range get_subnet_ip_range is_range_overlap get_network_interfaces get_local_ip);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(load_kea_config init_kea_config write_kea_config subnet_exists client_exists add_subnet del_subnet add_pool del_pool add_client del_client set_option set_client_option list_subnets list_pools list_clients);
our $debug = 0; # Global debug variable

# Option code to name mapping
my %option_code_to_name = (
    6   => "domain-name-servers",
    15  => "domain-name",
    119 => "domain-search",
    7   => "log-servers",
    66  => "next-server",
    200 => "image-servers",
    201 => "log-server-port",
    202 => "ssh-download-url",
    203 => "flamethrower-port-base",
    204 => "tmpfs-staging",
);

# load_kea_config: Load and parse Kea configuration file
# Input: filename, debug level
# Output: (config hashref, changelog arrayref) or (undef, undef) on error
sub load_kea_config {
    my ($filename, $debug) = @_;
    my @changelog;
    my $config;

    if (-f $filename) {
        print "Loading configuration from $filename\n" if $debug >= 1;
        open my $fh, '<', $filename or do {
            print "Error: Cannot open $filename: $!\n" if $debug >= 1;
            return (undef, undef);
        };
        my $content = do { local $/; <$fh> };
        close $fh;

        # Extract changelog
        while ($content =~ m|^// (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} .+)$|mg) {
            push @changelog, "// $1";
        }

        # Remove comments and normalize JSON
        my $json_content = $content;
        $json_content =~ s|//.*$||mg;  # Remove single-line comments
        $json_content =~ s|/\*.*?\*/||sg;  # Remove multi-line comments
        $json_content =~ s/,\s*([\]\}])/$1/g;  # Remove trailing commas before ] or }
        $json_content =~ s/\s+$//;  # Remove trailing whitespace

        print "Raw config content (after comment removal):\n$json_content\n" if $debug >= 3;

        eval {
            $config = decode_json($json_content);
        };
        if ($@) {
            print "Error parsing JSON in $filename: $@\n" if $debug >= 1;
            print "Problematic content (first 500 chars):\n", substr($json_content, 0, 500), "...\n" if $debug >= 3;
            return (undef, undef);
        }

        # Convert code-based options to name-based
        print "Calling _convert_option_codes\n" if $debug >= 2;
        _convert_option_codes($config);
        print "Loaded config structure:\n", encode_json($config), "\n" if $debug >= 3;
    }

    return ($config, \@changelog);
}

# init_kea_config: Initialize a new Kea configuration
# Output: config hashref
sub init_kea_config {
    my $config = {
        "Dhcp4" => {
            "interfaces-config" => {
                "interfaces" => ["*"],
            },
            "option-def" => [
                { "name" => "image-servers", "code" => 200, "type" => "string"  },
                { "name" => "log-server-port", "code" => 201, "type" => "uint16" },
                { "name" => "ssh-download-url", "code" => 202, "type" => "string" },
                { "name" => "flamethrower-port-base", "code" => 203, "type" => "uint16" },
                { "name" => "tmpfs-staging", "code" => 204, "type" => "string" },
            ],
            "client-classes" => [
                {
                    "name" => "IA32_UEFI",
                    "test" => "option[93].hex == 0x0006",
                    "option-data" => [
                        { "name" => "boot-file-name", "code" => 67, "space" => "dhcp4", "data" => "bootia32.efi" }
                    ]
                },
                {
                    "name" => "X64_UEFI",
                    "test" => "option[93].hex == 0x0007",
                    "option-data" => [
                        { "name" => "boot-file-name", "code" => 67, "space" => "dhcp4", "data" => "grubx64.efi" }
                    ]
                },
                {
                    "name" => "ARM64_UEFI",
                    "test" => "option[93].hex == 0x000B",
                    "option-data" => [
                        { "name" => "boot-file-name", "code" => 67, "space" => "dhcp4", "data" => "grubaa64.efi" }
                    ]
                },
                {
                    "name" => "PXE_LEGACY",
                    "test" => "option[93].hex == 0x0000",
                    "option-data" => [
                        { "name" => "boot-file-name", "code" => 67, "space" => "dhcp4", "data" => "pxelinux.0" }
                    ]
                },
            ],
            "subnet4" => [],
            "reservations" => [],
            "option-data" => [],
        }
    };

    # Initialize from /etc/resolv.conf
    if (-r "/etc/resolv.conf") {
        open my $fh, '<', "/etc/resolv.conf" or return $config;
        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ /^nameserver\s+(\S+)/ && valid_ip($1)) {
                push @{$config->{"Dhcp4"}->{"option-data"}}, {
                    "name" => "domain-name-servers",
                    "code" => 6,
                    "space" => "dhcp4",
                    "data" => $1
                };
            } elsif ($line =~ /^domain\s+(\S+)/) {
                push @{$config->{"Dhcp4"}->{"option-data"}}, {
                    "name" => "domain-name",
                    "code" => 15,
                    "space" => "dhcp4",
                    "data" => $1
                };
            } elsif ($line =~ /^search\s+(.+)/) {
                push @{$config->{"Dhcp4"}->{"option-data"}}, {
                    "name" => "domain-search",
                    "code" => 119,
                    "space" => "dhcp4",
                    "data" => $1
                };
            }
        }
        close $fh;
    }

    return $config;
}

# subnet_exists: Function to check if a subnet exists
# Input: config href, subnet (string: IPv4/MASK)
# Output: 1 on success, 0 on failure
sub subnet_exists {
    my ($config, $subnet) = @_;
    return 0 unless ref($config) eq 'HASH' && exists $config->{Dhcp4}{subnet4};
    for my $s (@{$config->{Dhcp4}{subnet4}}) {
        return 1 if $s->{subnet} eq $subnet;
    }
    return 0;
}

# client_exists: Function to check if a client exists
# Input: config href, client (string: FQDN|MAC|IPv4)
# Output: 1 on success, 0 on failure
sub client_exists {
    my ($config, $client) = @_;
    return 0 unless ref($config) eq 'HASH' && exists $config->{Dhcp4}{subnet4};
    for my $s (@{$config->{Dhcp4}{subnet4}}) {
        next unless exists $s->{reservations};
        for my $r (@{$s->{reservations}}) {
            return 1 if ($r->{hostname} && $r->{hostname} eq $client) ||
                        ($r->{"ip-address"} && $r->{"ip-address"} eq $client) ||
                        ($r->{"hw-address"} && $r->{"hw-address"} eq $client);
        }
    }
    return 0;
}

# write_kea_config: Write Kea configuration to file
# Input: filename, config hashref, changelog arrayref, debug level
# Output: 1 on success, 0 on failure
sub write_kea_config {
    my ($filename, $config, $changelog, $debug) = @_;

    # Update interfaces
    my @interfaces;
    for my $if (get_network_interfaces()) {
        my $ip = get_local_ip($if);
        next unless $ip;
        for my $subnet (@{$config->{"Dhcp4"}->{"subnet4"}}) {
            if (is_ip_in_network($ip, $subnet->{"subnet"})) {
                push @interfaces, $if;
                last;
            }
        }
    }
    $config->{"Dhcp4"}->{"interfaces-config"}->{"interfaces"} = @interfaces ? \@interfaces : ["*"];

    # Backup existing file
    if (-f $filename) {
        print "Creating backup of $filename to $filename.bak\n" if $debug >= 1;
        copy($filename, "$filename.bak") or do {
            print "Error: Failed to create backup of $filename: $!\n" if $debug >= 1;
            return 0;
        };
    }

    # Generate JSON output
    my $json = JSON::PP->new->pretty->canonical;
    my $content = $json->encode($config);

    # Add header and changelog
    my $header = "//\n// This is a Kea DHCPv4 server configuration file generated by si_mkdhcpserver on " . strftime("%Y-%m-%d %H:%M:%S", localtime) . "\n" .
                 "// You can tune it, but it is not guaranteed that your comments are kept upon next use of si_mkdhcpserver\n" .
                 "//\n// ------------ Changelog -------------\n" . join("\n", @$changelog) . "\n\n";
    $content = $header . $content;

    print "Writing config to $filename:\n$content\n" if $debug >= 3;

    # Write to file
    open my $fh, '>', $filename or do {
        print "Error: Failed to open $filename for writing: $!\n" if $debug >= 1;
        copy("$filename.bak", $filename) if -f "$filename.bak";
        return 0;
    };
    print $fh $content;
    close $fh;

    return 1;
}

# add_subnet: Add a subnet to the configuration
# Input: config hashref, subnet (ip/mask)
# Output: (1, message) on success, (0, error message) on failure
sub add_subnet {
    my ($config, $subnet) = @_;
    my ($ip, $mask) = split /\//, $subnet;
    return (0, "Invalid subnet format: $subnet") unless valid_ip($ip) && $mask >= 0 && $mask <= 32;

    # Check for duplicate subnet
    for my $s (@{$config->{"Dhcp4"}->{"subnet4"}}) {
        return (0, "Subnet $subnet already exists") if $s->{"subnet"} eq $subnet;
    }

    # Generate unique subnet ID
    my $max_id = 0;
    for my $s (@{$config->{"Dhcp4"}->{"subnet4"}}) {
        $max_id = $s->{"id"} if $s->{"id"} && $s->{"id"} > $max_id;
    }
    my $new_id = $max_id + 1;

    # Check if subnet is visible from local interfaces
    my $visible = 0;
    for my $if (get_network_interfaces()) {
        my $ip = get_local_ip($if);
        if ($ip && is_ip_in_network($ip, $subnet)) {
            $visible = 1;
            last;
        }
    }
    print "Warning: Subnet $subnet not visible from any local interface\n" unless $visible;

    push @{$config->{"Dhcp4"}->{"subnet4"}}, {
        "id" => $new_id,
        "subnet" => $subnet,
        "pools" => [],
        "reservations" => [],
        "option-data" => [],
    };

    return (1, "Added subnet $subnet");
}

# del_subnet: Delete a subnet from the configuration
# Input: config hashref, subnet (ip/mask), force flag 
# Output: (1, message) on success, (0, error message) on failure
sub del_subnet {
    my ($config, $subnet, $force) = @_;
    my @new_subnets;
    my $found = 0;  
    my @reservations;
                        
    for my $s (@{$config->{"Dhcp4"}{"subnet4"}}) {
        if ($s->{"subnet"} eq $subnet) {
            $found = 1;
            # Collecte sécurisée des réservations : vérifie existence + type ARRAY + non vide
            if (my $res = $s->{"reservations"}) {
                if (ref($res) eq 'ARRAY' && @$res) {
                    push @reservations, @$res;
                }
            }
            next;
        }   
        push @new_subnets, $s;
    }

    return (0, "Subnet $subnet not found") unless $found;
    return (0, "Cannot delete subnet $subnet: contains reservations: " . join(", ", map { $_->{"hostname"} || $_->{"ip-address"} } @reservations))
        if @reservations && !$force;
            
    $config->{"Dhcp4"}->{"subnet4"} = \@new_subnets;
    my $msg = "Deleted subnet $subnet" . (@reservations ? " and reservations: " . join(", ", map { $_->{"hostname"} || $_->{"ip-address"} } @reservations) : "");
    return (1, $msg);
}

# add_pool: Add a pool to a subnet
# Input: config hashref, start IP, end IP
# Output: (1, message) on success, (0, error message) on failure
sub add_pool {
    my ($config, $start_ip, $end_ip) = @_;
    return (0, "Configuration is not a valid hash") unless ref($config) eq 'HASH' && exists $config->{Dhcp4}{subnet4};
    return (0, "Start IP must be less than or equal to end IP") if ip_to_int($start_ip) > ip_to_int($end_ip);

    # Find subnet containing start_ip
    my $subnet_ref;
    my $subnet_str;
    for my $s (@{$config->{Dhcp4}{subnet4}}) {
        if (is_ip_in_network($start_ip, $s->{subnet})) {
            $subnet_ref = $s;
            $subnet_str = $s->{subnet};
            last;
        }
    }
    return (0, "No subnet found containing IP $start_ip" . ($SystemImager::KeaConfUtils::debug >= 1 ? "\nAvailable subnets: " . list_subnets($config, 0, 1) : ""))
        unless $subnet_ref;

    # Check if end_ip is in the same subnet
    return (0, "End IP $end_ip is not in subnet $subnet_str")
        unless is_ip_in_network($end_ip, $subnet_str);

    # Check for reservations in pool
    for my $r (@{$subnet_ref->{reservations}}) {
        return (0, "Pool $start_ip - $end_ip conflicts with reservation $r->{'ip-address'}")
            if is_ip_in_range($r->{"ip-address"}, $start_ip, $end_ip);
    }

    # Check for overlapping pools and merge if adjacent
    my @new_pools;
    my $merged = 0;
    my $new_pool = "$start_ip - $end_ip";
    for my $p (@{$subnet_ref->{pools}}) {
        my ($p_start, $p_end) = split / - /, $p->{pool};
        if (is_range_overlap($start_ip, $end_ip, $p_start, $p_end)) {
            return (0, "Pool $start_ip - $end_ip overlaps with existing pool $p_start - $p_end in subnet $subnet_str");
        }
        if ((ip_to_int($end_ip) + 1 == ip_to_int($p_start)) || (ip_to_int($p_end) + 1 == ip_to_int($start_ip))) {
            $new_pool = (ip_to_int($start_ip) < ip_to_int($p_start)) ?
                "$start_ip - $p_end" : "$p_start - $end_ip";
            $merged = 1;
            next;
        }
        push @new_pools, $p;
    }
    push @new_pools, { pool => $new_pool };

    $subnet_ref->{pools} = \@new_pools;
    my $msg = $merged ? "Merged pool $start_ip - $end_ip into $new_pool in subnet $subnet_str" :
                        "Added pool $start_ip - $end_ip to subnet $subnet_str";
    return (1, $msg);
}

# del_pool: Delete a pool from a subnet
# Input: config hashref, start IP, end IP
# Output: (1, message) on success, (0, error message) on failure
sub del_pool {
    my ($config, $start_ip, $end_ip) = @_;
    return (0, "Configuration is not a valid hash") unless ref($config) eq 'HASH' && exists $config->{Dhcp4}{subnet4};
    return (0, "Invalid IP addresses") unless valid_ip($start_ip) && valid_ip($end_ip);
    return (0, "Start IP must be less than or equal to end IP") if ip_to_int($start_ip) > ip_to_int($end_ip);

    # Find subnet containing start_ip
    my $subnet_ref;
    my $subnet_str;
    for my $s (@{$config->{Dhcp4}{subnet4}}) {
        if (is_ip_in_network($start_ip, $s->{subnet})) {
            $subnet_ref = $s;
            $subnet_str = $s->{subnet};
            last;
        }
    }
    return (0, "No subnet found containing IP $start_ip" . ($SystemImager::KeaConfUtils::debug >= 1 ? "\nAvailable subnets: " . list_subnets($config, 0, 1) : ""))
        unless $subnet_ref;

    # Check if end_ip is in the same subnet
    return (0, "End IP $end_ip is not in subnet $subnet_str")
        unless is_ip_in_network($end_ip, $subnet_str);

    # Find and delete the pool
    my @new_pools;
    my $found = 0;
    for my $p (@{$subnet_ref->{pools}}) {
        if ($p->{pool} eq "$start_ip - $end_ip") {
            $found = 1;
            next;
        }
        push @new_pools, $p;
    }
    return (0, "Pool $start_ip - $end_ip not found in subnet $subnet_str") unless $found;

    $subnet_ref->{pools} = \@new_pools;
    return (1, "Deleted pool $start_ip - $end_ip from subnet $subnet_str");
}

# add_client: Add a client reservation
# Input: config hashref, name, MAC address, IP address, global flag
# Output: (1, message) on success, (0, error message) on failure
sub add_client {
    my ($config, $name, $mac, $ip, $global) = @_;

    my $subnet_ref;
    unless ($global) {
        for my $s (@{$config->{"Dhcp4"}->{"subnet4"}}) {
            if (is_ip_in_network($ip, $s->{"subnet"})) {
                $subnet_ref = $s;
                last;
            }
        }
        return (0, "No subnet found for IP $ip. Use --global to add globally") unless $subnet_ref;
    }

    my $reservations = $global ? $config->{"Dhcp4"}->{"reservations"} : $subnet_ref->{"reservations"};
    for my $r (@$reservations) {
        return (0, "Reservation for $ip, $mac, or $name already exists")
            if $r->{"ip-address"} eq $ip || $r->{"hw-address"} eq $mac || $r->{"hostname"} eq $name;
    }

    push @$reservations, {
        "hostname" => $name,
        "hw-address" => $mac,
        "ip-address" => $ip,
        "option-data" => [],
    };

    my $msg = $global ? "Added global client reservation $name ($mac, $ip)" :
                       "Added client reservation $name ($mac, $ip) to subnet $subnet_ref->{subnet}";
    return (1, $msg);
}

# del_client: Delete a client reservation
# Input: config hashref, identifier (name, MAC, or IP)
# Output: (1, message) on success, (0, error message) on failure
sub del_client {
    my ($config, $identifier) = @_;
    my $found = 0;
    my $msg = "";

    # Process global reservations
    my @new_global;
    for my $r (@{$config->{"Dhcp4"}->{"reservations"}}) {
        if ($identifier eq "*" || $r->{"hostname"} eq $identifier || $r->{"hw-address"} eq $identifier || $r->{"ip-address"} eq $identifier) {
            $found++;
            $msg .= "Deleted global client reservation $r->{hostname} ($r->{'hw-address'}, $r->{'ip-address'}) ";
            next;
        }
        push @new_global, $r;
    }
    $config->{"Dhcp4"}->{"reservations"} = \@new_global;

    # Process subnet reservations
    for my $s (@{$config->{"Dhcp4"}->{"subnet4"}}) {
        my @new_reservations;
        for my $r (@{$s->{"reservations"}}) {
            if ($identifier eq "*" || $r->{"hostname"} eq $identifier || $r->{"hw-address"} eq $identifier || $r->{"ip-address"} eq $identifier) {
                $found++;
                $msg .= "Deleted client reservation $r->{hostname} ($r->{'hw-address'}, $r->{'ip-address'}) from subnet $s->{subnet} ";
                next;
            }
            push @new_reservations, $r;
        }
        $s->{"reservations"} = \@new_reservations;
    }

    return (0, "No client found matching $identifier") unless $found;
    return (1, $msg);
}

# set_option: Set a DHCP option
# Input: config hashref, option name, value, optional subnet
# Output: (1, message) on success, (0, error message) on failure
sub set_option {
    my ($config, $option_name, $value, $subnet) = @_;
    my $option_data;

    if ($subnet) {
        for my $s (@{$config->{"Dhcp4"}->{"subnet4"}}) {
            if ($s->{"subnet"} eq $subnet) {
                $option_data = $s->{"option-data"};
                last;
            }
        }
        return (0, "Subnet $subnet not found") unless $option_data;
    } else {
        $option_data = $config->{"Dhcp4"}->{"option-data"};
    }

    my $found = 0;
    for my $opt (@$option_data) {
        if ($opt->{"name"} eq $option_name) {
            $opt->{"data"} = $value;
            $found = 1;
            last;
        }
    }
    unless ($found) {
        push @$option_data, {
            "name" => $option_name,
            "code" => _name_to_code($option_name),
            "space" => "dhcp4",
            "data" => $value,
        };
    }

    my $msg = $found ? "Updated $option_name to $value" : "Added $option_name as $value";
    $msg .= " in subnet $subnet" if $subnet;
    return (1, $msg);
}

# set_client_option: Set a client-specific option
# Input: config hashref, client identifier, option name, value
# Output: (1, message) on success, (0, error message) on failure
sub set_client_option {
    my ($config, $identifier, $option_name, $value) = @_;
    my $found = 0;

    # Check global reservations
    for my $r (@{$config->{"Dhcp4"}->{"reservations"}}) {
        if ($r->{"hostname"} eq $identifier || $r->{"hw-address"} eq $identifier || $r->{"ip-address"} eq $identifier) {
            my $option_data = $r->{"option-data"};
            for my $opt (@$option_data) {
                if ($opt->{"name"} eq $option_name) {
                    $opt->{"data"} = $value;
                    $found = 1;
                    last;
                }
            }
            unless ($found) {
                push @$option_data, {
                    "name" => $option_name,
                    "code" => _name_to_code($option_name),
                    "space" => "dhcp4",
                    "data" => $value,
                };
            }
            return (1, "Set $option_name to $value for client $r->{hostname}");
        }
    }

    # Check subnet reservations
    for my $s (@{$config->{"Dhcp4"}->{"subnet4"}}) {
        for my $r (@{$s->{"reservations"}}) {
            if ($r->{"hostname"} eq $identifier || $r->{"hw-address"} eq $identifier || $r->{"ip-address"} eq $identifier) {
                my $option_data = $r->{"option-data"};
                for my $opt (@$option_data) {
                    if ($opt->{"name"} eq $option_name) {
                        $opt->{"data"} = $value;
                        $found = 1;
                        last;
                    }
                }
                unless ($found) {
                    push @$option_data, {
                        "name" => $option_name,
                        "code" => _name_to_code($option_name),
                        "space" => "dhcp4",
                        "data" => $value,
                    };
                }
                return (1, "Set $option_name to $value for client $r->{hostname} in subnet $s->{subnet}");
            }
        }
    }

    return (0, "Client $identifier not found");
}

# list_subnets: List all subnets
# Input: config hashref, csv flag, quiet flag
# Output: None (prints to stdout)
sub list_subnets {
    my ($config, $csv, $quiet) = @_;
    my @rows;

    for my $s (@{$config->{"Dhcp4"}->{"subnet4"}}) {
        my ($min_ip, $max_ip) = get_subnet_ip_range($s->{"subnet"});
        my $interface = "N/A";
        for my $if (get_network_interfaces()) {
            my $ip = get_local_ip($if);
            if ($ip && is_ip_in_network($ip, $s->{"subnet"})) {
                $interface = $if;
                last;
            }
        }
        push @rows, [$s->{"subnet"}, $s->{"id"}, $interface, $min_ip, $max_ip];
    }

    if (@rows) {
        if ($csv) {
            print join(",", qw(subnet subnet-id net-interface-name ip-min ip-max)), "\n" unless $quiet;
            for my $row (@rows) {
                print join(",", @$row), "\n";
            }
        } else {
			my $tb = Text::Table->new(
                { title => "Subnet", align => "left", sample => "255.255.255.255/32" },
                \" | ",
                { title => "ID", align => "right", sample => "9999" },
                \" | ",
                { title => "Interface", align => "left", sample => "enp0s1" },
                \" | ",
                { title => "Min IP", align => "left", sample => "255.255.255.255" },
                \" | ",
                { title => "Max IP", align => "left", sample => "255.255.255.255" },
                \" | "
            );
            $tb->load(@rows);
            print $tb unless $quiet;
        }
    } else {
        print "No subnet defined\n" unless $csv || $quiet;
    }
}

# list_pools: List all pools
# Input: config hashref, csv flag, quiet flag
# Output: None (prints to stdout)
sub list_pools {
    my ($config, $csv, $quiet) = @_;
    my @rows;

    for my $s (@{$config->{"Dhcp4"}->{"subnet4"}}) {
        my $interface = "N/A";
        for my $if (get_network_interfaces()) {
            my $ip = get_local_ip($if);
            if ($ip && is_ip_in_network($ip, $s->{"subnet"})) {
                $interface = $if;
                last;
            }
        }
        for my $p (@{$s->{"pools"}}) {
            my ($start_ip, $end_ip) = split / - /, $p->{"pool"};
            push @rows, [$s->{"subnet"}, $s->{"id"}, $interface, $start_ip, $end_ip];
        }
    }

    if (@rows) {
        if ($csv) {
            print join(",", qw(subnet subnet-id net-interface-name pool-ip-min pool-ip-max)), "\n" unless $quiet;
            for my $row (@rows) {
                print join(",", @$row), "\n";
            }
        } else {
			my $tb = Text::Table->new(
                { title => "Subnet", align => "left", sample => "255.255.255.255/32" },
                \" | ",
                { title => "ID", align => "right", sample => "9999" },
                \" | ",
                { title => "Interface", align => "left", sample => "enp0s1" },
                \" | ",
                { title => "Pool Min IP", align => "left", sample => "255.255.255.255" },
                \" | ",
                { title => "Pool Max IP", align => "left", sample => "255.255.255.255" },
                \" | "
            );
            $tb->load(@rows);
            print $tb unless $quiet;
        }
    } else {
        print "No pool defined\n" unless $csv || $quiet;
    }
}

# list_clients: List all client reservations
# Input: config hashref, csv flag, quiet flag
# Output: None (prints to stdout)
sub list_clients {
    my ($config, $csv, $quiet) = @_;
    my @rows;

    # Global reservations
    for my $r (@{$config->{"Dhcp4"}->{"reservations"}}) {
        push @rows, ["global", "N/A", "N/A", $r->{"hostname"} || "N/A", $r->{"hw-address"}, $r->{"ip-address"}];
    }

    # Subnet reservations
    for my $s (@{$config->{"Dhcp4"}->{"subnet4"}}) {
        my $interface = "N/A";
        for my $if (get_network_interfaces()) {
            my $ip = get_local_ip($if);
            if ($ip && is_ip_in_network($ip, $s->{"subnet"})) {
                $interface = $if;
                last;
            }
        }
        for my $r (@{$s->{"reservations"}}) {
            push @rows, [$s->{"subnet"}, $s->{"id"}, $interface, $r->{"hostname"} || "N/A", $r->{"hw-address"}, $r->{"ip-address"}];
        }
    }

    if (@rows) {
        if ($csv) {
            print join(",", qw(subnet subnet-id net-interface fqdn MAC IP)), "\n" unless $quiet;
            for my $row (@rows) {
                print join(",", @$row), "\n";
            }
        } else {
			my $tb = Text::Table->new(
                { title => "Subnet", align => "left", sample => "255.255.255.255/32" },
                \" | ",
                { title => "ID", align => "right", sample => "9999" },
                \" | ",
                { title => "Interface", align => "left", sample => "enp0s1" },
                \" | ",
                { title => "FQDN", align => "left", sample => "hostname.example.com" },
                \" | ",
                { title => "MAC", align => "left", sample => "00:11:22:33:44:55" },
                \" | ",
                { title => "IP", align => "left", sample => "255.255.255.255" },
                \" | "
            );
            $tb->load(@rows);
            print $tb unless $quiet;
        }
    } else {
        print "No client defined\n" unless $csv || $quiet;
    }
}

# _convert_option_codes: Convert code-based options to name-based
# Input: config hashref
# Output: None (modifies config in place)
sub _convert_option_codes {
    my ($config) = @_;
    for my $opt (@{$config->{"Dhcp4"}->{"option-data"}}) {
        if ($opt->{"code"} && $option_code_to_name{$opt->{"code"}}) {
            $opt->{"name"} = $option_code_to_name{$opt->{"code"}};
        }
    }
    for my $s (@{$config->{"Dhcp4"}->{"subnet4"}}) {
        for my $opt (@{$s->{"option-data"}}) {
            if ($opt->{"code"} && $option_code_to_name{$opt->{"code"}}) {
                $opt->{"name"} = $option_code_to_name{$opt->{"code"}};
            }
        }
        for my $r (@{$s->{"reservations"}}) {
            for my $opt (@{$r->{"option-data"}}) {
                if ($opt->{"code"} && $option_code_to_name{$opt->{"code"}}) {
                    $opt->{"name"} = $option_code_to_name{$opt->{"code"}};
                }
            }
        }
    }
}

# _name_to_code: Get option code from name
# Input: option name
# Output: code or undef
sub _name_to_code {
    my ($name) = @_;
    for my $code (keys %option_code_to_name) {
        return 0 + $code if $option_code_to_name{$code} eq $name; # 0 + : Force int
    }
    return undef;
}

1;

__END__

=pod

=head1 NAME

SystemImager::KeaConfUtils - Kea DHCPv4 configuration utilities for SystemImager

=head1 SYNOPSIS

use SystemImager::KeaConfUtils qw(load_kea_config init_kea_config write_kea_config add_subnet del_subnet add_pool del_pool add_client del_client set_option set_client_option list_subnets list_pools list_clients);

=head1 DESCRIPTION

This module provides utility functions for managing Kea DHCPv4 configuration
files used by SystemImager.

=head1 FUNCTIONS

=over 4

=item B<load_kea_config>($filename, $debug)

Loads and parses a Kea configuration file. Returns (config, changelog) or (undef, undef).

=item B<init_kea_config>()

Initializes a new Kea configuration with default options and classes.

=item B<write_kea_config>($filename, $config, $changelog, $debug)

Writes the configuration to a file with changelog. Returns 1 on success, 0 on failure.

=item B<add_subnet>($config, $subnet)

Adds a subnet to the configuration. Returns (1, message) or (0, error).

=item B<del_subnet>($config, $subnet, $force)

Deletes a subnet. Returns (1, message) or (0, error).

=item B<add_pool>($config, $subnet, $start_ip, $end_ip)

Adds a pool to a subnet. Returns (1, message) or (0, error).

=item B<del_pool>($config, $subnet, $start_ip, $end_ip)

Deletes a pool from a subnet. Returns (1, message) or (0, error).

=item B<add_client>($config, $name, $mac, $ip, $global)

Adds a client reservation. Returns (1, message) or (0, error).

=item B<del_client>($config, $identifier)

Deletes a client reservation. Returns (1, message) or (0, error).

=item B<set_option>($config, $option_name, $value, $subnet)

Sets a DHCP option globally or for a subnet. Returns (1, message) or (0, error).

=item B<set_client_option>($config, $identifier, $option_name, $value)

Sets a client-specific option. Returns (1, message) or (0, error).

=item B<list_subnets>($config, $csv, $quiet)

Lists all subnets in pretty print or CSV format.

=item B<list_pools>($config, $csv, $quiet)

Lists all pools in pretty print or CSV format.

=item B<list_clients>($config, $csv, $quiet)

Lists all client reservations in pretty print or CSV format.

=back

=head1 AUTHOR

Olivier Lahaye <olivier.lahaye1@free.fr>

=head1 COPYRIGHT

Copyright (C) 2025 Olivier Lahaye
Licensed under the GNU General Public License v2 or later.

=cut
