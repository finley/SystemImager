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

# Usage:
# expand_range(\%expanded_hosts, $range_string)
# Description:
#       Expand host ranges identified by the $range_string into the
#       %expaned_hosts hash.
sub expand_range {
        my ($expanded_hosts, $node) = @_;
        my ($start_root, $start_domain, $start_num, $end_root, $end_domain, $end_num);
        if ($node =~ /-/) {
                my ($front, $end) = split('-', $node, 2);

                ($start_root, $start_num, $start_domain) = ($front =~ /^(.*?)(\d+)(\..+)?$/);
                ($end_root, $end_num, $end_domain) = ($end =~ /^(.*?)(\d+)(\..+)?$/);
                if (!defined($start_domain)) {
                        $start_domain = '';
                }
                if (!defined($end_domain)) {
                        $end_domain = '';
                }
                if (!defined($start_num) || !defined($end_num)
                        || ($start_num >= $end_num)
                        || ($end_root ne $start_root)
                        || ($end_domain ne $start_domain)) {
                                $$expanded_hosts{$node}++;
                                return;
                }
        } else {
                $$expanded_hosts{$node}++;
                return;
        }
        foreach my $suffix ($start_num .. $end_num) {
                my $zeros = (length($start_num) - length($suffix));
                my $prefix = '0' x $zeros;
                $$expanded_hosts{"$start_root$prefix$suffix$start_domain"}++;
        }
}

1;
