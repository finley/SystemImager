package SystemImager::Common;

# put copyright here

=head1 NAME

SystemImager::Common - Modules common to both client and server utilities.

=head1 SYNOPSIS

#  my $bootloader = new SystemConfig::Boot::Grub(%bootvars);
#
#  if($bootloader->footprint()) {
#      $bootloader->setup();
#  }
#
#  my @fileschanged = $bootloader->files();

=cut

#use strict;

$version_number="1.5.0";
$VERSION = $version_number;

#push @SystemConfig::Boot::boottypes, qw(SystemConfig::Boot::Grub);

#sub new {
#    my $class = shift;
#    my %this = (
#                root => "",
#                filesmod => [],
#		grub_path => "",       ### Path to Grub executable.
#		device_map_file => "", ### Device map file
#		boot_inst_dev => "",   ### Device to which to install boot image.
#		default_root => "",    ### The default root device. 
#                @_,
#               );
#    bless \%this, $class;
#}

=head1 METHODS

The following methods exist in this module:

=over 4

=item check_if_root()

The check_if_root() method makes sure that the command is being run as
the user root.

=cut

sub check_if_root{
    unless($< == 0) { die "$program_name: Must be run as root!\n"; }
}


=back

=head1 AUTHOR

  Brian Finley <brian@thefinleys.com>

=head1 SEE ALSO

L<SystemImager::Client>, L<SystemImager::Common>, L<perl>

=cut

1;


