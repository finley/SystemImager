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

                my $kernel_version = get_kernel_version();
                print FILE qq(  <kernel version="$kernel_version"/>\n\n);

                my @modules = get_load_ordered_list_of_running_modules();
                my $line = 1;
                foreach(@modules) {
                        print FILE qq(  <modules order="$line"\tname="$_"/>\n);
                        $line++;
                }

        close(FILE);

        capture_dev();

        return 1;
}

# save ordered list of modules to autoinstallscript.conf

#if($opt{fs}) {
#    # get list of running filesystems
#    my %filesystems = get_hash_of_running_filesystems();
#
#    if( (grep(/$opt{fs}/, @modules) and ($filesystems{$opt{fs}}) ) {
#        then we can use it. XXXXX
#    }
#
#    # see if user specified fs is available as compiled into kernel
#    if(! $non_module_filesystems{$opt{fs}}) {
#        print "Filesystem $opt{fs} doesn't appear to be compiled into $opt{kernel}\n";
#    }
#} else {
#    $opt{fs} = choose_file_system_for_new_initrd()
#        or die("Couldn't choose_file_system_for_new_initrd()");
#  }
#}
##XXX record preferred fs for initrd in autoinstallscript.conf
#
#
#

sub get_kernel_version {

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


#sub get_hash_of_running_filesystems {
#}
#
#sub choose_file_system_for_new_initrd {
#}
#
#sub check_for_fs_as_module {
#}
#
#sub check_for_fs_in_kernel {
#}

sub capture_dev {

        my $file = "/etc/systemimager/my_device_files.tar";

        my $cmd = "tar -cpf $file /dev >/dev/null 2>&1";
        !system($cmd) or die("Couldn't $cmd");

        my $cmd = "gzip --force -9 $file";
        !system($cmd) or die("Couldn't $cmd");
        
        return 1;
}

1;

# /* vi: set et ts=8: */
