package SystemImager::Image;

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
use vars qw(@EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

$VERSION = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw(image_exists);
%EXPORT_TAGS = ('all' => [@EXPORT_OK]);

############################################
#
#  image_exists - takes one arguement, which is the name
#  of an image.  Determines whether or not the image exists
#  on the local image server
#
############################################

sub image_exists {
    my $imagename = shift;
    return _image_exists_filesystem($imagename);
}

sub _image_exists_filesystem {
    my $imagename = shift;
    my $config = get_config();
    my $dir = $config->default_imagedir . '/' . $imagename;
    return -d $dir;
}

sub _image_exists_rsync {
    my ($file, $imagename) = shift;
    open(IN,"<$file") or (carp "Can't open $file for reading", return undef);
    my $found = 0;
    while(<IN>) {
        if(/^\[$imagename\]/) {
            $found = 1;
            last;
        }
    }
    close(IN);
    return $found;
}

#
#  IMAGE INFORMATION Functions
#

sub image_info {
    my $name = shift;
    carp("I am not implemented yet");
    return {};
}

sub list_images {
    my $config = get_config();
    my $dir = $config->default_imagedir;
    my @images = ();
    opendir(IN,$dir) or (carp($!),return undef);
    while(my $file = readdir(IN)) {
        if($file !~ /^\./ and -d "$dir/$file") {
            push @images, "$dir/$file";
        }
    }
    closedir(IN);
    return @images;
}

############################################################
#
#  addimage($imagename, [$imagedir]) - adds the meta information for a SystemImager image.
#  Takes the image name, and an optional image directory (if defaults are
#  not good enough) and adds everything you need.
#
#  returns 1 on success, undef on error
#
############################################################

sub addimage {
    my ($imagename, $imagedir) = @_;
    my $config = get_config();
    $imagedir ||= $config->default_imagedir . "/" . $imagename;
    my $rsyncconf = $config->rsyncd_conf;
    return _addimage_rsync($rsyncconf, $imagename, $imagedir);
}

sub _addimage_rsync {
    my ($rsyncconf, $imagename, $imagedir) = @_;
    if(!_image_exists_rsync($rsyncconf, $imagename)) {
        open(OUT,">>$rsyncconf") or (carp "Couldn't open $rsyncconf in append mode", return 0);
        print OUT "[$imagename]\n\tpath=$imagedir\n\n";
        close OUT;
        return 1;
    }
    return 1;
}

sub removeimage {
    my $image = shift;
    my $config = get_config();
    _removeimage_clients($image);
    _removeimage_script($image);
    _removeimage_rsync($image);
    _removeimage_filesystem($image);
 
}

sub _removeimage_clients {
    return 1;
}

sub _removeimage_script {
    return 1;
}

sub _removeimage_rsync {
    return 1;
}

sub _removeimage_filesystem {
    return 1;
}

42;


