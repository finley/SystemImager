#
#    vi:set filetype=bash et ts=4:
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

package SystemImager::IpUtils;

use strict;
use warnings;
use Socket;
use IO::Socket::INET;

our $VERSION = "SYSTEMIMAGER_VERSION_STRING";

# Exporter les fonctions
use Exporter qw(import);
our @EXPORT_OK = qw(
    valid_ip
	valid_fqdn
    ip_to_int
    first_usable_ip
    is_ip_in_network
    is_ip_in_range
    get_subnet_ip_range
    is_range_overlap
    get_network_interfaces
    get_local_ip
);

sub valid_ip {
    my ($ip) = @_;
    return 0 unless $ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
    return 0 if $1 > 255 || $2 > 255 || $3 > 255 || $4 > 255;
    return 1;
}

sub valid_fqdn {
    my ($fqdn) = @_;
    return $fqdn =~ /^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$/;
}

sub ip_to_int {
    my ($ip) = @_;
    return 0 unless valid_ip($ip);
    my @octets = split(/\./, $ip);
    return ($octets[0] << 24) + ($octets[1] << 16) + ($octets[2] << 8) + $octets[3];
}

sub first_usable_ip {
    my ($ip, $mask) = @_;
    my $net_int = ip_to_int($ip);
    my $mask_int = (2 ** 32) - (2 ** (32 - $mask));
    my $first_ip = ($net_int & $mask_int) + 1;
    my @octets;
    for my $i (3, 2, 1, 0) {
        $octets[$i] = $first_ip & 255;
        $first_ip >>= 8;
    }
    return join('.', @octets);
}

sub is_ip_in_network {
    my ($ip, $ip_mask, $net_ip, $net_mask) = @_;
    return 0 unless valid_ip($ip) && valid_ip($net_ip);
    return 0 unless $ip_mask =~ /^\d+$/ && $ip_mask >= 0 && $ip_mask <= 32;
    return 0 unless $net_mask =~ /^\d+$/ && $net_mask >= 0 && $net_mask <= 32;
    my $ip_int = ip_to_int($ip);
    my $net_int = ip_to_int($net_ip);
    my $mask_int = (2 ** 32) - (2 ** (32 - $net_mask));
    return ($ip_int & $mask_int) == ($net_int & $mask_int);
}

sub is_ip_in_range {
    my ($ip, $start, $end) = @_;
    my $ip_int = ip_to_int($ip);
    my $start_int = ip_to_int($start);
    my $end_int = ip_to_int($end);
    return $ip_int >= $start_int && $ip_int <= $end_int;
}

sub get_subnet_ip_range {
    my ($ip, $mask) = @_;
    my $net_int = ip_to_int($ip);
    my $mask_int = (2 ** 32) - (2 ** (32 - $mask));
    my $ip_min = $net_int & $mask_int;
    my $ip_max = $ip_min + (2 ** (32 - $mask)) - 1;
    my @min_octets;
    my @max_octets;
    my $temp_min = $ip_min;
    my $temp_max = $ip_max;
    for my $i (3, 2, 1, 0) {
        $min_octets[$i] = $temp_min & 255;
        $max_octets[$i] = $temp_max & 255;
        $temp_min >>= 8;
        $temp_max >>= 8;
    }
    return (join('.', @min_octets), join('.', @max_octets));
}

sub is_range_overlap {
    my ($start1, $end1, $start2, $end2) = @_;
    my $start1_int = ip_to_int($start1);
    my $end1_int = ip_to_int($end1);
    my $start2_int = ip_to_int($start2);
    my $end2_int = ip_to_int($end2);
    my $is_included = ($start1_int >= $start2_int && $end1_int <= $end2_int) || ($start2_int >= $start1_int && $end2_int <= $end1_int);
    my $is_partial_overlap = ($start1_int <= $end2_int && $end1_int >= $start2_int) && !$is_included;
    return ($is_included, $is_partial_overlap);
}

