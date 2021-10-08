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
#    Copyright (C) 2002 Bald Guy Software 
#                       Brian E. Finley <brian.finley@baldguysoftware.com>
#                  2017 -2019Olivier Lahaye <olivier.lahaye@cea.fr>
#
#    $Id$
#

package SystemImager::Config;

use strict;
use AppConfig;

BEGIN {
    use Exporter();

    @SystemImager::Config::ISA       = qw(Exporter);
    @SystemImager::Config::EXPORT    = qw();
    @SystemImager::Config::EXPORT_OK = qw($config);

}
use vars qw($config);

$config = AppConfig->new(
    'default_image_dir'         => { ARGCOUNT => 1 },
    'default_override_dir'      => { ARGCOUNT => 1 },
    'autoinstall_script_dir'    => { ARGCOUNT => 1 },
    'autoinstall_config_dir'    => { ARGCOUNT => 1 },
    'autoinstall_boot_dir'      => { ARGCOUNT => 1 },
    'rsyncd_conf'               => { ARGCOUNT => 1 },
    'rsync_stub_dir'            => { ARGCOUNT => 1 },
    'tftp_dir'                  => { ARGCOUNT => 1 },
    'net_boot_default'          => { ARGCOUNT => 1 },
    'autoinstall_tarball_dir'   => { ARGCOUNT => 1 },
    'autoinstall_torrent_dir'   => { ARGCOUNT => 1 },
    'systemimager_dir'          => { ARGCOUNT => 1,
				     ARGS => "=s",
				     DEFAULT => "/etc/systemimager" },
);

# If SIS_CONFDIR is defined use this instead of default /etc/systemimager.
# This is usefull when run from build environment where /etc/systemimager doesn't
# exists yet.
if(defined($ENV{'SIS_CONFDIR'})) {
    my $env_sis_confdir="$ENV{'SIS_CONFDIR'}";
    $env_sis_confdir =~ s/\/+$//; # Remove useless trailing slashes

    if ( -e "$env_sis_confdir/systemimager.conf" ) {
        $config->set("systemimager_dir","$env_sis_confdir");
    }
}

my $config_file = $config->get("systemimager_dir")."/systemimager.conf";
$config->file($config_file) if (-f $config_file);

$::main::config = $config;

1;
