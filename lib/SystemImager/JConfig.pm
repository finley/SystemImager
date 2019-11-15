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
# read parameter value:
#	my $port = $config->getParam('monitor','port');
#	 => returns value upon success. undef otherwise.
#
# set parameter value:
#	 $config->setParam('monitor','port',"8181");
#	 => returns value upon success. undef otherwise.
#
# get/set configuration filename:
#	my $file_name = $config->fileName()
#	my $file_name = $config->fileName('/path/to/new/fileName')
#	=> returns fileName.
#
# read default values for all parameters:
# 	$config->loadDefaults()
#	=> returns nothing. (dies if fails to load defaults).
#
# read parameters from config file:
# 	my $config_structure = $config->loadConfig()
#	=> returns undef upon failure.
#	=> Note: using this module defines $config by default.
#	   Thus this method is only needed internally.
#

package SystemImager::JConfig;

use JSON;
use strict;
use warnings;
use 5.010;

BEGIN {
    use Exporter();

    @SystemImager::JConfig::ISA       = qw(Exporter);
    @SystemImager::JConfig::EXPORT    = qw();
    @SystemImager::JConfig::EXPORT_OK = qw($config);

}

use vars qw($config);

sub new {
	my $class = shift;
	my $self = {
		_config_file => "/etc/systemimager/systemimager.json",
		_config_scheme => "/usr/share/systemimager/webgui/config_scheme.json",
		_config => undef,
	};
	# If SIS_CONFDIR is defined use this instead of default /etc/systemimager.
	# This is usefull when run from build environment where /etc/systemimager doesn't
	# exists yet.
	if( defined($ENV{'SIS_CONFDIR'}) ) {
		my $env_sis_confdir="$ENV{'SIS_CONFDIR'}";
		$env_sis_confdir =~ s/\/+$//; # Remove useless trailing slashes

		if ( -d "$env_sis_confdir" ) {
			$self->{_config_file} = "$env_sis_confdir/systemimager.json";
		}
	}
	# If SIS_WEBGUIDIR is defined use this instead of default /usr/share/systemimager/webgui
	# This is usefull when run from build environment where /usr/share/systemimager/webgui doesn't
	# exists yet.
	if( defined($ENV{'SIS_WEBGUIDIR'}) ) {
		my $env_webgui_dir="$ENV{'SIS_WEBGUIDIR'}";
		$env_webgui_dir =~ s/\/+$//; # Remove useless trailing slashes

		if ( -d "$env_webgui_dir" ) {
			$self->{_config_scheme} = "$env_webgui_dir/config_scheme.json";
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
	# 1/ Read the scheme.
	my $scheme_raw_text = do {
		open(my $json_fh, "<:encoding(UTF-8)", $self->{_config_scheme})
                        or die("Can't open $self->{_config_scheme}: $!\n");
                local $/;
                <$json_fh>
	};
	# 2/ Load defaults values.
	my $scheme_hash = undef;
	if (defined ($scheme_raw_text) ) {
		my $json = JSON->new;
		$scheme_hash = $json->decode($scheme_raw_text);
		if (!defined ($scheme_hash)) {
			die "Failed to parse $self->{_config_scheme}.";
		}
	} else {
		die "Failed to read $self->{_config_scheme}.";
	}
	# 3/ Load defaults from scheme.
	foreach my $field ( keys $scheme_hash) {
		foreach my $param (keys $scheme_hash->{$field}) {
			my $field_tolower = lc($field);
			my $param_tolower = lc($param);
			my @param_scheme = @{ $scheme_hash->{$field}->{$param} };
			if ($param_scheme[0] eq "path") {
				$self->{_config}->{$field_tolower}->{$param_tolower} = $param_scheme[1];
		       	} elsif ($param_scheme[0] eq "file") {
				$self->{_config}->{$field_tolower}->{$param_tolower} = $param_scheme[1];
			} elsif ($param_scheme[0] eq "port") {
				$self->{_config}->{$field_tolower}->{$param_tolower} = $param_scheme[1];
			} elsif ($param_scheme[0] eq "select") {
				$self->{_config}->{$field_tolower}->{$param_tolower} = $param_scheme[1][0]; # Def val is elmt #0 of possible values.
			} elsif ($param_scheme[0] eq "text") {
				$self->{_config}->{$field_tolower}->{$param_tolower} = $param_scheme[1];
			} else {
				die "Unknown field type in config_scheme: ".$param_scheme[0];
			}
		}
	}
	return;
};

sub loadConfig {
	my ($self) = @_;

	# 1st: load config file content.
	my $config_raw_text = do {
        	open(my $json_fh, "<:encoding(UTF-8)", $self->{_config_file})
                       or die("Can't open $self->{_config_file}: $!\n");
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
	die "saveConfig is not yet implemented."
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
	my ($self, $field, $var_name) = @_;
	if (exists($self->{_config}->{$field}->{$var_name})) {
		return($self->{_config}->{$field}->{$var_name});
	} else {
		warn "$field.$var_name is not a systemimager configuration parameter";
		return undef;
	}
}

sub set {
	my ($self, $field, $var_name, $value) = @_;
	if (exists($self->{_config}->{$field}->{$var_name})) {
		$self->{_config}->{$field}->{$var_name} = $value;
		return $self->{_config}->{$field}->{$var_name};
	} else {
		warn "$var_name is not a systemimager configuration parameter";
		return undef;
	}
}

my $config = new SystemImager::JConfig();
$::main::config = $config;

1;