sub get_network_interfaces {
    my (@networks) = @_;
    my %interfaces;
    open my $ip_addr, '-|', 'ip -4 addr show' or die "Impossible d'exécuter ip addr: $!\n";
    while (my $line = <$ip_addr>) {
        chomp $line;
        if ($line =~ /inet\s+(\d+\.\d+\.\d+\.\d+)\/(\d+)\s+.*\s+(\S+)$/) {
            my ($ip, $mask, $iface) = ($1, $2, $3);
            print "DEBUG: Interface trouvée: $iface pour $ip/$mask\n" if $SystemImager::IpUtils::debug;
            foreach my $net (@networks) {
                my ($net_ip, $net_mask) = split('/', $net);
                next unless defined $net_ip && defined $net_mask;
                if (is_ip_in_network($ip, $mask, $net_ip, $net_mask)) {
                    push @{$interfaces{$net}}, $iface;
                    print "DEBUG: Interface $iface associée au réseau $net\n" if $SystemImager::IpUtils::debug;
                }
            }
        }
    }
    close $ip_addr;
    return map { @{$interfaces{$_} || []} } @networks;
}

sub get_local_ip {
    my (@add_networks, $config) = @_;
    my @available_networks;
    foreach my $i (0 .. $#add_networks / 3) {
        push @available_networks, $add_networks[$i*3];
    }
    if (exists $config->{"Dhcp4"}->{"subnet4"}) {
        foreach my $subnet (@{$config->{"Dhcp4"}->{"subnet4"}}) {
            my $net = $subnet->{"subnet"};
            next unless defined $net && $net =~ m|^(\d+\.\d+\.\d+\.\d+)/(\d+)$|;
            push @available_networks, $net;
        }
    }

    if (@available_networks) {
        open my $ip_addr, '-|', 'ip -4 addr show' or die "Impossible d'exécuter ip addr: $!\n";
        while (my $line = <$ip_addr>) {
            chomp $line;
            if ($line =~ /inet\s+(\d+\.\d+\.\d+\.\d+)\/(\d+)/) {
                my ($ip, $mask) = ($1, $2);
                print "DEBUG: IP locale trouvée: $ip/$mask\n" if $SystemImager::IpUtils::debug;
                foreach my $net (@available_networks) {
                    my ($net_ip, $net_mask) = split('/', $net);
                    unless (defined $net_ip && defined $net_mask) {
                        warn "DEBUG: Réseau mal formé dans get_local_ip: $net\n" if $SystemImager::IpUtils::debug;
                        next;
                    }
                    print "DEBUG: Vérification si $ip/$mask est dans $net_ip/$net_mask\n" if $SystemImager::IpUtils::debug;
                    if (is_ip_in_network($ip, $mask, $net_ip, $net_mask)) {
                        close $ip_addr;
                        return $ip;
                    }
                }
            }
        }
        close $ip_addr;
    }

    print "DEBUG: Aucun réseau correspondant trouvé, utilisation du fallback\n" if $SystemImager::IpUtils::debug;
    my $socket = IO::Socket::INET->new(
        Proto    => 'udp',
        PeerAddr => '8.8.8.8',
        PeerPort => 53
    ) or die "Impossible de déterminer l'IP locale: $!\n";
    my $ip = inet_ntoa($socket->sockaddr);
    $socket->close;
    return $ip;
}

1;

__END__

=head1 NAME

SystemImager::IpUtils - Utilitaires pour la manipulation des adresses IP et sous-réseaux

=head1 SYNOPSIS

    use SystemImager::IpUtils qw(valid_ip valid_fqdn ip_to_int first_usable_ip is_ip_in_network is_ip_in_range get_subnet_ip_range is_range_overlap get_network_interfaces get_local_ip);

    # Valider une adresse IP
    if (valid_ip("192.168.1.1")) {
        print "Adresse IP valide\n";
    }

    # Valider un FQDN
    if (valid_fqdn("example.com")) {
        print "FQDN valide\n";
    }

    # Convertir une IP en entier
    my $ip_int = ip_to_int("192.168.1.1");

    # Obtenir la première IP utilisable d'un sous-réseau
    my $first_ip = first_usable_ip("192.168.1.0", 24);

    # Vérifier si une IP est dans un sous-réseau
    if (is_ip_in_network("192.168.1.100", 24, "192.168.1.0", 24)) {
        print "IP dans le sous-réseau\n";
    }

    # Vérifier si une IP est dans une plage
    if (is_ip_in_range("192.168.1.100", "192.168.1.50", "192.168.1.150")) {
        print "IP dans la plage\n";
    }

    # Obtenir la plage d'adresses d'un sous-réseau
    my ($ip_min, $ip_max) = get_subnet_ip_range("192.168.1.0", 24);

    # Vérifier si deux plages se chevauchent
    my ($is_included, $is_partial_overlap) = is_range_overlap("192.168.1.50", "192.168.1.100", "192.168.1.75", "192.168.1.125");

    # Obtenir les interfaces réseau associées à un sous-réseau
    my @interfaces = get_network_interfaces("192.168.1.0/24");

    # Obtenir l'adresse IP locale
    my $local_ip = get_local_ip(["192.168.1.0/24"], $config);

