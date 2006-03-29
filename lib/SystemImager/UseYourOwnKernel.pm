#  
#   Copyright (C) 2004-2006 Brian Elliott Finley
#
#   $Id$
#    vi: set filetype=perl:
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

package SystemImager::UseYourOwnKernel;

use strict;
our $verbose;


#
# Usage: 
#       SystemImager::UseYourOwnKernel->create_uyok_initrd($arch);
#
sub create_uyok_initrd() {

        my $module      = shift;
        my $arch        = shift;
        my $all_modules = shift;
        $verbose        = shift;

        use File::Copy;
        use File::Basename;
        use File::Path;

        my $cmd;
        my $file;

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
        # Determine module exclusions here.  Jeremy Siadal made the excellent
        # suggestion of explicitly excluding, as opposed to explicitly 
        # including, so that we don't inadvertently exclude some new fancy 
        # module that someone needs. -BEF-
        #
        my $modules_to_exclude = '';
        $file = "/etc/systemimager/UYOK.modules_to_exclude";
        if(!$all_modules and -e $file) {
            #
            # Get list of exclusions from "/etc/systemimager/modules_to_exclude"
            # (that file should live in the "systemimager-common" package)
            #
            open(FILE,"<$file") or die("Couldn't open $file for reading");
                while(<FILE>) {
                    next if(m/^(#|\s|$)/);
                    chomp;
                    $modules_to_exclude .= "--exclude $_ ";
                }
            close(FILE);
        }

        my $uname_r = get_uname_r();
        my $module_paths = `find /lib/modules/$uname_r`;

        #
        # Copy modules
        #
        print ">>> Copying modules to new initrd from: /lib/modules/$uname_r...\n" if( $verbose );
        mkdir("$staging_dir/lib/modules", 0755) or die "$!";
        $cmd = qq(rsync -a --exclude=build --exclude=source $modules_to_exclude /lib/modules/$uname_r $staging_dir/lib/modules/);
        !system( $cmd ) or die( "Couldn't $cmd." );

        #
        # add modules and insmod commands
        #
        my $my_modules_dir = "$staging_dir/my_modules";
        $file = "$my_modules_dir" . "/INSMOD_COMMANDS";
        open( FILE,">>$file" ) or die( "Couldn't open $file for appending" );

        print ">>> Appending insmod commands to ./my_modules_dir/INSMOD_COMMANDS...\n" if( $verbose );
        my @modules = get_load_ordered_list_of_running_modules();
        foreach my $module ( @modules ) {
                print " >> insmod $module\n" if( $verbose );
                print FILE "insmod $1\n";
        }
        close(FILE);

        #
        # Copy over /dev
        #
        print ">>> Copying contents of /dev to new initrd...\n" if( $verbose );
        $cmd = qq(rsync -a /dev/ $staging_dir/dev/);
        !system( $cmd ) or die( "Couldn't $cmd." );

        #
        # Remove LVM device mapper files from $staging_dir/dev
        #
        $cmd = 'vgdisplay -c 2>/dev/null | grep -v ^$';
        open(VG, "$cmd|");
        foreach my $vg_name (<VG>) {
                chomp $vg_name;
                $vg_name =~ s/^\s+//;
                $cmd = "find $staging_dir/dev/ -name \"$vg_name\" -type d | xargs rm -rf";
                !system( $cmd ) or die( "Couldn't $cmd" );
                $cmd = "find $staging_dir/dev/mapper -name \"$vg_name-*\" -type b | xargs rm -f";
                !system( $cmd ) or die( "Couldn't $cmd" );
        }
        close(VG);

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
                print "I couldn't identify your kernel file.  Please try --<some-option-that-needs-to-be-added-XXX>.\n";
                exit 1;
        }

        print ">>> Using kernel from:          $kernel_file\n" if( $verbose );

        my $new_kernel_file = $boot_dir . "/kernel";
        copy($kernel_file, $new_kernel_file) or die("Couldn't copy $kernel_file to $new_kernel_file: $!");
        run_cmd("ls -l $new_kernel_file", $verbose, 1) if($verbose);

        return 1;
}

#
# Usage: my $is_this_file_a_kernel = is_kernel( $kernel );
#
sub is_kernel {

        # The goal here is to make reasonable effort to _eliminate_
        # files that are obviously _not_ kernels.  Any thing that passes
        # the elimination tests we assume is a kernel.
        #
        # Problem with trying to positively identify files that are kernels
        # is that different distros and different archs produce kernels that
        # look different to "file", and we cannot comprehensively know that
        # we've considered all possible resultant strings from kernels.
        #
        # Therefore, we should add elimination tests to this function whenever
        # we get a report of something passing as a kernel, that shouldn't.
        # -BEF-

        my $file = shift;

        #
        # Make sure it's binary
        if( ! -B $file ) { return undef; }
        #
        # and not a directory
        if( -d $file )   { return undef; }

        #
        # Get output from "file" for elimination by identification tests
        my $cmd = "file -b $file";
        open(INPUT,"$cmd|") or die("Couldn't run $cmd to get INPUT");
                my ($input) = (<INPUT>);
                #
                # eliminate vmlinux files on RH
                if( $input =~ m/ELF 32-bit LSB executable,/ ) { return undef; }    
        close(INPUT);

        #
        # If we've made it down to here, then we'll assume it's a kernel. -BEF-
        return 1;
}

#
# Usage:
#       my $kernel_file = _choose_kernel_file( $uname_r );
#
sub _choose_kernel_file($) {

        my $uname_r = shift;
        my @dirs = ('/boot', '/');
        my @kernels;

        foreach my $dir (@dirs) {
                
                # 
                # Check each binary to see if it is a kernel file.  Preference given to the file with
                # the running kernel version, otherwise, the first available good kernel file is used.
                #
                opendir(DIR, $dir) || die("Can't opendir $dir: $!");
                        my @files = readdir(DIR);
                closedir DIR;

                foreach (@files) {
                        my $kernel = $_;
                        my $file = "$dir/$kernel";
                        if ( is_kernel($file) ) {
                                my $kernel_release = _get_kernel_release($file);
                                if ( defined($kernel_release) and ($kernel_release eq $uname_r) ) {
                                        return $file;
                                } else {
                                        push(@kernels, $file);
                                }
                        }
                }

                # If cannot find kernel with name matching running version, return the first good one
                if (@kernels) {
                        return pop(@kernels);
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
                chomp($module_file = `modinfo -F filename $module 2>/dev/null`);
                if ($?) {
                        print STDERR qq(WARNING: Couldn't find module "$module " (skipping it)!\n);
                        next;
                }
                push (@modules, $module_file);
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

        print ">>> Choosing filesystem for new initrd:  $fs\n" if( $verbose );
        print ">>> Creating new initrd from staging dir:  $staging_dir\n" if( $verbose );

        switch ($fs) {
                case 'cramfs'   { _create_initrd_cramfs(   $staging_dir, $boot_dir) }
                case 'ext2'     { _create_initrd_ext2(     $staging_dir, $boot_dir) }
                case 'reiserfs' { _create_initrd_reiserfs( $staging_dir, $boot_dir) }
                case 'jfs'      { _create_initrd_jfs(      $staging_dir, $boot_dir) }
                case 'xfs'      { _create_initrd_xfs(      $staging_dir, $boot_dir) }

                else { die("FATAL: Unable to create initrd using $fs") }
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
        run_cmd("gzip -f -9 -S .img $new_initrd", $verbose);
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
        run_cmd("mkreiserfs -b 512 -q -s $journal_blocks $new_initrd", $verbose);

        # mount
        run_cmd("mount $new_initrd $new_initrd_mount_dir -o loop -t reiserfs", $verbose);

        # copy from staging dir to new initrd
        run_cmd("tar -C $staging_dir -cf - . | tar -C $new_initrd_mount_dir -xf -", $verbose, 0);

        # umount and gzip up
        run_cmd("umount $new_initrd_mount_dir", $verbose);
        run_cmd("gzip -f -9 -S .img $new_initrd", $verbose);
        run_cmd("ls -l $new_initrd.img", $verbose, 1) if($verbose);

        return 1;
}

sub _create_initrd_ext2($$) {

        my $staging_dir = shift;
        my $boot_dir    = shift;

        my $new_initrd  = $boot_dir . "/initrd";

        my $new_initrd_mount_dir = _mk_tmp_dir();

        my $is_mounted = 0;

        # cleanup routine.
        $SIG{__DIE__} = sub {
            my $msg = shift;
            run_cmd("umount $new_initrd_mount_dir", $verbose, 0) if ($is_mounted);
            unlink($new_initrd) if (-f $new_initrd);
            run_cmd("rm -fr $staging_dir $new_initrd_mount_dir", $verbose, 1);
            die $msg;
        };

        print ">>> New initrd mount point:     $new_initrd_mount_dir\n" if($verbose);
        eval { mkpath($new_initrd_mount_dir, 0, 0755) }; 
        if ($@) { 
                die "Couldn't mkpath $new_initrd_mount_dir $@";
        }

        my $cmd;

        # loopback file
        chomp(my $size = `du -ks $staging_dir`);
        $size =~ s/\s+.*$//;
        my $breathing_room = 2000;
        $size = $size + $breathing_room;
        run_cmd("dd if=/dev/zero of=$new_initrd bs=1024 count=$size", $verbose, 1);

        # fs creation
        chomp(my $inodes = `find $staging_dir -printf "%i\n" | sort -u | wc -l`);
        $inodes = $inodes + 10;
        run_cmd("mke2fs -b 1024 -m 0 -N $inodes -F $new_initrd", $verbose, 1);
        run_cmd("tune2fs -i 0 $new_initrd", $verbose, 1);

        # mount
        run_cmd("mount $new_initrd $new_initrd_mount_dir -o loop -t ext2", $verbose);

        # copy from staging dir to new initrd
        run_cmd("tar -C $staging_dir -cf - . | tar -C $new_initrd_mount_dir -xf -", $verbose, 0);

        # umount and gzip up
        run_cmd("umount $new_initrd_mount_dir", $verbose);
        run_cmd("gzip -f -9 -S .img $new_initrd", $verbose);
        run_cmd("ls -l $new_initrd.img", $verbose, 1) if($verbose);

        # cleanup the temporary mount dir
        run_cmd("rm -fr $new_initrd_mount_dir", $verbose, 1);

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
        run_cmd("gzip -f -9 -S .img $new_initrd", $verbose);
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

        print " >> $cmd\n" if($verbose);
        !system($cmd) or die("FAILED: $cmd");
        print "\n" if($add_newline and $verbose);

        return 1;
}


1;

