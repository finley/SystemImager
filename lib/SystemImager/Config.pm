#
# "SystemImager"
#
#  Copyright (C) 2002 Bald Guy Software 
#                     Brian E. Finley <brian.finley@baldguysoftware.com>
#                2017 Olivier Lahaye <olivier.lahaye@cea.fr>
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
if ( -e "$ENV{'SIS_CONFDIR'}/systemimager.conf" ) {
        $config->set("systemimager_dir","$ENV{'SIS_CONFDIR'}");
}

my $config_file = $config->get("systemimager_dir")."/systemimager.conf";
$config->file($config_file) if (-f $config_file);

$::main::config = $config;

1;
