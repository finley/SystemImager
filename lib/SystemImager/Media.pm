package SystemImager::Media;

#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
 
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
 
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#  Sean Dague <sean@dague.net>

#  $Id$

use strict;
use Carp;
use SystemImager::Config qw(get_config);
use base qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION $AUTOLOAD $ARCH);
use POSIX qw(uname);

$VERSION = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw(create_bootdisk create_bootcd create_netboot);
%EXPORT_TAGS = ('all' => [@EXPORT_OK]);

$ARCH = (uname())[4]; 
$ARCH =~ s/i.86/i386/;

print "Arch = $ARCH\n";

sub create_bootdisk {
    _do_boot_loader_things('i386');
}

#sub _do_boot_loader_things {
#
#}


sub AUTOLOAD {
    $AUTOLOAD =~ /.*::(\w+)/
      or croak("No such method: $AUTOLOAD");
    
    my $var = $1;
    my $return = "";
    eval {
        $return = "SystemImager::Media::$ARCH"->$var(@_);
    };
    if($@) {
        eval {
            $return = "SystemImager::Media::Base"->$var(@_);
        };
    }
    return $return;
}

package SystemImager::Media::Base;

sub _do_boot_loader_things {
    print "I am the base\n";
}

package SystemImager::Media::s390;
use base qw(SystemImager::Media::Base);



package SystemImager::Media::i386;

sub _do_boot_loader_things {
    print "I am i386\n";
}

package SystemImager::Media::ia64;

sub _do_boot_loader_things {
    print "I am ia64\n";
}



42;

__END__

=head1 NAME

Auto Installation Boot Media Creation

=head1 CREATION STEPS

This is an attempt to document the steps that it takes to 
create boot media in order to come up with a platform agnostic
way of doing this.

We would also like to have one method that supports network,
cd, and floppy (i386 only) booting methods.

Please add any other things to this list when you find it.

=over 4

=item 1)

Build loop file (CD and Floppy only)

This builds the loopback mountable file for the image that will make it to the
media.  The size of this varies based on architecture.

  * i386 - 2880 k
  * ia64 - 10240 k (this could be smaller)
  * ppc chrp - unknown

=item 2)

Format the loop file (CD and Floppy only)

This formats it for a specific filesystem.  The type of filesystem varies depending
on architecture.

  * i386 - mkdosfs
  * ia64 - mkdosfs
  * ppc chrp - iso9660 ?

=item 3)

Make media bootable (i386 / CD and Floppy only) 

This runs syslinux on the loop file to make it bootable

=item 4)

Mount the loop file as a loopback (CD and Floppy only)

The file system used here is important and varies based on arch.

  * i386 - msdos
  * ia64 - vfat (we need long filenames)
  * ppc chrp - unknown

=item 1N)

Setup Network Serving Daemon.

This is equivalent to 'making media bootable' for hard media.  This is
where the network daemon gets set up.  Depending on the architecture
different files must be served, though they all need the following:

  * dhcp server - specified to serve a file
  * tftp server - designed to actually transfer that file

Each architecture must serve its own specific file here:

  * i386 - PXE utility (either syslinux or the real PXE daemon)
  * ia64 - elilo.efi (this is the efi boot loader)
  * ppc chrp - zImage.initrd (this is a special file which is both the
               kernel and initrd together.  See later for more info)

=item 5)

Copy appropriate kernel files to the boot area

   * i386 - kernel, initrd.gz, message.txt
   * ia64 - kernel, initrd.gz, elilo.efi (for symetry we may want elilo.efi elsewhere) 
   * ppc chrp - zImage.initrd

=item 6)

Set up local.cfg (CD & Floppy)

Question: How can we use this for CD boot?

=item 7)

Write boot conf file

   * i386 CD & Floppy - syslinux.cfg
   * i386 Network - pxelinux.cfg
   * ia64 - elilo.conf
   * ppc chrp CD - /ppc/bootinfo.txt
   * ppc chrp network - none

=item 8)

Umount loops (CD & Floppy only)

=item 9)

Make ISO filesystem (CD only)

=item 10)

Commit media (CD and Floppy only)

Actually write out the media to disk.  Floppy uses dd here, CD uses cdrecord.

=back

=head1 ARCH SPECIFIC STUFF

=head2 zImage.initrd

The following is a conversation from irc that explains this as well as
I understand it.

 <hollis> zImage.initrd.chrp-rs6k
 <hollis> that is kernel+initrd in one file
 <sdague> catted together?
 <hollis> no, built together
 <hollis> make zImage.initrd
 <sdague> oh... ok
 <hollis> (with ramdisk.image.gz in arch/ppc/boot/images at the time)

=head2 /ppc/bootinfo.txt

Here is the format of this file as grokked from irc

 <hollis> <chrp-boot>
 <hollis> <description>SuSE Linux SLES-7 (PPC)</description>
 <hollis> <os-name>SuSE Linux SLES-7 (PPC)</os-name>
 <hollis> <boot-script>boot &device;:1,zImage.initrd </boot-script>
 <hollis> </chrp-boot>


