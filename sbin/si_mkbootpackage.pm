#!/usr/bin/perl -w
#
#  Copyright (C) 2003-2004 Brian Elliott Finley
#
#  $Id$
# 
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
# 
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
# 
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

# 2004.03.15 Brian Elliott Finley
# - Specify destination kernel name as 'kernel'.  Bug found by Thomas 
#   Naughton.

#
# TODO: 
# - update FLAVOR string in initrd.img/etc/init.d/functions
# - deal with FLAVOR via DHCP and/or net boot loader config files
# - need to libraryize all subroutines
# - need to manpageize --help
#

# XXX use lib "USR_PREFIX/lib/systemimager/perl";
use lib "/usr/lib/systemimager/perl";
print "WARNING: si_mkbootpackage is currently considered an experimental tool.\n";
print "         \"Your Mileage May Vary\"\n";

use strict;
use File::Path;
use Getopt::Long;
use SystemImager::Common;

# set path for system calls
$ENV{PATH} = "/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin";

our %opt;

GetOptions( 
        "help"          => \$opt{help},
        "version"       => \$opt{version},
        "verbose|v"     => \$opt{v},
        "kernel=s"      => \$opt{kernel},
        "modules-dir=s" => \$opt{modules_dir},
        "from-flavor=s" => \$opt{from_flavor},
        "new-flavor=s"  => \$opt{new_flavor},
        "filesystem|fs=s"  => \$opt{fs},
        "arch=s"        => \$opt{arch},
        "modules=s"     => \$opt{modules},
) or usage() and exit(1);

if($opt{help}) { 
        usage() and exit(0);
}

if($opt{version}) { 
        version() and exit(0); 
}

SystemImager::Common->check_if_root();

if(!$opt{kernel}) { 
        usage();
        print "Hint: Try the --kernel option.\n\n";
        exit(1);
}

if(!$opt{new_flavor}) { 
        usage();
        print "Hint: Try the --flavor option.\n\n";
        exit(1);
}

if(!$opt{v}) {
        $opt{v} = 0;
}

if(! -e $opt{kernel}) {
        die "$opt{kernel} doesn't exist.\n";
}

if(!$opt{modules_dir}) {
        $opt{uname_r} = get_kernel_release();
        if(!$opt{uname_r}) {
                print "Failed to determine kernel release from kernel file.\n";
                print "Hint: Try the --modules-dir option.\n";
                exit 1;
        }

        $opt{modules_dir} = "/lib/modules/$opt{uname_r}";
}
print ">>> Kernel release:             $opt{uname_r}\n" if($opt{v});
print ">>> Using modules from:         $opt{modules_dir}\n" if($opt{v});

if(!$opt{arch}) {
        $opt{arch} = get_arch();
}
print ">>> Using architecture:         $opt{arch}\n" if($opt{v});

# set tmp dir for mucking about with files
$opt{tmp_dir} = mk_tmp_dir();
print ">>> Base temporary dir:         $opt{tmp_dir}\n" if($opt{v});

# our new initrd file
$opt{new_initrd}        = $opt{tmp_dir} . "/initrd";
$opt{new_initrd_dir}    = $opt{tmp_dir} . "/new_initrd_dir";
$opt{staging_dir}       = $opt{tmp_dir} . "/staging_dir";

# old initrd file
$opt{old_initrd}        = $opt{tmp_dir} . "/old_initrd";
$opt{old_initrd_dir}    = $opt{tmp_dir} . "/old_initrd_dir";

if(!$opt{from_flavor}) { $opt{from_flavor} = "standard"; }

&extract_initrd;
&copy_new_modules;
&create_new_initrd;
&create_new_boel_binaries_tarball;
&copy_into_place;
rmtree $opt{tmp_dir};

exit 0;



##########################
# 
# Subroutines
#
sub create_new_boel_binaries_tarball
{
        my $from_tarball = "/usr/share/systemimager/boot/" . $opt{arch} . "/" . $opt{from_flavor} . "/boel_binaries.tar.gz";

        my $d = "$opt{tmp_dir}/boel";
        eval { mkpath($d, 0, 0755) }; if ($@) { die("Couldn't mkpath $d $@"); }
        run_cmd("tar -C $d -xzf $from_tarball", $opt{v});

        $d = "$opt{tmp_dir}/boel/lib/modules";
        rmtree $d;
        eval { mkpath($d, 0, 0755) }; if ($@) { die("Couldn't mkpath $d $@"); }

        run_cmd("rsync -a $opt{modules_dir}/ $d/", $opt{v});
        run_cmd("tar -C $opt{tmp_dir}/boel -czf $opt{tmp_dir}/boel_binaries.tar.gz .", $opt{v});
}

