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
#    Copyright (C) 2017-2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#    Purpose:
#      SystemImager JSON based configuration module.
#      This modules requires that the configuration scheem exists as:
#        - /usr/share/systemimager/webgui/config_scheme.json
#
# Usage:
# use SystemImager::JConfig;
# use vars qw($jconfig);
#
# read parameter value:
#	my $port = $jconfig->getParam('monitor','port');
#	 => returns value upon success. undef otherwise.
#
# set parameter value:
#	 $jconfig->setParam('monitor','port',"8181");
#	 => returns value upon success. undef otherwise.
#
# get/set configuration filename:
#	my $file_name = $jconfig->fileName()
#	my $file_name = $jconfig->fileName('/path/to/new/fileName')
#	=> returns fileName.
#
# read default values for all parameters:
#	$jconfig->loadDefaults()
#	=> returns nothing. (dies if fails to load defaults).
#
# read parameters from config file:
#	my $jconfig_structure = $jconfig->load()
#	=> returns undef upon failure.
#	=> Note: using this module defines $jconfig by default.
#	   Thus this method is only needed internally.
#
# save parameters to config file:
# 	$jconfig->save()
# 	=> dies on failure.

package SystemImager::JConfig;

use JSON;
use strict;
use warnings;
use 5.010;
use parent 'Exporter'; # imports and subclasses Exporter
our $jconfig = new SystemImager::JConfig();;
our @EXPORT = qw($jconfig);

sub new {
	my $class = shift;
	my $self = {
		_config_file => "/etc/systemimager/systemimager.json",
		_config_scheme => "/usr/share/systemimager/conf/config_scheme.json",
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
	# If SIS_DATAROOTDIR is defined use this instead of default /usr/share/systemimager/conf
	# This is usefull when run from build environment where /usr/share/systemimager/conf doesn't
	# exists yet.
	if( defined($ENV{'SIS_DATAROOTDIR'}) ) {
		my $env_datarootdir="$ENV{'SIS_DATAROOTDIR'}";
		$env_datarootdir =~ s/\/+$//; # Remove useless trailing slashes

		if ( -d "$env_datarootdir" ) {
			$self->{_config_scheme} = "$env_datarootdir/config_scheme.json";
		}
	}
	# At this point, $self->{_config_file} is defined.
	if ( -e $self->{_config_file} ) {
		load($self);
	} else {
		loadDefaults($self);	# File doesn't exists: load defaults values from scheme.
		eval {			# Then save the values in config file.
			save($self);
			1;
		} or do {
			my $err = $@;
			warn "Failed to save default config to $self->{_config_file}: $err.";
		}
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
	foreach my $field ( keys %{ $scheme_hash }) {
		foreach my $param (keys %{ $scheme_hash->{$field} }) {
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

sub load {
	my ( $self ) = @_;

	# 1st: load config file content.
	my $config_raw_text = do {
		open(my $json_fh, '<:encoding(UTF-8)', $self->{_config_file})
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

sub save {
	my ($self) = @_;
	my $json = JSON->new;
	my $json_raw_text = $json->pretty->encode($self->{_config});
	open(my $json_fh, '>:encoding(UTF-8)', $self->{_config_file})
		or die("Can't open $self->{_config_file}: $!\n");
	print $json_fh $json_raw_text;
	close $json_fh;
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

1;
