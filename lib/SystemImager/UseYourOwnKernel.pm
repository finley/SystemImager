#  
#   Copyright (C) 2004-2005 Brian Elliott Finley
#
#   $Id$
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
#
#       2005.02.15  Brian Elliott Finley
#       - added create_uyok_initrd
#       2005.05.15  Brian Elliott Finley
#       - added _record_arch()
#

package SystemImager::UseYourOwnKernel;

use strict;
our $verbose;


#
# Usage: 
#       SystemImager::UseYourOwnKernel->create_uyok_initrd($arch);
#
sub create_uyok_initrd($$) {

        my $module      = shift;
        my $arch        = shift;
        $verbose        = shift;

        use File::Copy;
        use File::Basename;
        use File::Path;

        my $cmd;

        #
        # Create temp dir
        #
        my $staging_dir = _mk_tmp_dir();

        #
        # Copy template over
        #
        $cmd = qq(rsync -a /usr/share/systemimager/boot/$arch/standard/initrd_template/ $staging_dir/);
        !system( $cmd ) or die( "Couldn't $cmd." );

        #
        # add modules and insmod commands
        #
        my $my_modules_dir = "$staging_dir/my_modules";
        my $file = "$my_modules_dir" . "/INSMOD_COMMANDS";
        open( FILE,">>$file" ) or die( "Couldn't open $file for appending" );

        my $uname_r = get_uname_r();
        my $module_paths = `find /lib/modules/$uname_r`;

        my @modules = get_load_ordered_list_of_running_modules();
        foreach( @modules ) {

                $_ =~ s/[-_]/(-|_)/g;      # match against either underscores or hyphens -BEF-

                if( $module_paths =~ m#(.*/$_\.(ko|o))# ) {

                        copy( $1, $my_modules_dir )
                                or die( "Couldn't copy $1 $my_modules_dir" );

                        print "Adding: $1\n" if( $verbose );

                        my $module = basename( $1 );
                        print FILE "insmod $module\n";

                } else {

                        print qq(\nWARNING: Couldn't find module "$_"!\n);
                        print qq(  Hit <Ctrl>+<C> to cancel, or press <Enter> to ignore and continue...\n);
                        <STDIN>;
                }
        }
        close(FILE);

        #
        # Copy over /dev
        #
        $cmd = qq(rsync -a /dev/ $staging_dir/dev/);
        !system( $cmd ) or die( "Couldn't $cmd." );

        # 
        # Dir in which to hold stuff.  XXX dannf where should this really go?
        #
        my $boot_dir = "/etc/systemimager/boot";
        eval { mkpath($boot_dir, 0, 0755) };
        if ($@) {
                print "Couldn't create $boot_dir: $@";
        }

        #
        # Create initrd and save copy of kernel
        #
        _create_new_initrd( $staging_dir, $boot_dir );
        _get_copy_of_kernel( $uname_r, $boot_dir );
        _record_arch( $boot_dir );

        #
        # Remove temp dir
        #
        $cmd = "rm -fr $staging_dir";
        !system( $cmd ) or die( "Couldn't $cmd." );

        return 1;
}


sub _record_arch {

        my $boot_dir = shift;

        my $arch = _get_arch();
        my $file = $boot_dir . "/ARCH";
        open(FILE,">$file") or die("Couldn't open $file for writing $!");
                print FILE "$arch\n";
        close(FILE);

        return 1;
}


#
# Usage: my $arch = get_arch();
#
sub _get_arch {

        use POSIX;

	my $arch = (uname())[4];
	$arch =~ s/i.86/i386/;

	return $arch;
}


sub _get_copy_of_kernel($) {

        my $uname_r     = shift;
        my $boot_dir    = shift;

        my $kernel_file = _choose_kernel_file( $uname_r );
        unless( defined $kernel_file ) {
                print "I couldn't identify your kernel file.  Please try --XXX.\n";
                exit 1;
        }

        my $new_kernel_file = $boot_dir . "/kernel";
        copy($kernel_file, $new_kernel_file) or die("Couldn't copy $kernel_file to $new_kernel_file: $!");
        run_cmd("ls -l $new_kernel_file", $verbose, 1) if($verbose);

        return 1;
}



#
# Usage:
#       my $kernel_file = _choose_kernel_file( $uname_r );
#
sub _choose_kernel_file($) {

        my $uname_r = shift;

        my @dirs = ('/boot', '/');

        foreach my $dir (@dirs) {
                
                # 
                # Check each binary to see if it contains the uname string
                #
                opendir(DIR, $dir) || die("Can't opendir $dir: $!");
                        my @files = readdir(DIR);
                closedir DIR;

                foreach (@files) {

                        my $file = "$dir/$_";
                        next unless( (-B $file) and (! -d $file) );
                        my $kernel_release = _get_kernel_release($file);
                        return $file if( defined($kernel_release) and ($kernel_release eq $uname_r) );
                }
        }

        return undef;
}


#
# Usage:
#       my $uname_r = _get_kernel_release( '/path/to/kernel/file' );
sub _get_kernel_release($) {

        my $file = shift;

        # the default tool
        my $cat = "cat";

        my $cmd = "gzip -l $file >/dev/null 2>&1";
        if( !system($cmd) ) {
                # It's gzip compressed.  Let's decompress it, man.
                $cat = "zcat";
        }

        my $uname_r;
        $cmd = "$cat $file";
        open(IN,"$cmd |") or die("Couldn't $cmd: $!");
                # 
                # Example entries like what we're trying to match against in kernels:
                #       2.6.10bef1 (finley@mantis) #1 Tue Mar 1 00:37:55 CST 2005
                #       2.4.21.SuSE_273.bef1 (root@tg-c025) (gcc version 3.2.2) #1 SMP Mon Jan 24 11:55:28 CST 2005
                #       2.4.24 (root@mantis) #2 Fri Jan 16 19:51:43 CST 2004^
                #       2.4.19-mantis-2002.11.20 (root@mantis) #6 Tue Nov 19 15:15:43 CST 2002
                #       2.6.7-1-686 (dilinger@toaster.hq.voxel.net) #1 Thu Jul 8 05:36:53 EDT 2004
                #
                my $regex = '(2\.[46]\.\d.*) \(.*@.*\) [#]\d+.*\w{3} \w{3} \d{1,2} \d{2}:\d{2}:\d{2} \w{3} \d{4}';
                while(<IN>) {
                       # extract the `uname -r` string from the kernel file
                       if(m/$regex/o) {
                               $uname_r = $1;
                       }
               }
        close(IN);

#       open(FILE,"$file") or die("Couldn't open $file for reading.");
#               while(<FILE>) {
#                       # extract the `uname -r` string from the kernel file
#                       if(m/(2\.[4|6]\.\d{1,2}.*) \(.*\) [#]\d+ \w{3} \w{3} \d+ \d+:\d+:\d+ \w{3} \d+/o) {
#                               $uname_r = $1;
#                       }
#               }
#       close(FILE);

        return $uname_r;
}



#
#       Usage: my $dir = _mk_tmp_dir();
#
sub _mk_tmp_dir() {

        my $count = 0;
        my $dir = "/tmp/.systemimager.";

        until( ! -e "${dir}${count}" ) {
                $count++;
        }
        mkdir("${dir}${count}", 0750) or die "$!";

        return "${dir}${count}";
}


#sub capture_uyok_info_to_autoinstallscript {
#
#        my $module      = shift;
#        my $file        = shift;
#
#        open(FILE,">>$file") or die("Couldn't open $file");
#
#                # initrd kernel
#                my $uname_r = get_uname_r();
#                print FILE qq(  <initrd kernel_version="$uname_r"/>\n) or die($!);
#
#                # initrd fs
#                my $fs = choose_file_system_for_new_initrd();
#                print FILE qq(  <initrd fs="$fs"/>\n) or die($!);
#                print FILE qq(\n) or die($!);
#
#                # initrd modules
#                my @modules = get_load_ordered_list_of_running_modules();
#                my $line = 1;
#                foreach( @modules ) {
#                        print FILE qq(  <initrd load_order="$line"\tmodule="$_"/>\n) or die($!);
#                        $line++;
#                }
#
#
#        close(FILE);
#
#        capture_dev();
#
#        return 1;
#}


sub choose_file_system_for_new_initrd() {

        my @filesystems;
        my $fs;
        my $uname_r = get_uname_r();
        my $modules_dir = "/lib/modules/$uname_r";

        my $file = "/proc/filesystems";
        open(FILESYSTEMS,"<$file") or die("Couldn't open $file for reading.");
        while (<FILESYSTEMS>) {
                chomp;
                push (@filesystems, $_) if (m/(cramfs|ext2|ext3|reiserfs|xfs|jfs)/);
        }
        close(FILESYSTEMS);

        # cramfs
        if ((grep { /cramfs/ } @filesystems) 
                and (! -e "$modules_dir/kernel/fs/cramfs/cramfs.o")
                and (! -e "$modules_dir/kernel/fs/cramfs/cramfs.ko")
                ) { 
                $fs = "cramfs";
        }

        # ext2
        elsif ((grep { /ext2/ } @filesystems) 
                and (! -e "$modules_dir/kernel/fs/ext2/ext2.o")
                and (! -e "$modules_dir/kernel/fs/ext2/ext2.ko")
                ) { 
                $fs = "ext2";
        }

        # ext3
        elsif ((grep { /ext3/ } @filesystems) 
                and (! -e "$modules_dir/kernel/fs/ext3/ext3.o")
                and (! -e "$modules_dir/kernel/fs/ext3/ext3.ko")
                ) { 
                $fs = "ext3";
        }

        # reiserfs
        elsif ((grep { /reiserfs/ } @filesystems) 
                and (! -e "$modules_dir/kernel/fs/reiserfs/reiserfs.o")
                and (! -e "$modules_dir/kernel/fs/reiserfs/reiserfs.ko")
                ) { 
                $fs = "reiserfs";
        }

        # jfs
        elsif ((grep { /jfs/ } @filesystems) 
                and (! -e "$modules_dir/kernel/fs/jfs/jfs.o")
                and (! -e "$modules_dir/kernel/fs/jfs/jfs.ko")
                ) { 
                $fs = "jfs";
        }

        # xfs
        elsif ((grep { /xfs/ } @filesystems) 
                and (! -e "$modules_dir/kernel/fs/xfs/xfs.o")
                and (! -e "$modules_dir/kernel/fs/xfs/xfs.ko")
                ) { 
                $fs = "xfs";
                print "XXX remove this warning line once xfs is tested.\n";
                print "XXX just need to verify where the xfs module lives.\n";
        }

        unless(defined $fs) {

                die("Can't determine the appropriate filesystem to use for an initrd.");
        }

        return $fs;
}


sub get_uname_r {

        #
        # later, deal with this:
        #       
        #    --kernel FILE
        #
        #    identify kernel file
        #    extract uname-r info
        #
        my $kernel_version = `uname -r`;
        chomp $kernel_version;

        return $kernel_version;
}

sub get_load_ordered_list_of_running_modules() {

        my $file = "/proc/modules";
        my @modules;
        open(MODULES,"<$file") or die("Couldn't open $file for reading.");
        while(<MODULES>) {
                my ($module) = split;
                push (@modules, $module);
        }
        close(MODULES);
        
        # reverse order list of running modules
        @modules = reverse(@modules);
        
        return @modules;
}

#sub capture_dev {
#
#        my $file = "/etc/systemimager/my_device_files.tar";
#
#        my $cmd = "tar -cpf $file /dev >/dev/null 2>&1";
#        !system($cmd) or die("Couldn't $cmd");
#
#        $cmd = "gzip --force -9 $file";
#        !system($cmd) or die("Couldn't $cmd");
#        
#        return 1;
#}


sub _create_new_initrd($$) {

        my $staging_dir = shift;
        my $boot_dir = shift;

        use Switch; 

        my $fs = choose_file_system_for_new_initrd();

        if($fs eq "ext3") { 
                # use ext2 as the filesystem (same as ext3, but no journal)
                $fs = "ext2";
        }   

        print ">>> Filesystem for new initrd:  $fs\n" if( $verbose );
        print ">>> Creating new initrd from:   $staging_dir\n" if( $verbose );

        switch ($fs) {                                                                      # Sizes from a sample run with the same data
                case 'cramfs'   { _create_initrd_cramfs(   $staging_dir, $boot_dir) }       # 1107131 bytes
                case 'ext2'     { _create_initrd_ext2(     $staging_dir, $boot_dir) }       # 1011284 bytes
                case 'reiserfs' { _create_initrd_reiserfs( $staging_dir, $boot_dir) }       # 1036832 bytes
                case 'jfs'      { _create_initrd_jfs(      $staging_dir, $boot_dir) }       # 1091684 bytes
                case 'xfs'      { _create_initrd_xfs(      $staging_dir, $boot_dir) }       # untested XXX
                else            { die("FATAL: Unable to create initrd using $fs") }
        }

        return 1;
}

sub _create_initrd_cramfs($$) {

        my $staging_dir = shift;
        my $boot_dir    = shift;

        my $new_initrd  = $boot_dir . "/initrd";

        # initrd creation
        my $mkfs;
        if (`which mkcramfs`) {
            $mkfs = 'mkcramfs';
        } elsif (`which mkfs.cramfs`) {
            $mkfs = 'mkfs.cramfs';
        } else {
            die "error: cannot find a valid utility to create cramfs initrd!\n";
        }
        run_cmd("$mkfs $staging_dir $new_initrd", $verbose, 1);

        # gzip up
        run_cmd("gzip -9 -S .img $new_initrd", $verbose);
        run_cmd("ls -l $new_initrd.img", $verbose, 1) if($verbose);

        return 1;
}

sub _create_initrd_reiserfs($$) {

        my $staging_dir = shift;
        my $boot_dir    = shift;

        my $new_initrd  = $boot_dir . "/initrd";

        my $new_initrd_mount_dir = _mk_tmp_dir();
        print ">>> New initrd mount point:     $new_initrd_mount_dir\n" if($verbose);
        eval { mkpath($new_initrd_mount_dir, 0, 0755) }; 
        if( $@ ) { 
                die "Couldn't mkpath $new_initrd_mount_dir $@";
        }

        my $cmd;

        # loopback file
        chomp(my $size = `du -ks $staging_dir`);
        $size =~ s/\s+.*$//;
        my $journal_blocks = 513;               # minimum journal size in blocks
        my $journal_size = $journal_blocks * 4; # journal size in blocks * block size in kilobytes
        my $breathing_room = 100;
        $size = $size + $journal_size + $breathing_room;
        run_cmd("dd if=/dev/zero of=$new_initrd bs=1024 count=$size", $verbose, 1);

        # fs creation
        run_cmd("mkreiserfs -q -s $journal_blocks $new_initrd", $verbose);

        # mount
        run_cmd("mount $new_initrd $new_initrd_mount_dir -o loop -t reiserfs", $verbose);

        # copy from staging dir to new initrd
        run_cmd("tar -C $staging_dir -cf - . | tar -C $new_initrd_mount_dir -xf -", $verbose, 0);

        # umount and gzip up
        run_cmd("umount $new_initrd_mount_dir", $verbose);
        run_cmd("gzip -9 -S .img $new_initrd", $verbose);
        run_cmd("ls -l $new_initrd.img", $verbose, 1) if($verbose);

        return 1;
}

sub _create_initrd_ext2($$) {

        my $staging_dir = shift;
        my $boot_dir    = shift;

        my $new_initrd  = $boot_dir . "/initrd";

        my $new_initrd_mount_dir = _mk_tmp_dir();
        print ">>> New initrd mount point:     $new_initrd_mount_dir\n" if($verbose);
        eval { mkpath($new_initrd_mount_dir, 0, 0755) }; 
        if ($@) { 
                die "Couldn't mkpath $new_initrd_mount_dir $@";
        }

        my $cmd;

        # loopback file
        chomp(my $size = `du -ks $staging_dir`);
        $size =~ s/\s+.*$//;
        my $breathing_room = 100;
        $size = $size + $breathing_room;
        run_cmd("dd if=/dev/zero of=$new_initrd bs=1024 count=$size", $verbose, 1);

        # fs creation
        chomp(my $inodes = `find $staging_dir -printf "%i\n" | sort -u | wc -l`);
        $inodes = $inodes + 10;
        run_cmd("mke2fs -m 0 -N $inodes -F $new_initrd", $verbose, 1);

        # mount
        run_cmd("mount $new_initrd $new_initrd_mount_dir -o loop -t ext2", $verbose);

        # copy from staging dir to new initrd
        run_cmd("tar -C $staging_dir -cf - . | tar -C $new_initrd_mount_dir -xf -", $verbose, 0);

        # umount and gzip up
        run_cmd("umount $new_initrd_mount_dir", $verbose);
        run_cmd("gzip -9 -S .img $new_initrd", $verbose);
        run_cmd("ls -l $new_initrd.img", $verbose, 1) if($verbose);

        return 1;
}

sub _create_initrd_xfs($$) {

        my $staging_dir = shift;
        my $boot_dir    = shift;

        my $new_initrd  = $boot_dir . "/initrd";

        my $new_initrd_mount_dir = _mk_tmp_dir();
        print ">>> New initrd mount point:     $new_initrd_mount_dir\n" if($verbose);
        eval { mkpath($new_initrd_mount_dir, 0, 0755) }; 
        if ($@) { 
                die "Couldn't mkpath $new_initrd_mount_dir $@";
        }

        print "\nPlease fill in this subroutine, _create_initrd_xfs(), and email the patch!\n\n";
        exit 1;
}

sub _create_initrd_jfs($$) {

        my $staging_dir = shift;
        my $boot_dir    = shift;

        my $new_initrd  = $boot_dir . "/initrd";

        my $cmd;

        my $new_initrd_mount_dir = _mk_tmp_dir();
        print ">>> New initrd mount point:     $new_initrd_mount_dir\n" if($verbose);
        eval { mkpath($new_initrd_mount_dir, 0, 0755) }; 
        if ($@) { 
                die "Couldn't mkpath $new_initrd_mount_dir $@";
        }

        # loopback file
        chomp(my $size = `du -ks $staging_dir`);
        $size =~ s/\s+.*$//;
        my $breathing_room = 3072;      # We may need to tweak this -- not for size(<), but for size(>). -BEF-
        $size = $size + $breathing_room;
        #
        # jfs_mkfs farts on you with an "Partition must be at least 16 megabytes."
        # if you try to use anything smaller.  However, because this is before we
        # compress the initrd, it results in suprisingly little increase in the 
        # size of the resultant initrd.
        #
        my $min_jfs_fs_size = 16384;    
        if($size < $min_jfs_fs_size) { $size = $min_jfs_fs_size; }
        run_cmd("dd if=/dev/zero of=$new_initrd bs=1024 count=$size", $verbose, 1);

        # fs creation
        run_cmd("jfs_mkfs -q $new_initrd", $verbose);

        # mount
        run_cmd("mount $new_initrd $new_initrd_mount_dir -o loop -t jfs", $verbose);

        # copy from staging dir to new initrd
        run_cmd("tar -C $staging_dir -cf - . | tar -C $new_initrd_mount_dir -xf -", $verbose, 0);

        # umount and gzip up
        run_cmd("umount $new_initrd_mount_dir", $verbose);
        run_cmd("gzip -9 -S .img $new_initrd", $verbose);
        run_cmd("ls -l $new_initrd.img", $verbose, 1) if($verbose);

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
sub run_cmd($$$) {

        my $cmd = shift;
        my $add_newline = shift;

        #if(!$verbose) {
        #        $cmd .= " >/dev/null 2>/dev/null";
        #}

        print ">>> $cmd\n" if($verbose);
        !system($cmd) or die("FAILED: $cmd");
        print "\n" if($add_newline and $verbose);

        return 1;
}


1;

# /* vi: set ai et ts=8: */