sub copy_into_place
{
        use File::Copy;

        my $d = "/usr/share/systemimager/boot/" . $opt{arch} . "/" .  $opt{new_flavor};
        eval { mkpath($d, 0, 0755) }; if ($@) { die("Couldn't mkpath $d $@"); }

        print ">>> Copying $opt{kernel} to:  $d\n" if($opt{v});
        copy("$opt{kernel}", "${d}/kernel") or die("Couldn't copy $opt{kernel} to ${d}/kernel");

        print ">>> Copying $opt{new_initrd}.img to:  $d\n" if($opt{v});
        copy("$opt{new_initrd}.img", "${d}/") or die("Couldn't copy $opt{new_initrd} to $d");

        print ">>> Copying $opt{tmp_dir}/boel_binaries.tar.gz to:  $d\n" if($opt{v});
        copy("$opt{tmp_dir}/boel_binaries.tar.gz", "${d}/") or die("Couldn't copy $opt{tmp_dir}/boel_binaries.tar.gz to $d");

        run_cmd("ls -l $d", $opt{v}, 1);

        print "Finished!  Your new boot package lives in:\n\n";
        print "  $d\n\n";
}

sub mk_tmp_dir
{
        my $d;

        $d = "/tmp/si";
        until(! -e $d) { $d = $d . $$; }
        eval { mkpath($d, 0, 0755) }; if ($@) { die("Couldn't mkpath $d $@"); }

        return $d;
}

sub get_arch
{
        use POSIX qw(uname);

        my $arch = (uname())[4];
        $arch =~ s/i.86/i386/;

        return $arch;
}

sub create_new_initrd
{
        use Switch; 

        unless ($opt{fs}) { $opt{fs} = choose_file_system_for_new_initrd(); }

        if($opt{fs} eq "ext3") { 
                # use ext2 as the filesystem (same as ext3, but no journal)
                $opt{fs} = "ext2";
        }   

        unless($opt{fs} eq 'cramfs') {
                print ">>> New initrd mount point:     $opt{new_initrd_dir}\n" if($opt{v});
                eval { mkpath($opt{new_initrd_dir}, 0, 0755) }; if ($@) { die "Couldn't mkpath $opt{new_initrd_dir} $@"; }
        }

        print ">>> Filesystem for new initrd:  $opt{fs}\n" if($opt{v});
        print ">>> Creating new initrd from:   $opt{staging_dir}\n" if($opt{v});

        # Sean Dague's little jewel that helps keep the size down. -BEF-
        run_cmd("find $opt{staging_dir} -depth -exec touch -t 196912311900 '{}' ';'");

        switch ($opt{fs}) {                                             # Sizes from a sample run with the same data
                case 'cramfs'   { create_initrd_cramfs()        }       # 1107131 bytes
                case 'ext2'     { create_initrd_ext2()          }       # 1011284 bytes
                case 'reiserfs' { create_initrd_reiserfs()      }       # 1036832 bytes
                case 'jfs'      { create_initrd_jfs()           }       # 1091684 bytes
                case 'xfs'      { create_initrd_xfs()           }       # untested XXX
                else            { die("FATAL: Unable to create initrd using $opt{fs}") }
        }

        return 1;
}

