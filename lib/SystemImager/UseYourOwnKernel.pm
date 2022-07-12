#  
#    vi:set filetype=bash et ts=4:
#
#    This file is part of SystemImager.
#
#    SystemImager is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    SystemImager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with SystemImager. If not, see <https://www.gnu.org/licenses/>.
#
#    Copyright (C) 2004-2006 Brian Elliott Finley
#

package SystemImager::UseYourOwnKernel;

use strict;
use File::Basename;
use File::Glob;
use SystemImager::JConfig qw($jconfig);

our $verbose;
our $is_mounted = 0;
our $fs_regexp = "(cramfs|ext2|ext3|reiserfs|xfs|btrfs|jfs|cpio)";

#
# Usage: 
#       SystemImager::UseYourOwnKernel->create_uyok_initrd(
#           $my_modules, $custom_kernel, $kernel_version,
#           $custom_mod_dir, $image, $destination, $ssh_key,
#           $authorized_keys, $local_cfg,
#           $firmware_dir, $dracut_opts, $verbose);
#
sub create_uyok_initrd() {

	my $perl_package    = shift;
        my $my_modules      = shift;
        my $custom_kernel   = shift;
	my $kernel_version  = shift;
        my $custom_mod_dir  = shift;
        my $image           = shift;
        my $destination     = shift;
        my $ssh_key         = shift;
        my $authorized_keys = shift;
        my $local_cfg       = shift;
        my $firmware_dir    = shift;
	my $dracut_opts     = shift;
        $verbose            = shift;

        use File::Copy;
        use File::Basename;
        use File::Path;

        my $cmd;
        my $file;

        #
        # Create temp dir
        #
        my $staging_dir = _mk_tmp_dir();
	my $staging_dir_option = "";

        # Set the cleanup handler.
        $SIG{__DIE__} = sub {
            my $msg = shift;
            if ($staging_dir) {
                if ($staging_dir =~ m/^\/tmp\/\.systemimager\.[0-9]+$/) {
                    system("rm -rf $staging_dir");
                }
            }
            die $msg;
        };

        # Detect the kernel release.
        my $uname_r;
	my $config_r;
        if ($custom_kernel) {
            $uname_r = _get_kernel_release($custom_kernel);
        } elsif ($kernel_version) {
		$uname_r=$kernel_version;
	} elsif ($image) {
            # Get SystemImager directories.
            my $image_dir = $jconfig->get('imager','images_dir');

            unless (-d "$image_dir/$image") {
                print STDERR "error: $image is not a valid image! use si_lsimage to see the list of available images.\n";
                print STDERR "Remember: the option --image can be used only on the image server.\n";
                exit(1);
            }

            # Autodetect custom kernel and modules directory in the image.
            $custom_kernel = _choose_kernel_file( '', "$image_dir/$image" );
            $uname_r = _get_kernel_release($custom_kernel);
            $custom_mod_dir = "$image_dir/$image/lib/modules/$uname_r";
        } else {
            $uname_r = get_uname_r();
        }

	#
	# Handle the --my-modules options (only use modules necesssary to boot this host)
	#
        my $module_dir;
        if ($custom_mod_dir) {
            $module_dir = $custom_mod_dir;
        } else {
            $module_dir = "/lib/modules/$uname_r" unless ($custom_kernel);
        }

	#
	#
	#
	my $extra_firmwares="";
	if ($firmware_dir) {
	    $extra_firmwares=" --fwdir $firmware_dir";
	}
        #
        # Determine module exclusions here.  Jeremy Siadal made the excellent
        # suggestion of explicitly excluding, as opposed to explicitly 
        # including, so that we don't inadvertently exclude some new fancy 
        # module that someone needs. -BEF-
        #
        my $modules_to_exclude = '';
        $file = "/etc/systemimager"."/UYOK.modules_to_exclude";
        if(-e $file) {
            #
            # Get list of exclusions from "/etc/systemimager/UYOK.modules_to_exclude"
            # (that file should live in the "systemimager-common" package)
            #
            open(FILE,"<$file") or die("Couldn't open $file for reading");
                while(<FILE>) {
                    next if(m/^(#|\s|$)/);
                    chomp;
                    my $cmd = "find $module_dir/$_ -name '*.ko*' -type f -printf '%f '";
		    my $found=`$cmd`;
		    chomp($found);
		    if ($found ne "") {
		        # Remove modules extentions whatever they are (compressed or not)
		        $found =~ s/\.ko(\.\S+)*(\s|$)/ /g;
                        $modules_to_exclude .= " --omit-drivers \"$found\"";
	            }
                }
            close(FILE);
        }

	my $modules_to_include = get_mandatory_modules();
        #
        # Copy SSH keys.
        #
        if ($ssh_key) {
            $staging_dir_option = "--include $staging_dir /";
            unless (-d "$staging_dir/root/") {
                mkdir("$staging_dir/root/", 0700) or
                    die("Couldn't create directory: $staging_dir/root/!\n");
            }
            unless (-d "$staging_dir/root/.ssh/") {
                mkdir("$staging_dir/root/.ssh/", 0700) or
                    die("Couldn't create directory: $staging_dir/root/.ssh/!\n");
            }
            print ">>> Including SSH private key: $ssh_key\n" if ($verbose);
            unless( copy($ssh_key, "$staging_dir/root/.ssh/") ) {
                die("Couldn't copy $ssh_key to $staging_dir/root/.ssh/!\n");
            }
        }
        if ($authorized_keys) {
            $staging_dir_option = "--include $staging_dir /";
            unless (-d "$staging_dir/root/.ssh/") {
                mkdir("$staging_dir/root/.ssh/", 0700) or
                    die("Couldn't create directory: $staging_dir/root/.ssh/!\n");
            }
            print ">>> Including SSH authorized keys: $authorized_keys\n" if ($verbose);
            unless( copy($authorized_keys, "$staging_dir/root/.ssh/authorized_keys") ) {
                die("Couldn't copy $authorized_keys to $staging_dir/root/.ssh/authorized_keys!\n");
            }
        }

        #
        # Copy local.cfg
        #
        if ($local_cfg) {
            $staging_dir_option = "--include $staging_dir /";
            print ">>> Including local.cfg into the initrd.img: $local_cfg\n" if ($verbose);
            unless (copy($local_cfg, "$staging_dir/local.cfg")) {
                die("Couldn't copy $local_cfg to $staging_dir/local.cfg!\n");
            }
        }

        # 
        # Dir in which to hold stuff.  XXX dannf where should this really go?
        # OL: The correct location is /usr/share/systemimager/boot/${ARCH}/
        my $boot_dir;
        if ($destination) {
            $boot_dir = $destination;
        } else {
	    # Should not end here....
            $boot_dir = "/usr/share/systemimager/boot/"._get_arch()."/standard";
        }
        eval { mkpath($boot_dir, 0, 0755) };
        if ($@) {
                print "Couldn't create $boot_dir: $@";
        }

	#
	#
	#
	my @opts = ("--no-hostonly","--no-hostonly-cmdline","--no-hostonly-i18n");
	# If --my-modules, it is a host only image: we overwrite @opts.
	@opts = ("--hostonly","--hostonly-cmdline","--hostonly-i18n") if($my_modules);
	my $hostonly_opt = "";
	my $test_cmd = "";
	my $result = "";
	# Check dracut available options and keep available ones.
	for my $opt ( @opts ) {
		$test_cmd = "dracut --help |grep -c -- $opt";
                $result = `$test_cmd`;
		chomp($result);
		$hostonly_opt .= " $opt" if ( $result != 0 );
	}
        #
        # Create initrd and save copy of kernel
        #
	if ( $staging_dir_option ) {
            print ">>> Creating new initrd addind staging dir:  $staging_dir\n" if( $verbose );
        }

	unless ($dracut_opts) { $dracut_opts = ""; }

	my $dracut_cmd="dracut --force --add systemimager --omit dash$hostonly_opt $extra_firmwares $staging_dir_option $modules_to_exclude $modules_to_include $dracut_opts $boot_dir/initrd.img $uname_r";
	system("echo $dracut_cmd > /tmp/dracut_cmd.sh");
        !system($dracut_cmd) or die("FAILED: $dracut_cmd");
	system("rm -f /tmp/dracut_cmd.sh");

        # Print initrd size information.
	# OL: BUG: this code is obsolete and not compatible with what dracut produces.
	# print ">> Evaluating initrd size to be added in the kernel boot options\n" .
	#      ">> (e.g. ".$config->systemimager_dir."/pxelinux.cfg/syslinux.cfg):\n";
	#if (-f "$boot_dir/initrd.img") {
	#    my $ramdisk_size = (`zcat $boot_dir/initrd.img | wc -c` + 10485760) / 1024;
	#    print " >>\tsuggested value -> ramdisk_size=$ramdisk_size\n\n";
	#} else {
	#    print qq(WARNING: cannot find the new boot initrd!\n);
	#}

        _get_copy_of_kernel( $uname_r, $boot_dir, $custom_kernel );
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

        my $cpuinfo = "/proc/cpuinfo";

        #
        # On the PS3, /proc/cpuinfo has a line which reads (depending on kernel version):
        # platform        : PS3(PF)
        #
        open(CPUINFO,"<$cpuinfo") or die("Couldn't open $cpuinfo for reading");
        while(<CPUINFO>) {
            if ( m/PS3/ ) {
                $arch = "ppc64-ps3";
            }
        }
        close(CPUINFO);

	return $arch;
}


sub _get_copy_of_kernel($) {

        my $uname_r       = shift;
        my $boot_dir      = shift;
        my $kernel_file   = shift;

        unless ($kernel_file) {
            $kernel_file = _choose_kernel_file( $uname_r );
        }
        unless( defined $kernel_file ) {
                print "I couldn't identify your kernel file.  Please try to use --kernel option.\n";
                exit 1;
        }

        print ">>> Using kernel from:          $kernel_file\n" if( $verbose );

        my $new_kernel_file = "$boot_dir/kernel";
        copy($kernel_file, $new_kernel_file) or die("Couldn't copy $kernel_file to $new_kernel_file: $!");
        run_cmd("ls -l $new_kernel_file", $verbose, 1) if($verbose);

	# Now try to add the matching config file if possible.
	my $kernel_release = _get_kernel_release($kernel_file);
	my $kernel_path = dirname($kernel_file);
	if(-f "$kernel_path/config-$uname_r") { # We are in /boot
		copy("$kernel_path/config-$uname_r","$boot_dir/config");
		run_cmd("ls -l $boot_dir/config", $verbose, 1) if($verbose);
	} elsif(-f "$kernel_path/config") { # We are in /lib/modules/<kver>/
		copy("$kernel_path/config","$boot_dir/config");
		run_cmd("ls -l $boot_dir/config", $verbose, 1) if($verbose);
	} else {
		print "WARNING: Unable to find config file for kernel $kernel_file";
	}

	# Now write the version.txt file
	my $version_filename = "$boot_dir/version.txt";
	open my $FH, ">", $version_filename or die("Can't open file: $version_filename: $!\n");
        print $FH "$uname_r";
        close $FH;
	run_cmd("ls -l $boot_dir/version.txt", $verbose, 1) if($verbose);
        return 1;
}

#
# Usage: my $is_this_file_a_kernel = is_kernel( $kernel );
#
#sub is_kernel {

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

#        my $file = shift;
#        my $filename = basename($file);

        #
        # Make sure it's binary
#        if( ! -B $file ) { return undef; }
        #
        # and not a directory
#        if( -d $file )   { return undef; }
        #
        # skip symlinks
#        if( -l $file )   { return undef; }
        #
        # skip dot files
#        if( $filename =~ /^\..*$/ )   { return undef; }
        #
        # skip *.bak files
#        if( $filename =~ /\.bak$/ )   { return undef; }
        #
        # eliminate ramdisks
#        if( $filename =~ m/initrd/ ) { return undef; }
        #
        # eliminate vmlinux files
#        if( $filename =~ m/^vmlinux/ ) { return undef; }
        #
        # eliminate symvers files
#        if( $filename =~ m/^symvers/ ) { return undef; }
        #
        # eliminate memtest
#        if( $filename =~ m/^memtest/ ) { return undef; }
        #
        # eliminate message
#        if( $filename =~ m/^message/ ) { return undef; }

        #
        # Get output from "file" for elimination by identification tests
#        my $cmd = "file -bz $file";
#        open(INPUT,"$cmd|") or die("Couldn't run $cmd to get INPUT");
#                my ($input) = (<INPUT>);
                # eliminate cpio archives (eg. ramdisk)
#                if( $input =~ m/cpio archive/ ) { return undef; }
                # eliminate cramfs files (eg. ramdisk)
#                if( $input =~ m/Linux Compressed ROM File System data,/ ) { return undef; }
#        close(INPUT);

        #
        # If we've made it down to here, then we'll assume it's a kernel. -BEF-
#        return 1;
#}


#
# Usage:
#       my $kernel_file = _choose_kernel_file( $uname_r, $image_dir );
#
sub _choose_kernel_file {

        my $uname_r = shift;
        my $image_dir = shift;
        $image_dir = '' if !($image_dir);

	# searching for those type of kernel in $image_dir (or /)
	# $image_dir/boot/vmlinu{x,z}-$uname_r  => Suitable for most distro shipped kernels
	# $image_dir/lib/modules/$uname_r/vmlinu{x,z} => For fedora-30+ or rhel/centos-8 in docker container
	# $image_dir/boot/{,vm}linu{x,z}* => custom kernel with name starting with (vmlinux, vmlinuz, linux, linuz)
	# $image_dir/boot/kernel*" => custom kernel with name stating with kernel
	my @kernels = glob("$image_dir/boot/vmlinu{x,z}-$uname_r $image_dir/lib/modules/$uname_r/vmlinu{x,z} $image_dir/boot/{,vm}linu{x,z}* $image_dir/boot/kernel*");

        foreach my $kernel (@kernels) {
                
                # 
                # Check each binary to verify that it's a kernel file. Preference given to the file with
                # the running kernel version, otherwise, the first available good kernel file is used.
                #

                my $kernel_release = _get_kernel_release($kernel);
                chomp($kernel_release) if ( defined($kernel_release) );
                if ( defined($kernel_release) and ($kernel_release eq $uname_r) and (-f "$image_dir/lib/modules/$uname_r/modules.dep")) {
                        return $kernel;
                }
        }
        # If cannot find kernel with name matching running version, return undef.
        return undef;
}


#
# Usage:
#       my $uname_r = _get_kernel_release( '/path/to/kernel/file' );
sub _get_kernel_release($) {
	my $file = shift;
	my $cmd = "LC_ALL=C file $file|grep -E 'Linux(/x86){0,1}\\s[Kk]ernel'";
	my $result = `$cmd`;
	my $arch = `arch`;
	$result =~ s/^.*bzImage,\s[Vv]ersion\s(\S+)\s.*$/$1/g;
	$result =~ s/,$/.$arch/g; # Old kernels idon't have arch (RHEL6, kernel 2.6)
	chomp($result);
	if ($result ne "") {
		return $result;
	} else {
		return undef;
	}
}

#
# Usage:
#       my $uname_r = _get_kernel_release( '/path/to/kernel/file' );
#sub _get_kernel_release($) {
#
#        my $file = shift;
#
#        # the default tool
#        my $cat = "cat";
#
#        my $cmd = "gzip -l $file >/dev/null 2>&1";
#        if( !system($cmd) ) {
#                # It's gzip compressed.  Let's decompress it, man.
#                $cat = "zcat";
#        }
#
#        my $uname_r;
#        $cmd = "$cat $file";
#        open(IN,"$cmd |") or die("Couldn't $cmd: $!");
#        binmode(IN);
                # 
                # Example entries like what we're trying to match against in kernels:
                #       2.6.10bef1 (finley@mantis) #1 Tue Mar 1 00:37:55 CST 2005
                #       2.4.21.SuSE_273.bef1 (root@tg-c025) (gcc version 3.2.2) #1 SMP Mon Jan 24 11:55:28 CST 2005
                #       2.4.24 (root@mantis) #2 Fri Jan 16 19:51:43 CST 2004^
                #       2.4.19-mantis-2002.11.20 (root@mantis) #6 Tue Nov 19 15:15:43 CST 2002
                #       2.6.7-1-686 (dilinger@toaster.hq.voxel.net) #1 Thu Jul 8 05:36:53 EDT 2004
                #       2.6.22.5-31-default (geeko@buildhost) #1 SMP 2007/09/21 22:29:00 UTC
                #
#                my $regex =
                #           | kernel version + build machine
                #           `---------------------------------------
#                            '(((2\.[46])|(3\.\d{1,2}))\.\d{1,2}[\w.-]*) *\(.*@.*\) [#]\d+.*' .
                #
                #           | build date
                #           `---------------------------------------
#                            '(\w{3} \w{3} \d{1,2})|(\d{4}\/\d{2}\/\d{2}) '.
                #
                #           | build time
                #           `---------------------------------------
#                            '\d{2}:\d{2}:\d{2} \w{3,4}( \d{4})?';
#                while(<IN>) {
                       # extract the `uname -r` string from the kernel file
#                       if(m/$regex/o) {
#                               $uname_r = $1;
#                               last;
#                       }
#               }
#        close(IN);

#        return $uname_r;
#}

#
# Usage:
#    my $is_this_file_a_initrd = is_initrd( $file, $kernel_release );
#
sub is_initrd
{
        # Try to detect if a file is a valid initrd that can be used to
        # boot the image - used by kexec stuff to generate a valid
        # configuration file for systemconfigurator
        # (/etc/systemconfig/systemconfig.conf).

        my $file = shift;
        my $kernel_release = shift;

        #
        # explicitly skip files without "initrd" in the filename
        unless ( $file =~ /initrd|initramfs/ ) { return undef; }
        #
        # Make sure it's binary
        if( ! -B $file ) { return undef; }
        #
        # and not a directory
        if( -d $file )   { return undef; }
        #
        # skip symlinks
        if( -l $file )   { return undef; }
        #
        # skip .bak files
        if( $file =~ /\.bak$/ )   { return undef; }

        # Get output from "file" for elimination by identification tests
        my $cmd = "LC_ALL=C file -zb $file";
        open(INPUT,"$cmd|") or die("Couldn't run $cmd to get INPUT");
                my ($input) = (<INPUT>);
                # eliminate vmlinux files
                if( $input =~ m/ELF (32|64)-bit [ML]SB/ ) { return undef; }
                # eliminate kernels
                if( $input =~ m/kernel/i ) { return undef; }
                # eliminate boot sectors
                if( $input =~ m/x86 boot sector/i ) { return undef; }
        close(INPUT);

        if ($kernel_release) {
            # Look for the kernel release into the initrd.
            foreach $cmd ('grep', 'zgrep') {
                chomp(my $rel_check = `$cmd -l "$kernel_release" $file 2>/dev/null`);
                if ($rel_check eq $file) {
                    return 1;
                }
            }
            # The kernel version string couldn't be found in the initrd, but if
            # the filename contains the kernel version probably it's the right
            # initrd to be used; i.e. if the kernel is statically built (no
            # loadable module support) the version string can't be found into
            # the initrd. -AR-
            if (((index($file, $kernel_release)) > 0) && ($file =~ /initrd/)) {
                return 1;
            }
        }

        return undef;
}


#
# Usage:
#       my $initrd_file = _choose_initrd_file( $boot_dir, $kernel_release );
#
sub _choose_initrd_file
{
        # Try to detect a valid initrd that can be used together with a
        # kernel release - this function is used by kexec stuff to
        # generate a configuration file for systemconfigurator
        # (/etc/systemconfig/systemconfig.conf)
 
        my $dir = shift;
        my $kernel_release = shift;

        opendir(DIR, $dir) || die("Can't opendir $dir: $!");
        my @files = readdir(DIR);
        closedir DIR;

        foreach (@files) {
                my $file = "$dir/$_";
                if (is_initrd($file, $kernel_release)) {
                        return $file;
                }
        }
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

################################################################################
# get_uname_r
#
# Return the most suitable kernel version
# 1st, we try uname -r version and check that modules are available. (in docker
# context, uname -r returns the host kernel version which often has no matching
# modules in guest environment).
# Then we look in /lib/modules available version higher release 1st until we
# find a matching kernel in /boot or in /lib/modules/<kver>/vmlinuz
# In case of failure (no kernel with matching modules), we return 0 as version.
#
# optional argument: image_dir (perform search in image dir instead of /)
################################################################################
sub get_uname_r {

        #
        # later, deal with this:
        #       
        #    --kernel FILE
        #
        #    identify kernel file
        #    extract uname-r info
        #
	my $image_dir = shift;
	$image_dir = '' if !($image_dir);

        my $kernel_version = `uname -r`;
        chomp $kernel_version;
        return $kernel_version if (-f "$image_dir/lib/modules/$kernel_version/modules.dep");

	# Uname -r kernel version has no matching modules, we need to find another kernel.
	unless(opendir(DIR, "$image_dir/lib/modules")) { # List available kernel versions in /lib/modules
            print "Error: $image_dir/lib/modules does not exists!";
	    return 0; # Return void kernel version.
        }

	# Sort kernel, highest version 1st. BUG: cmp is not working. Need to implement our own kernel version comparison
	my @mod_dirs = sort { $b cmp $a } grep(/^\d+\.\d+\.\d+/,readdir(DIR)); # read available module dirs in /lib/modules.
	closedir(DIR);
	foreach my $kernel_version (@mod_dirs) {
            next if (! -f "$image_dir/lib/modules/$kernel_version/modules.dep");
	    return $kernel_version if (glob("$image_dir/boot/vmlinu{x,z}-$kernel_version")); # Standard redhat kernel location and name
	    return $kernel_version if (glob("$image_dir/lib/modules/$kernel_version/vmlinu{x,z}")); # rhel8 / fedora 30 in docker container
        }

	return "0"; # We did not find any suitable kernel. return a dummy version.
}

# Create --add-drivers dracut command line option to add mandatory modules listed in /etc/systemimager/UYOK.modules_to_include.
sub get_mandatory_modules() {
	my $mandatory_modules_file = "/etc/systemimager"."/UYOK.modules_to_include";
	my $mandatory_modules_option="";
	if (-e $mandatory_modules_file) {
            #
            # Get list of inclusions from "/etc/systemimager/UYOK.modules_to_include"
            # (that file should live in the "systemimager-common" package)
            #
            open(MODULES, "<$mandatory_modules_file") or
                die("Couldn't open $mandatory_modules_file for reading\n");
                while(<MODULES>) {
                    next if(m/^(#|\s|$)/);
                    chomp;
                    $mandatory_modules_option.=$_." ";
                }
            close(MODULES);
 
	}
	# If string is non empty, we add the command line switch
	# Else we leave the empty string.
	if(length $mandatory_modules_option ) {
		# Trim right end of the module list
		$mandatory_modules_option =~ s/\s+$//;
		$mandatory_modules_option = '--add-drivers "'.$mandatory_modules_option.'"';
	}
	return $mandatory_modules_option;

}

# The function below seems unused and tries to add running modules (dracut does handle that).
# BUG: delete?
sub get_load_ordered_list_of_running_modules() {

        my $file = "/proc/modules";
        my $mandatory_modules_file = "/etc/systemimager"."/UYOK.modules_to_include";
        my @modules = ();
        my @mandatory_modules = ();

        unless (-e $file) {
            print STDERR qq(WARNING: running kernel doesn't support loadable modules!\n);
            return @modules; 
        }
        if (-e $mandatory_modules_file) {
            #
            # Get list of inclusions from "/etc/systemimager/UYOK.modules_to_include"
            # (that file should live in the "systemimager-common" package)
            #
            open(MODULES, "<$mandatory_modules_file") or
                die("Couldn't open $mandatory_modules_file for reading\n");
                while(<MODULES>) {
                    next if(m/^(#|\s|$)/);
                    chomp;
                    push(@mandatory_modules, $_);
                }
            close(MODULES);
        }

        # Find the right way to get modules info.
        my $uname_r = get_uname_r();
        my $modinfo_filename;
        if ($uname_r =~ /(^2\.6)|(^[3-4]\.[0-9]+)/) {
            $modinfo_filename = 'modinfo -F filename';
        } elsif ($uname_r =~ /^2\.4/) {
            $modinfo_filename = 'modinfo -n';
        } else {
            die "ERROR: unsupported kernel $uname_r!\n";
        }

        # get the list of the loaded module filenames.
        open(MODULES,"<$file") or die("Couldn't open $file for reading.");
        while(<MODULES>) {
                my ($module) = split;
                chomp(my $module_file = `$modinfo_filename $module 2>/dev/null`);
                if ($?) {
                        print STDERR qq(WARNING: Couldn't find module "$module" (skipping it)!\n);
                        next;
                } elsif ($module_file eq '') {
                    # try to get the filename using "modprobe -l".
                   chomp($module_file = `modprobe -l $module`);
                }
                push (@modules, $module_file);
        }
        close(MODULES);

        # add not-loaded modules mandatory for the installation environment
        foreach my $module (@mandatory_modules) {
                chomp(my $module_file = `$modinfo_filename $module 2>/dev/null`);
                if ($?) {
                        print STDERR qq(WARNING: Couldn't find module "$module", assuming it's built into the kernel.\n);
                        next;
                }
                push (@modules, $module_file);
                # add module dependencies
                my @deps;
                if ($uname_r =~ /(^2\.6)|(^3\.[0-9])/) {
                    chomp(@deps = split(/,/, `modinfo -F depends $module 2>/dev/null`));
                } elsif ($uname_r =~ /^2\.4/) {
                    open(MODULES_DEP, "</lib/modules/$uname_r/modules.dep") or
                        die "ERROR: cannot open modules.dep!\n";
                    while ($_ = <MODULES_DEP>) {
                        if ($_ =~ m/$module_file:(.*)$/) {
                            $_ = $1;
                            do {
                                last if ($_ =~ m/^$/);
                                $_ =~ s/\s*(\S+)\s*\\*$/$1/g;
                                push(@deps, $_);
                            } while (chomp($_ = <MODULES_DEP>));
                            last;
                        }
                    }
                    close(MODULES_DEP);
                } else {
                    die "ERROR: unsupported kernel $uname_r!\n";
                }
                foreach (@deps) {
                    next unless ($_);
                    chomp(my $module_file = `$modinfo_filename $_ 2>/dev/null`);
                    if ($?) {
                        print STDERR qq(WARNING: Couldn't find module "$_", assuming it's built into the kernel.\n);
                        next;
                    }
                    push (@modules, $module_file);
                }
        }
        # remove duplicate modules
        my %seen = ();
        @modules = grep { !$seen{$_}++ } @modules;

        # reverse order list of running modules
        @modules = reverse(@modules);

        return @modules;
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