=head1 DESCRIPTION

Ce module fournit des fonctions utilitaires pour manipuler les adresses IP, les sous-réseaux, et les interfaces réseau dans le contexte de SystemImager. Il est conçu pour être utilisé avec le script C<si_mkdhcpserver> pour gérer les configurations de serveurs DHCP Kea.

=head1 FUNCTIONS

=over 4

=item B<valid_ip($ip)>

Valide une adresse IPv4. Retourne 1 si l'adresse est valide (format C<xxx.xxx.xxx.xxx> avec chaque octet entre 0 et 255), 0 sinon.

=item B<valid_fqdn($fqdn)>

Valide un nom de domaine complet (FQDN). Retourne 1 si le FQDN est valide (caractères alphanumériques, points, tirets, sans commencer ni finir par un point ou un tiret), 0 sinon.

=item B<ip_to_int($ip)>

Convertit une adresse IPv4 en entier 32 bits. Retourne 0 si l'adresse est invalide.

=item B<first_usable_ip($ip, $mask)>

Calcule la première adresse IP utilisable dans un sous-réseau donné par son adresse réseau (C<$ip>) et son masque (C<$mask>). Retourne l'adresse sous forme de chaîne (format C<xxx.xxx.xxx.xxx>).

=item B<is_ip_in_network($ip, $ip_mask, $net_ip, $net_mask)>

Vérifie si une adresse IP (C<$ip>) avec son masque (C<$ip_mask>) appartient à un sous-réseau défini par son adresse réseau (C<$net_ip>) et son masque (C<$net_mask>). Retourne 1 si l'IP est dans le sous-réseau, 0 sinon.

=item B<is_ip_in_range($ip, $start, $end)>

Vérifie si une adresse IP (C<$ip>) est dans la plage définie par C<$start> et C<$end>. Retourne 1 si l'IP est dans la plage, 0 sinon.

=item B<get_subnet_ip_range($ip, $mask)>

Calcule les adresses minimale (réseau) et maximale (broadcast) d'un sous-réseau donné par son adresse réseau (C<$ip>) et son masque (C<$mask>). Retourne un tableau de deux éléments : C<($ip_min, $ip_max)> sous forme de chaînes (format C<xxx.xxx.xxx.xxx>).

=item B<is_range_overlap($start1, $end1, $start2, $end2)>

Vérifie si deux plages d'adresses IP se chevauchent. Retourne un tableau de deux booléens : C<($is_included, $is_partial_overlap)>. C<$is_included> est vrai si une plage est entièrement incluse dans l'autre. C<$is_partial_overlap> est vrai si les plages se chevauchent partiellement sans inclusion complète.

=item B<get_network_interfaces(@networks)>

Retourne une liste d'interfaces réseau associées aux sous-réseaux spécifiés (format C<xxx.xxx.xxx.xxx/n>). Utilise la commande C<ip -4 addr show> pour détecter les interfaces réseau locales.

=item B<get_local_ip(@add_networks, $config)>

Détermine l'adresse IP locale correspondant à l'un des sous-réseaux fournis dans C<@add_networks> ou dans la configuration C<$config->{"Dhcp4"}->{"subnet4"}>. Si aucune correspondance n'est trouvée, utilise une connexion UDP vers 8.8.8.8:53 pour déterminer l'IP locale.

=back

=head1 AUTHOR

Équipe SystemImager

=head1 COPYRIGHT

Copyright (C) 2025 SystemImager Team

This library is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

=head1 SEE ALSO

L<si_mkdhcpserver>, L<kea-dhcp4(8)>, L<systemimager(1)>

=head1 BUGS

Signalez les bugs à l'équipe SystemImager. Problèmes connus :
- La fonction C<get_network_interfaces> dépend de la commande C<ip -4 addr show> et peut ne pas fonctionner correctement sur des systèmes où cette commande n'est pas disponible ou retourne un format inattendu.
- La fonction C<get_local_ip> utilise une connexion UDP vers 8.8.8.8:53 comme fallback, ce qui nécessite une connectivité réseau sortante.

=head1 VERSION

SYSTEMIMAGER_VERSION_STRING

=cut