sub create_initrd_reiserfs
{
        my $cmd;

        # loopback file
        chomp(my $size = `du -ks $opt{staging_dir}`);
        $size =~ s/\s+.*$//;
        my $journal_blocks = 513;               # minimum journal size in blocks
        my $journal_size = $journal_blocks * 4; # journal size in blocks * block size in kilobytes
        my $breathing_room = 100;
        $size = $size + $journal_size + $breathing_room;
        run_cmd("dd if=/dev/zero of=$opt{new_initrd} bs=1024 count=$size", $opt{v}, 1);

        # fs creation
        run_cmd("mkreiserfs -q -s $journal_blocks $opt{new_initrd}", $opt{v});

        # mount
        run_cmd("mount $opt{new_initrd} $opt{new_initrd_dir} -o loop -t $opt{fs}", $opt{v});

        # copy from staging dir to new initrd
        #my $v = '';
        #$v = "v" if($opt{v}); 
        run_cmd("tar -C $opt{staging_dir} -cf - . | tar -C $opt{new_initrd_dir} -xf -", $opt{v}, 0);

        # umount and gzip up
        run_cmd("umount $opt{new_initrd_dir}", $opt{v});
        run_cmd("gzip -9 -S .img $opt{new_initrd}", $opt{v});
        run_cmd("ls -l $opt{new_initrd}.img", $opt{v}, 1) if($opt{v});

        return 1;
}

sub create_initrd_ext2
{
        my $cmd;

        # loopback file
        chomp(my $size = `du -ks $opt{staging_dir}`);
        $size =~ s/\s+.*$//;
        my $breathing_room = 100;
        $size = $size + $breathing_room;
        run_cmd("dd if=/dev/zero of=$opt{new_initrd} bs=1024 count=$size", $opt{v}, 1);

        # fs creation
        chomp(my $inodes = `find $opt{staging_dir} -printf "%i\n" | sort -u | wc -l`);
        $inodes = $inodes + 10;
        run_cmd("mke2fs -m 0 -N $inodes -F $opt{new_initrd}", $opt{v}, 1);

        # mount
        run_cmd("mount $opt{new_initrd} $opt{new_initrd_dir} -o loop -t $opt{fs}", $opt{v});

        # copy from staging dir to new initrd
        run_cmd("tar -C $opt{staging_dir} -cf - . | tar -C $opt{new_initrd_dir} -xf -", $opt{v}, 0);

        # umount and gzip up
        run_cmd("umount $opt{new_initrd_dir}", $opt{v});
        run_cmd("gzip -9 -S .img $opt{new_initrd}", $opt{v});
        run_cmd("ls -l $opt{new_initrd}.img", $opt{v}, 1) if($opt{v});

        return 1;
}

sub create_initrd_cramfs
{
        my $cmd;

        # initrd creation
        run_cmd("mkcramfs $opt{staging_dir} $opt{new_initrd}", $opt{v}, 1);

        # gzip up
        run_cmd("gzip -9 -S .img $opt{new_initrd}", $opt{v});
        run_cmd("ls -l $opt{new_initrd}.img", $opt{v}, 1) if($opt{v});

        return 1;
}

sub create_initrd_xfs
{
        print "\nPlease fill in this subroutine, create_initrd_xfs(), and submit the patch!\n\n";
        exit 1;
}

sub create_initrd_jfs
{
        my $cmd;

        # loopback file
        chomp(my $size = `du -ks $opt{staging_dir}`);
        $size =~ s/\s+.*$//;
        my $breathing_room = 100;
        $size = $size + $breathing_room;
        #
        # jfs_mkfs farts on you with an "Partition must be at least 16 megabytes."
        # if you try to use anything smaller.  However, because this is before we
        # compress the initrd, it results in suprisingly little increase in the 
        # size of the resultant initrd.
        #
        my $min_jfs_fs_size = 16384;    
        if($size < $min_jfs_fs_size) { $size = $min_jfs_fs_size; }
        run_cmd("dd if=/dev/zero of=$opt{new_initrd} bs=1024 count=$size", $opt{v}, 1);

        # fs creation
        run_cmd("jfs_mkfs -q $opt{new_initrd}", $opt{v});

        # mount
        run_cmd("mount $opt{new_initrd} $opt{new_initrd_dir} -o loop -t $opt{fs}", $opt{v});

        # copy from staging dir to new initrd
        run_cmd("tar -C $opt{staging_dir} -cf - . | tar -C $opt{new_initrd_dir} -xf -", $opt{v}, 0);

        # umount and gzip up
        run_cmd("umount $opt{new_initrd_dir}", $opt{v});
        run_cmd("gzip -9 -S .img $opt{new_initrd}", $opt{v});
        run_cmd("ls -l $opt{new_initrd}.img", $opt{v}, 1) if($opt{v});

        return 1;
}

