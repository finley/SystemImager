package SystemImager::Common;

# put copyright here

$version_number="1.5.0";
$VERSION = $version_number;

sub check_if_root{
	unless($< == 0) { die "Must be run as root!\n"; }
}

sub get_response {
	my $garbage_in=<STDIN>;
	chomp $garbage_in;
	unless($garbage_in) { $garbage_in = $_[1]; }
	$garbage_out = $garbage_in;
	return $garbage_out;
}
