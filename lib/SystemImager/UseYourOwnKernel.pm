#  
#   Copyright (C) 2004 Brian Elliott Finley
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

package SystemImager::UseYourOwnKernel;

use strict;
sub capture_uyok_info_to_autoinstallscript {

        my $module      = shift;
        my $file        = shift;

        open(FILE,">>$file") or die("Couldn't open $file");

                # initrd kernel
                my $uname_r = get_uname_r();
                print FILE qq(  <initrd kernel_version="$uname_r"/>\n) or die($!);

                # initrd fs
                my $fs = choose_file_system_for_new_initrd();
                print FILE qq(  <initrd fs="$fs"/>\n) or die($!);
                print FILE qq(\n) or die($!);

                # initrd modules
                my @modules = get_load_ordered_list_of_running_modules();
                my $line = 1;
                foreach(@modules) {
                        print FILE qq(  <initrd load_order="$line"\tmodule="$_"/>\n) or die($!);
                        $line++;
                }


        close(FILE);

        capture_dev();

        return 1;
}


sub choose_file_system_for_new_initrd
{
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

sub get_load_ordered_list_of_running_modules {

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

sub capture_dev {

        my $file = "/etc/systemimager/my_device_files.tar";

        my $cmd = "tar -cpf $file /dev >/dev/null 2>&1";
        !system($cmd) or die("Couldn't $cmd");

        $cmd = "gzip --force -9 $file";
        !system($cmd) or die("Couldn't $cmd");
        
        return 1;
}

1;

# /* vi: set et ts=8: */