#
# Usage:  
#       run_cmd("my shell command", 1, 1);
#
#       First argument:  the "command" to run.
#           Required.
#
#       Second argument: '1' to print command before running.
#           Defaults to "off".
#
#       Third argument:  '1' to print a newline after the command.
#           Defaults to "off".
#
sub run_cmd
{
        my $cmd = shift;
        my $verbose = shift;
        my $add_newline = shift;

        if(!$verbose) {
                $cmd .= " >/dev/null 2>/dev/null";
        }

        print ">>> $cmd\n" if($verbose);
        !system($cmd) or die("FAILED: $cmd");
        print "\n" if($add_newline and $verbose);

        return 1;
}

sub copy_new_modules
{
        use File::Find;

        my @modules;

        # rm modules in initrd_dir
        print ">>> Removing old modules from:  $opt{staging_dir}/my_modules\n" if($opt{v});
        unlink <$opt{staging_dir}/*.o>;

        # read in current INSMOD_COMMANDS file
        my $file = "$opt{staging_dir}/my_modules/INSMOD_COMMANDS";
        my @new_file;
        open(FILE,"<$file") or die("Couldn't open $file for reading.");
        while(<FILE>) {
                push (@new_file, $_) if (m/^#/);
        }
        close(FILE);

        if($opt{modules}) {
                print "$opt{modules}\n";
                @modules = split(/\s+/, $opt{modules});
        } else {
                @modules = get_load_ordered_list_of_running_modules();
        }

        # do copy
        foreach (@modules) {
                run_cmd("find $opt{modules_dir} -name ${_}.o -exec cp '{}' $opt{staging_dir}/my_modules/ ';'",$opt{v},0);
        }

        # add insmod commands
        print ">>> Updating insmod commands:   $opt{staging_dir}/my_modules/INSMOD_COMMANDS\n" if($opt{v});
        foreach (@modules) {
                push (@new_file, "insmod ${_}.o\n");
        }

        # write out the new file
        open(FILE,">$file") or die("Couldn't open $file for writing.");
                print FILE @new_file;
        close(FILE);

}

sub get_load_ordered_list_of_running_modules
{
        # get ordered list of running modules
        my $file = "/proc/modules";
        my @modules;
        open(FILE,"<$file") or die("Couldn't open $file for reading.");
        while(<FILE>) {
                my ($module) = split;
                push (@modules, $module);
        }
        close(FILE);

        # reverse order list of running modules
        @modules = reverse @modules;

        return @modules;
}

sub extract_initrd
{
        my $cmd;

        # initrd to copy from (as a starting point)
        $opt{source_initrd} = "/usr/share/systemimager/boot/" . $opt{arch} . "/" . $opt{from_flavor} . "/initrd.img";

        # de-compress old initrd
        copy("$opt{source_initrd}", "$opt{old_initrd}.gz") or die("Couldn't copy $opt{source_initrd} to $opt{old_initrd}.gz");
        run_cmd("gunzip $opt{old_initrd}.gz", $opt{v});

        # make old initrd dir
        print ">>> Old initrd mount point:     $opt{old_initrd_dir}\n" if($opt{v});
        eval { mkpath($opt{old_initrd_dir},0,0755) };
        if ($@) { die "Couldn't mkpath $opt{old_initrd_dir} $@"; }

        # mount old initrd
        run_cmd("mount $opt{old_initrd} $opt{old_initrd_dir} -o loop", $opt{v});

        # make new initrd dir
        print ">>> New initrd temporary dir:   $opt{staging_dir}\n" if($opt{v});
        eval { mkpath($opt{staging_dir}, 0, 0755) };
        if ($@) { die "Couldn't mkpath $opt{staging_dir} $@"; }

        # copy stuff to new initrd dir
        run_cmd("rsync -aHS --exclude=lost+found/ --numeric-ids $opt{old_initrd_dir}/ $opt{staging_dir}/", $opt{v});

        # umount old initrd
        run_cmd("umount $opt{old_initrd_dir}", $opt{v});
}

sub get_hash_of_running_filesystems
{
        my %filesystems;

        # get hash of running filesystems
        my $file = "/proc/filesystems";
        open(FILE,"<$file") or die("Couldn't open $file for reading.");
        while (<FILE>) {
                chomp;

                # remove everything from each line, except for the filesystem name
                s/^.*\s(\S+)$/$1/;

                ( $filesystems{$_} = $_ ) if (m/(cramfs|ext2|ext3|reiserfs|xfs|jfs)/);
        }
        close(FILE);

        return %filesystems;
}

sub choose_file_system_for_new_initrd
{
        # get list of running filesystems
        my %filesystems = get_hash_of_running_filesystems();

        # get list of running modules
        my @modules = get_load_ordered_list_of_running_modules();
         
        # remove modular filesystems from hash
        foreach my $module (@modules) {
            if($filesystems{$module}) {
                delete $filesystems{$module};
            }
        }

        # Choose filesystem to use, from remaining filesystems (those 
        # compiled directly into the kernel), in order of preference.

        return "cramfs"     if ($filesystems{cramfs});
        return "ext2"       if ($filesystems{ext2});
        return "ext3"       if ($filesystems{ext3});
        return "reiserfs"   if ($filesystems{reiserfs});
        return "jfs"        if ($filesystems{jfs});
        return "xfs"        if ($filesystems{xfs});

        # if we made it down to here, then we didn't find any valid filesystem
        return undef;
}

sub get_kernel_release
{
        my $file = $opt{kernel};
        my $uname_r;
        open(FILE,"$file") or die("Couldn't open $file for reading.");
        while(<FILE>) {
                # extract the `uname -r` string from the kernel file
                if(m/(2\.[4|6]\.\d{1,2}.*) \(.*\) [#]\d+ \w{3} \w{3} \d+ \d+:\d+:\d+ \w{3} \d+/o) {
                        $uname_r = $1;
                }
        }
        close(FILE);

        return $uname_r;
}

sub usage
{
        print <<EOF;

Usage: si_mkbootpackage --kernel FILE --flavor NAME [OPTION]...

Description: 
        Takes the kernel specified, and necessary modules from it, and creates
        a new boot package based on said kernel.  The resultant files include
        a matched kernel, initrd.img, and boel_binaries.tar.gz that can be 
        used as the SystemImager autoinstall client software.

Current Assumptions:
        You are running this command on your imageserver.  Maybe others...

Options: (options can be presented in any order)

 --help
        Display this output.

 --version
        Display version and copyright information.

 --verbose
        Show information and output for almost every step.  Highly 
        recommended for learning and/or troubleshooting.
                         
 --kernel FILE
        Path to the kernel you want to use.

        Required.

 --new-flavor FLAVOR  
        What do you want to call this new new boot package.  For example, if
        your flavor is "gentoo1", then your boot package will end up living 
        in a directory such as: "/usr/share/systemimager/boot/i386/gentoo1".

        Required.

 --from-flavor FLAVOR  
        Copy the SystemImager initrd.img and boel_binaries.tar.gz of flavor 
        "FLAVOR" and use them as the base for your new boot package.  All 
        modules and module information in the source files will be removed,
        and will be replaced with your new modules (if any).

        Default:
        The "standard" flavor initrd for your architecture.  For example, on an
        x86 machine this would be:

                /usr/share/systemimager/boot/i386/standard/initrd.img

 --modules "MODULE1 MODULE2 etc..."
        It is recommended that you first try letting the system choose your
        modules for you (the Default), and that you only use this option if
        the system fails to choose successfully.

        That being said, this option allows you to specify a list of modules
        to load from the initrd.img at boot time, in the order you want them
        loaded.  Essential modules to place here include any modules needed to
        access the network.  You need not include any disk related drivers,
        unless they are required to read a local.cfg file from the floppy or 
        hard disk drive(s).

        Default:
        If --modules is not specified, then we try to learn which modules you
        need based on what is currently running on your system.  To do this, we
        get a list of all running modules from "/proc/modules".  All running 
        modules will be used.  Modules will be loaded in the order that you see
        when you do a "cat /proc/modules | tac".

 --filesystem,--fs FILESYSTEM
        Filesystem that you want used on the initrd.img.  The initrd.img is 
        made with a filesystem driver compiled into the kernel (not a module),
        and may be one of cramfs, ext2, ext3, reiserfs, jfs, or xfs.

        Default:
        An appropriate filesystem will be chosen automatically.

 --modules-dir DIR
        Path to your kernel's modules directory.  These modules must be the
        ones that match your kernel.  
        
        Default:
        /lib/modules/`uname -r`
                

Download, report bugs, and submit patches at:
http://systemimager.org/

EOF
}
