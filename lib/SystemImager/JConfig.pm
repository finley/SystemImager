#
# "SystemImager"
#
#  Copyright (C) 2019 Olivier Lahaye <olivier.lahaye@cea.fr>
#
#    $Id$
#
# Usage:
# use SystemImager::JConfig;
# use vars qw($config);
#
# my $port = $config->getParam('monitor_port');
# $config->setParam('monitor_port',"8181");

package SystemImager::JConfig;

use JSON;
use strict;
use warnings;

BEGIN {
    use Exporter();

    @SystemImager::Config::ISA       = qw(Exporter);
    @SystemImager::Config::EXPORT    = qw();
    @SystemImager::Config::EXPORT_OK = qw($config);

}

use vars qw($config);

sub new {
	my $class = shift;
	my $self = {
		_config_file => "/etc/systemimager/systemimager.json",
		_config => undef,
	};
	# If SIS_CONFDIR is defined use this instead of default /etc/systemimager.
	# This is usefull when run from build environment where /etc/systemimager doesn't
	# exists yet.
	if( defined($ENV{'SIS_CONFDIR'}) ) {
		my $env_sis_confdir="$ENV{'SIS_CONFDIR'}";
		$env_sis_confdir =~ s/\/+$//; # Remove useless trailing slashes

		if ( -d "$env_sis_confdir" ) {
			$self->{_config_file} = "$env_sis_confdir/systemimager.conf";
		}
	}
	# At this point, $self->{_config_file} is defined.
	if ( -e $self->{_config_file} ) {
		loadConfig($self);
	} else {
		loadDefaults($self);
	}
	bless $self, $class;
	return $self;
}

sub loadDefaults {
	my ( $self ) = @_;
	$self->{_config} = {
		'images_dir' => '/var/lib/systemimager/images',
		'overrides_dir' => '/var/lib/systemimager/overrides',
		'scripts_dir' => '/var/lib/systemimager/scripts',
		'clients_db_dir' => '/var/lib/systemimager/clients',
		'tarballs_dir' => '/var/lib/systemimager/tarballs',
		'torrents_dir' => '/var/lib/systemimager/torrents',
		'pxe_boot_files' => '/usr/share/systemimager/boot',
		'monitor_logfile' => '/var/log/systemimager/si_monitord.log',
		'monitor_port' => '8181',
		'monitor_loglevel' => '1',
		'rsyncd_conf' => '/etc/systemimager/rsyncd.conf',
		'rsync_stub_dir' => '/etc/systemimager/rsync_stubs',
		'tftp_dir' => '/var/lib/tftpboot',
		'pxe_boot_mode' => 'net',
	};
	return;
};

#    'default_image_dir'         => { ARGCOUNT => 1 },
#    'default_override_dir'      => { ARGCOUNT => 1 },
#    'autoinstall_script_dir'    => { ARGCOUNT => 1 },
#    'autoinstall_config_dir'    => { ARGCOUNT => 1 },
#    'autoinstall_boot_dir'      => { ARGCOUNT => 1 },
#    'rsyncd_conf'               => { ARGCOUNT => 1 },
#    'rsync_stub_dir'            => { ARGCOUNT => 1 },
#    'tftp_dir'                  => { ARGCOUNT => 1 },
#    'net_boot_default'          => { ARGCOUNT => 1 },
#    'autoinstall_tarball_dir'   => { ARGCOUNT => 1 },
#    'autoinstall_torrent_dir'   => { ARGCOUNT => 1 },
#    'systemimager_dir'          => { ARGCOUNT => 1,
#				     ARGS => "=s",
#				     DEFAULT => "/etc/systemimager" },

sub loadConfig {
	my ($self) = @_;

	# 1st: load config file content.
	my $config_raw_text = do {
        	open(my $json_fh, "<:encoding(UTF-8)", $self->{_config_file})
        	        or die("Can't open \$filename\": $!\n");
        	local $/;
        	<$json_fh>
	};

	# 2nd: Upon success, try to parse it
	if (defined ($config_raw_text) ) {
		my $json = JSON->new;
		$self->{_config} = $json->decode($config_raw_text);
		if (defined ($self->{_config})) {
			return $self->{_config}; # Return parsed data. Code blow is for error handling.
		} else {
			warn "Failed to parse $self->{_config_file}. Using Defaults.";
		}
	} else {
		warn "Failed to read $self->{_config_file}. Using defaults.";
	}
	loadDefaults($self); # Use default values as fallback.
	return $self->{_config};
}

sub saveConfig {
	my ($self) = @_;
	# Not implemented. Needed?
}

# If parameter given: set filename.
# return: configuration filename.
sub fileName {
        my ($self,$config_file) = @_;
	$self->{_config_file} = $config_file if defined($config_file);
	return $self->{_config_file};
}

sub get {
	my ($self, $var_name) = @_;
	if (exists($self->{_config}->{$var_name})) {
		return($self->{_config}->{$var_name});
	} else {
		warn "$var_name is not a systemimager configuration parameter";
		return undef;
	}
}

sub set {
	my ($self, $var_name, $value) = @_;
	if (exists($self->{_config}->{$var_name})) {
		$self->{_config}->{$var_name} = $value;
		return $self->{_config}->{$var_name};
	} else {
		warn "$var_name is not a systemimager configuration parameter";
		return undef;
	}
}

my $config = new SystemImager::JConfig();
$::main::config = $config;

1;
