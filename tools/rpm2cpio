#!/usr/bin/perl

# Copyright (C) 1997,1998,1999, Roger Espel Llima
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and any associated documentation files (the "Software"), to 
# deal in the Software without restriction, including without limitation the 
# rights to use, copy, modify, merge, publish, distribute, sublicense, 
# and/or sell copies of the Software, and to permit persons to whom the 
# Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# SOFTWARE'S COPYRIGHT HOLDER(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE

# (whew, that's done!)

# why does the world need another rpm2cpio?  because the existing one
# won't build unless you have half a ton of things that aren't really
# required for it, since it uses the same library used to extract RPM's.
# in particular, it won't build on the HPsUX box i'm on.

# sw 2002-Mar-6 Don't slurp the whole file

# add a path if desired
$gzip = "gzip";

sub printhelp {
  print <<HERE;
rpm2cpio, perl version by orabidoo <odar\@pobox.com> +sw
dumps the contents to stdout as a cpio archive

use: rpm2cpio [file.rpm] > file.cpio

Here's how to use cpio:
     list of contents:   cpio -t -i < /file/name
        extract files:   cpio -d -i < /file/name
HERE

  exit 0;
}

if ($#ARGV == -1) {
  printhelp if -t STDIN;
  $f = "STDIN";
} elsif ($#ARGV == 0) {
  open(F, "< $ARGV[0]") or die "Can't read file $ARGV[0]\n";
  $f = 'F';
} else {
  printhelp;
}

printhelp if -t STDOUT;

# gobble the file up
##undef $/;
##$|=1;
##$rpm = <$f>;
##close ($f);

read $f,$rpm,96;

($magic, $major, $minor, $crap) = unpack("NCC C90", $rpm);

die "Not an RPM\n" if $magic != 0xedabeedb;
die "Not a version 3 or 4 RPM\n" if $major != 3 && $major != 4;

##$rpm = substr($rpm, 96);

while (!eof($f)) {
  $pos = tell($f);
  read $f,$rpm,16;
  $smagic = unpack("n", $rpm);
  last if $smagic eq 0x1f8b;
  # Turns out that every header except the start of the gzip one is
  # padded to an 8 bytes boundary.
  if ($pos & 0x7) {
    $pos += 7;
    $pos &= ~0x7;	# Round to 8 byte boundary
    seek $f, $pos, 0;
    read $f,$rpm,16;
  }
  ($magic, $crap, $sections, $bytes) = unpack("N4", $rpm);
  die "Error: header not recognized\n" if $magic != 0x8eade801;
  $pos += 16;		# for header
  $pos += 16 * $sections;
  $pos += $bytes;
  seek $f, $pos, 0;
}

if (eof($f)) {
  die "bogus RPM\n";
}

open(ZCAT, "|gzip -cd") || die "can't pipe to gzip\n";
print STDERR "CPIO archive found!\n";

print ZCAT $rpm;

while (read($f, ($_=''), 16384) > 0) {
  print ZCAT;
}

close ZCAT;

