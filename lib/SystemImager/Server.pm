#
#   "SystemImager" 
#
#   Copyright (C) 1999-2014 Brian Elliott Finley
#
#

package SystemImager::Server;

#use lib "USR_PREFIX/lib/systemimager/perl";
use Carp;
use strict;
use File::Copy;
use File::Path;
use XML::Simple;
use SystemImager::Config qw($config);
use vars qw($VERSION @mount_points %device_by_mount_point %filesystem_type_by_mount_point $disk_no %dev2disk $bootdev $rootdev);

$VERSION="SYSTEMIMAGER_VERSION_STRING";

################################################################################
#
# Subroutines in this module include:
#
#   _mount_proc_in_image_on_client 
#   _get_array_of_disks 
#   _imageexists 
#   _in_script_add_standard_header_stuff 
#   _read_partition_info_and_prepare_parted_commands 
#   _read_partition_info_and_prepare_soft_raid_devs -AR- 
#   _read_partition_info_and_prepare_pvcreate_commands -AR-
#   _write_lvm_groups_commands -AR-
#   _write_lvm_volumes_commands -AR-
#   _write_boel_devstyle_entry
#   _write_elilo_conf
#   _write_out_mkfs_commands 
#   _write_out_new_fstab_file 
#   _write_out_umount_commands 
#   add2rsyncd 
#   copy_boot_files_from_image_to_shared_dir
#   copy_boot_files_to_boot_media
#   create_autoinstall_script
#   create_image_stub 
#   gen_rsyncd_conf 
#   get_image_path 
#   numerically 
#   record_image_retrieval_time
#   record_image_retrieved_from
#   remove_boot_file
#   remove_image_stub 
#   upgrade_partition_schemes_to_generic_style 
#   validate_auto_install_script_conf 
#   validate_ip_assignment_option 
#   validate_post_install_option 
#
################################################################################


sub copy_boot_files_from_image_to_shared_dir {

    use File::Copy;
    use File::Path;

    shift;
    my $image                   = shift;
    my $image_dir               = shift;
    my $rsync_stub_dir          = shift;
    my $autoinstall_boot_dir    = shift;

    my $kernel = $image_dir . "/etc/systemimager/boot/kernel";
    my $initrd = $image_dir . "/etc/systemimager/boot/initrd.img";
    my $file   = $image_dir . "/etc/systemimager/boot/ARCH";

    unless ((-e $kernel) && (-e $initrd) && (-e $file)) {
        return -1;
    }

    open(FILE,"<$file") or die("Couldn't open $file for reading $!");
        my $arch = (<FILE>)[0];
    close(FILE);
    chomp $arch;

    my $dir = "$autoinstall_boot_dir/$arch/$image";
    eval { mkpath($dir, 0, 0755) };
    if ($@) { print "Couldn’t create $dir: $@"; }
    copy("$kernel","$dir") or die "Copy failed: $!";
    copy("$initrd","$dir") or die "Copy failed: $!";

    return 1;
}


sub record_image_retrieved_from {

    shift;
    my $image_dir       = shift @_;
    my $golden_client   = shift @_;

    my $file = $image_dir . "/etc/systemimager/IMAGE_RETRIEVED_FROM";

    local *FILE;
    open(FILE,">$file") or die("Couldn't open $file for writing!");
        print FILE "$golden_client\n";
    close(FILE);

    return 1;
}

sub record_image_retrieval_time {

    shift;
    my $image_dir = shift @_;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon += 1;

    my $file = $image_dir . "/etc/systemimager/IMAGE_RETRIEVAL_TIME";

    local *FILE;
    open(FILE,">$file") or die("Couldn't open $file for writing!");
        printf(FILE "%04d.%02d.%02d %02d:%02d\n", $year,$mon,$mday,$hour,$min);
    close(FILE);

    return 1;

}

sub create_image_stub {
    my ($class, $stub_dir, $imagename, $image_dir) = @_;

    open(OUT,">$stub_dir/40$imagename") or return undef;
        print OUT "[$imagename]\n\tpath=$image_dir\n\n";
    close OUT;
}


sub remove_image_stub {
    my ($class, $stub_dir, $imagename) = @_;
    unlink "$stub_dir/40$imagename" or return undef;
}


sub gen_rsyncd_conf {
    my ($class, $stub_dir, $rsyncconf) = @_;

    opendir STUBDIR, $stub_dir or return undef;
      my @stubfiles = readdir STUBDIR;
    closedir STUBDIR;

    #
    # For a stub file to be used, that stub file's name must:
    # o start with one or more digits
    # o have one or more letters and or underscores
    # o have no other characters
    #
    # -BEF-
    #
    @stubfiles = grep (/^\d+/, @stubfiles);      # Must start with a digit
    @stubfiles = grep (!/~$/, @stubfiles);       # Can't end with a tilde (~)
    @stubfiles = grep (!/\.bak$/, @stubfiles);   # Can't end with .bak
    @stubfiles = sort @stubfiles;

    open(RSYNC_CONF, ">$rsyncconf") or return undef;
      foreach my $stub_file (@stubfiles) {
        my $file = "$stub_dir/$stub_file";

        if ( -f $file ) {
          open(STUBFILE, "<$file") or return undef;
          while (<STUBFILE>) {
            print RSYNC_CONF;
          }
          close STUBFILE;
        }
      }
    close RSYNC_CONF;
}

sub add2rsyncd {
    my ($class, $rsyncconf, $imagename, $image_dir) = @_;
    
    if(!_imageexists($rsyncconf, $imagename)) {
        open(OUT,">>$rsyncconf") or return undef;
        print OUT "[$imagename]\n\tpath=$image_dir\n\n";
        close OUT;
        return 1;
    }
    return 1;
}

sub _imageexists {
    my ($rsyncconf, $imagename) = @_;
    open(IN,"<$rsyncconf") or return undef;
    if(grep(/\[$imagename\]/, <IN>)) {
        close(IN);
        return 1;
    }
    return undef;
}

sub validate_post_install_option {
  my $post_install=$_[1];

  unless(($post_install eq "beep") or ($post_install eq "reboot") or ($post_install eq "shutdown") or ($post_install eq "shell") or ($post_install eq "kexec")) { 
    die qq(\nERROR: -post-install must be beep, reboot, shutdown, shell or kexec.\n\n       Try "--help" for more options.\n);
  }
  return 0;
}

sub validate_ip_assignment_option {
  my $ip_assignment_method=$_[1];

  $ip_assignment_method = lc $ip_assignment_method;
  unless(
    ($ip_assignment_method eq "")
    or ($ip_assignment_method eq "dhcp")
    or ($ip_assignment_method eq "static")
    or ($ip_assignment_method eq "replicant")
  ) { die qq(\nERROR: -ip-assignment must be dhcp, static, or replicant.\n\n       Try "-help" for more options.\n); }
  return 0;
}

#
#   Usage:  my $path = get_image_path( $stub_dir, $imagename );
#
sub get_image_path {

    my $class       = shift;
    my $stub_dir    = shift;
    my $imagename   = shift;

    open (FILE, "<$stub_dir/40$imagename") or return undef;
    while (<FILE>) {
        if (/^\s*path\s*=\s*(\S+)\s$/) {
            close FILE;
            return $1;
        }
    }
    close FILE;

    return undef;
}

# Usage:
# my $path = SystemImager::Server->get_image_path( $rsync_stub_dir, $image );   #XXX
sub get_full_path_to_image_from_rsyncd_conf {

    print "FATAL: get_full_path_to_image_from_rsyncd_conf is depricated.\n";
    print "Please tell this tool to call the following subroutine instead:\n";
    print 'SystemImager::Server->get_image_path( $rsync_stub_dir, $image );' . "\n";
    die;
}

# Description:
#  Given a disk name, and a partition number, return the appropriate
#  filename for the partition.
#
# Usage:
#  get_part_name($disk, $num);
#
sub get_part_name {
    my ($disk, $num) = @_;
    
    if ($disk =~ /^\/dev\/.*\/c\d+d\d+$/) {
        return $disk . "p" . $num;
    }
    return $disk . $num;
}

# Description:
#  Returns a list of all devices (disks & partitions) from a given
#  autoinstallscript.conf file.
#
# Usage:
#  get_all_devices($file)
#
sub get_all_devices($) {

    my ($file) = @_;
    
    my @dev_list = ();
    
    my $part_config = XMLin($file, keyattr => { fsinfo => "+line" }, forcearray => 1 );
    foreach my $line (keys %{$part_config->{fsinfo}}) {
        if ($part_config->{fsinfo}->{$line}->{comment}) { 
            next;
        }
        if ($part_config->{fsinfo}->{$line}->{real_dev}) {
            push @dev_list, $part_config->{fsinfo}->{$line}->{real_dev};
        }
    }

    my $fs_config = XMLin($file, keyattr => { disk => "+dev", part => "+num" }, forcearray => 1 );  
    foreach my $key (keys %{$fs_config->{disk}}) {
        push @dev_list, $key;
    }
    
    return @dev_list;
}

# Description:
#  Returns a list of all disks from a given autoinstallscript.conf
#  file.
#
# Usage:
#  get_all_disks($file)
#
sub get_all_disks($) {
    my ($file) = @_;

    my @dev_list = ();
    
    my $fs_config = XMLin($file, keyattr => { disk => "+dev", part => "+num" }, forcearray => 1 );  
    foreach my $key (keys %{$fs_config->{disk}}) {
	push @dev_list, $key;
    }
    
    return @dev_list;
}


# Description:
# Convert standard /dev names to the corresponding devfs names.
# In most cases this is not needed.  However, there are a few cases
# in which using devfsd symbolic links is not possible.
# 
# An example of a case where this is necessary is the cpqarray driver.
# The standard /dev file name includes /dev/ida/c0d0 for the disk,
# while the devfs name it exports is /dev/ida/c0d0/disc.  The overlapping
# use of the /dev/ida/c0d0 name (in one case a file, and in another a
# directory), makes it impossible for both sets of names to exist in the
# same namespace.
#
# Usage:
# dev_to_devfs( @disk_and_partition_list );
#
# returns a mapping of [standard /dev name] -> [devfs name] in a hash
sub dev_to_devfs {
    my @devices = @_;
    my %table = ();

    foreach my $dev (@devices) {
        $table{$dev} = $dev;
    }

    return %table;
}

# Usage:  
# _read_partition_info_and_prepare_parted_commands( $out, $image_dir, $auto_install_script_conf );
sub _read_partition_info_and_prepare_parted_commands {

    my ($out, $image_dir, $file) = @_;

    my $xml_config = XMLin($file, keyattr => { disk => "+dev", part => "+num" }, forcearray => 1 );  

    my @all_devices = get_all_devices($file);
    my %devfs_map = dev_to_devfs(@all_devices) or return undef;

    #
    # Diagnostic output. -BEF-
    #
    #foreach my $dev (sort (keys ( %{$xml_config->{disk}} ))) {
	#    print "Found disk: $dev.\n";
    #}

    #
    # Ok.  Now that we've read all of the partition scheme info into hashes, let's do stuff with it. -BEF-
    #
    foreach my $dev (sort (keys ( %{$xml_config->{disk}} ))) {

        my $label_type = $xml_config->{disk}->{$dev}->{label_type};
        my (
            $highest_part_num, 
            $highest_p_or_e_part_num, 
            $m, 
            $cmd, 
            $part, 
            $empty_partition_count, 
            $remaining_empty_partitions, 
            $MB_from_end_of_disk
        );

        my $devfs_dev = $devfs_map{$dev};
        $dev2disk{$devfs_dev} = "DISK".$disk_no++;
        print $out "if [ -z \$DISKORDER ] ; then\n";
        print $out "  $dev2disk{$devfs_dev}=$devfs_dev\n";
        print $out "elif [ -z \$$dev2disk{$devfs_dev} ] ; then\n";
        print $out qq(  echo "Undefined: $dev2disk{$devfs_dev}"\n);
        print $out "  shellout\n";
        print $out "fi\n";
        $devfs_dev = '$'.$dev2disk{$devfs_dev};

        print $out "### BEGIN partition $devfs_dev ###\n";
        print $out qq(logmsg "Partitioning $devfs_dev..."\n);
        print $out qq(logmsg "Old partition table for $devfs_dev:"\n);
        print $out "LC_ALL=C parted -s -- $devfs_dev print\n\n";

        print $out "# Wipe the MBR (Master Boot Record) clean.\n";
        $cmd = "dd if=/dev/zero of=$devfs_dev bs=512 count=1 || shellout";
        print $out qq(logmsg "$cmd"\n);
        print $out "$cmd\n\n";

        print $out "# Re-read the disk label.\n";
        $cmd = "blockdev --rereadpt $devfs_dev";
        print $out qq(logmsg "$cmd"\n);
        print $out "$cmd\n\n";

        print $out "# Create disk label.  This ensures that all remnants of the old label, whatever\n";
        print $out "# type it was, are removed and that we're starting with a clean label.\n";
        $cmd = "parted -s -- $devfs_dev mklabel $label_type || shellout";
        print $out qq(logmsg "$cmd"\n);
        print $out "LC_ALL=C $cmd\n\n";

        print $out "# Get the size of the destination disk so that we can make the partitions fit properly.\n";
        print $out q(DISK_SIZE=`LC_ALL=C parted -s ) . $devfs_dev . q( unit MB print | egrep ") . $devfs_dev . q(" | awk '{print $NF}' | sed 's/MB//' `) . qq(\n);
        print $out q([ -z $DISK_SIZE ] && shellout) . qq(\n);

        print $out q(if [ "$ARCH" = "alpha" ]; then) . qq(\n);	
        print $out q(    END_OF_LAST_PRIMARY=1) . qq(\n);
        print $out q(else) . qq(\n);
        print $out q(    END_OF_LAST_PRIMARY=1 # 1: room for grub2) . qq(\n);
        print $out q(fi) . qq(\n\n);

        ### BEGIN Populate the simple hashes. -BEF- ###
        my (
            %end_of_disk,
            %flags,
            %id, 
            %p_type, 
            %p_name, 
            %size, 
            %startMB,
            %endMB
        );

        my $unit_of_measurement = lc $xml_config->{disk}->{$dev}->{unit_of_measurement};

        ########################################################################
        #
        # Make sure the user specified 100% or less of the disk (if used). -BEF-
        # (may want to functionize these at some point)
        #
        ########################################################################
        if (("$unit_of_measurement" eq "%")
            or ("$unit_of_measurement" eq "percent") 
            or ("$unit_of_measurement" eq "percentage") 
            or ("$unit_of_measurement" eq "percentages")) {

            #
            # Primary partitions. -BEF-
            #
            my $p_sum = 0;
            foreach my $m (sort (keys ( %{$xml_config->{disk}->{$dev}->{part}} ))) {

                #
                # Skip over logical partitions. -BEF-
                # 
                $_ = $xml_config->{disk}->{$dev}->{part}{$m}->{p_type};
                if ( $_ ne "primary" ) { next; }

                #
                # Skip over if size is end_of_disk (*) -- we can't measure that without the disk. -BEF-
                #
                $_ = $xml_config->{disk}->{$dev}->{part}{$m}->{size};
                if ( $_ eq "*" ) { next; }

                if (/[[:alpha:]]/) {
                    print qq(FATAL:  autoinstallscript.conf cannot contain "$_" as a percentage.\n);
                    print qq(        Disk: $dev, partition: $m\n);
                    exit 1;
                }

                $p_sum += $_;

            }

            #
            # Extended partition. -BEF-
            #
            my $e_sum = 0;
            foreach my $m (sort (keys ( %{$xml_config->{disk}->{$dev}->{part}} ))) {

                $_ = $xml_config->{disk}->{$dev}->{part}{$m}->{p_type};
                if ( $_ ne "extended" ) { next; }

                #
                # Skip over if size is end_of_disk (we can't measure that without the disk.) -BEF-
                #
                $_ = $xml_config->{disk}->{$dev}->{part}{$m}->{size};
                if ( $_ eq "*" ) { next; }

                if (/[[:alpha:]]/) {
                    print qq(FATAL:  autoinstallscript.conf cannot contain "$_" as a percentage.\n);
                    print qq(        Disk: $dev, partition: $m\n);
                    exit 1;
                }

                $e_sum += $_;

            }

            #
            # Logical partitions must not exceed percentage size of the extended partition.  But
            # we only need to process this loop if an extended partition exists. -BEF-
            #
            my $l_sum = 0;
            if ($e_sum > 0) {
                foreach my $m (sort (keys ( %{$xml_config->{disk}->{$dev}->{part}} ))) {
 
                    #
                    # Skip over primary and extended partitions. -BEF-
                    # 
                    $_ = $xml_config->{disk}->{$dev}->{part}{$m}->{p_type};
                    unless ( $_ eq "logical" ) { next; }
 
                    #
                    # Skip over if size is end_of_disk (we can't measure that without the disk.) -BEF-
                    #
                    $_ = $xml_config->{disk}->{$dev}->{part}{$m}->{size};
                    if ( $_ eq "*" ) { next; }
 
                    if (/[[:alpha:]]/) {
                        print qq(FATAL:  autoinstallscript.conf cannot contain "$_" as a percentage.\n);
                        print qq(        Disk: $dev, partition: $m\n);
                        exit 1;
                    }
 
                    $l_sum += $_;
 
                }
            }

            #
            # Produce error message if necessary. -BEF-
            #
            my $p_e_sum = $p_sum + $e_sum;
            if ($p_e_sum > 100) {
                print qq(FATAL:  Your autoinstallscript.conf file specifies that "${p_e_sum}%" of your disk\n);
                print   "        should be partitioned.  Ummm, I don't think you have that much disk. ;-)\n";
                exit 1;
            } elsif ($l_sum > 100) {
                print qq(FATAL:  Your autoinstallscript.conf file specifies that "${l_sum}%" of your disk\n);
                print   "        should be partitioned.  Ummm, I don't think you have that much disk. ;-)\n";
                exit 1;
            } elsif ($l_sum > $e_sum) {
                print qq(FATAL:  Your autoinstallscript.conf file specifies that the sum of your logical\n);
                print qq(partitions should take up "${l_sum}%" of your disk but the extended partition,\n);
                print qq(in which the logical partitions must fit, is specified as only "${e_sum}%" of\n);
                print qq(your disk.  Please modify and try again.\n);
                exit 1;
            }
        } 


        ########################################################################
        #
        # Continue processing. -BEF-
        #
        ########################################################################

        my $end_of_last_primary = 0;
        my $end_of_last_logical;

        foreach my $m (sort (keys ( %{$xml_config->{disk}->{$dev}->{part}} ))) {
            $flags{$m}       = $xml_config->{disk}->{$dev}->{part}{$m}->{flags};
            $id{$m}          = $xml_config->{disk}->{$dev}->{part}{$m}->{id};
            $p_name{$m}      = $xml_config->{disk}->{$dev}->{part}{$m}->{p_name};
            $p_type{$m}      = $xml_config->{disk}->{$dev}->{part}{$m}->{p_type};
            $size{$m}        = $xml_config->{disk}->{$dev}->{part}{$m}->{size};

            # Calculate $startMB and $endMB. -BEF-
            if ("$p_type{$m}" eq "primary") {
                $startMB{$m} = q($END_OF_LAST_PRIMARY);
            
            } elsif ("$p_type{$m}" eq "extended") {
                $startMB{$m} = q($END_OF_LAST_PRIMARY);
            
            } elsif ("$p_type{$m}" eq "logical") {
                # $startMB{$m} = q($END_OF_LAST_LOGICAL);
                # Fix parted extended partition table kernel reload error: -OL-
                # "Warning: The kernel was unable to re-read the partition table..."
                # Maybe related to bug https://bugzilla.redhat.com/show_bug.cgi?id=441244
                # => TEMPORARY FIX until parted get fixed.
                $startMB{$m} = q#$(( $END_OF_LAST_LOGICAL + 1 ))#;
            }

            if (("$unit_of_measurement" eq "mb") 
                or ("$unit_of_measurement" eq "megabytes")) {

                $endMB{$m} = q#$(echo "scale=3; ($START_MB + # . qq#$size{$m})" | bc)#;

            } elsif (("$unit_of_measurement" eq "%")
                or ("$unit_of_measurement" eq "percent") 
                or ("$unit_of_measurement" eq "percentage") 
                or ("$unit_of_measurement" eq "percentages")) {

                $endMB{$m} = q#$(echo "scale=3; (# . qq#$startMB{$m}# . q# + ($DISK_SIZE * # . qq#$size{$m} / 100))" | bc)#;
            }

        }
        ### END Populate the simple hashes. -BEF- ###

        # Figure out what the highest partition number is. -BEF-
        foreach (sort { $a <=> $b } (keys ( %{$xml_config->{disk}->{$dev}->{part}} ))) {
            $highest_part_num = $_;
        }


        # Find out what the highest primary or extended partition number is. 
        # This will help us prevent from creating unnecessary bogus partitions.
        # -BEF-
        #
        foreach my $m (sort (keys ( %{$xml_config->{disk}->{$dev}->{part}} ))) {
            unless (($p_type{$m} eq "primary") or ($p_type{$m} eq "extended")) { next; }
            $highest_p_or_e_part_num = $m;
        }


        ### BEGIN For empty partitions, change $endMB appropriately. -BEF- ###
        #
        $m = $highest_p_or_e_part_num;
        $empty_partition_count = 0;
        $MB_from_end_of_disk = 0;
        my %minors_to_remove;
        until ($m == 0) {
          unless ($endMB{$m}) {
            $empty_partition_count++;

            $endMB{$m} = '$(( $DISK_SIZE - ' . "$MB_from_end_of_disk" . ' ))';
            $MB_from_end_of_disk++;

            $startMB{$m} = '$(( $DISK_SIZE - ' . "$MB_from_end_of_disk" . ' ))';
            $MB_from_end_of_disk++;

            $p_type{$m} = "primary";
            $p_name{$m} = "-";
            $flags{$m}  = "-";

            $minors_to_remove{$m} = 1;  # This could be any value.  -BEF-
          }

          $m--;
        }

        # For partitions that go to the end of the disk, tell $endMB to grow to end of disk. -BEF-
        foreach $m (keys %endMB) {
            if (($size{$m}) and ( $size{$m} eq "*" )) {
                $endMB{$m} = '$(( $DISK_SIZE - ' . "$MB_from_end_of_disk" . ' ))';
            }
        }
        ### END For empty partitions, change $endMB appropriately. -BEF- ###


        # Start out with a minor of 1.  We iterate through all minors from one 
        # to $highest_part_num, and fool parted by creating bogus partitions
        # where there are gaps in the partition numbers, then later removing them. -BEF-
        #
        $m = "0";
        until ($m > $highest_part_num) {

            $m++;
            
            # Skip over partitions we don't have data for.  This is most likely to
            # occur in the case of an msdos disk label, with empty partitions
            # after an extended partition, but before logical partitions. -BEF-
            #
            unless ($endMB{$m}) { next; }
            
            ### Print partitioning commands. -BEF-
            print $out "\n";
	    
            $part = &get_part_name($dev, $m);
            $part =~ /^(.*?)(p?\d+)$/;
            $part = "\${".$dev2disk{$1}."}".$2;
            $cmd = "Creating partition $part.";
            print $out qq(logmsg "$cmd"\n);
            
            print $out qq(START_MB=$startMB{$m}\n);
            print $out qq(END_MB=$endMB{$m}\n);

            my $swap = '';
            if ($flags{$m}) {
                if ($flags{$m} =~ /swap/) {
                    $swap = 'linux-swap ';
                }
            }

            if($p_type{$m} eq "extended") {

                $cmd = qq(parted -s -- $devfs_dev mkpart $p_type{$m} $swap) . q($START_MB $END_MB) . qq( || shellout);

            } else {

                #
                # parted *always* (except for extended partitions) requires that you 
                # specify a filesystem type, even though it does nothing with it 
                # with the "mkpart" command. -BEF-
                #
                $cmd = qq(parted -s -- $devfs_dev mkpart $p_type{$m} $swap) . q($START_MB $END_MB) . qq( || shellout);

            }
            print $out qq(logmsg "$cmd"\n);
            print $out "$cmd\n";
            
            # Leave info behind for the next partition. -BEF-
            if ("$p_type{$m}" eq "primary") {
                print $out q(END_OF_LAST_PRIMARY=$END_MB) . qq(\n);
                print $out q(sleep 1) . qq(\n);
            
            } elsif ("$p_type{$m}" eq "extended") {
                print $out q(END_OF_LAST_PRIMARY=$END_MB) . qq(\n);
                print $out q(END_OF_LAST_LOGICAL=$START_MB) . qq(\n);
            
            } elsif ("$p_type{$m}" eq "logical") {
                print $out q(END_OF_LAST_LOGICAL=$END_MB) . qq(\n);
            }
            
            #
            # If $id is set for a partition, we invoke sfdisk to tag the partition
            # id appropriately.  parted is lame (in the true sense of the word) in 
            # this regard and is incapable of # adding an arbitrary id to a 
            # partition. -BEF-
            #
            if ($id{$m}) {
                print $out qq(# Use sfdisk to change the partition id.  parted is\n);
                print $out qq(# incapable of this particular operation.\n);
                print $out qq(sfdisk --change-id $devfs_dev $m $id{$m} \n);
            }
            
            # Name any partitions that need that kinda treatment.
            #
            # XXX Currently, we are assuming that no one is using a rediculously long name.  
            # parted's output doesn't make it easy for us, and it is currently possible for
            # a long name to get truncated, and the rest would be considered flags.   
            # Consider submitting a patch to parted that would print easily parsable output 
            # with n/a values "-" and no spaces in the flags. -BEF-
            #
            if (
                  ($label_type eq "gpt") 
                  and ($p_name{$m}) 
                  and ($p_name{$m} ne "-")
              ) {  # We're kinda assuming no one names their partitions "-". -BEF-
            
              $cmd = "parted -s -- $devfs_dev name $m $p_name{$m} || shellout\n";
              print $out qq(logmsg "$cmd");
              print $out "$cmd";
            }
            
            ### Deal with flags for each partition. -BEF-
            if(($flags{$m}) and ($flags{$m} ne "-")) {
            
                # $flags{$m} will look something like "boot,lba,raid" or "boot" at this point.
                my @flags = split (/,/, $flags{$m});
                
                foreach my $flag (@flags) {
                    # Parted 1.6.0 doesn't seem to want to tag gpt partitions with lba.  Hmmm. -BEF-
                    if (($flag eq "lba") and ($label_type eq "gpt")) { next; }
                    # Ignore custom flag 'swap'. -AR-
                    if ($flag eq "swap") { next; }
                    $cmd = "parted -s -- $devfs_dev set $m $flag on || shellout\n";
                    print $out qq(logmsg "$cmd");
                    print $out "$cmd";
                }
            }
        }

        # Kick the minors out.  (remove temporary partitions) -BEF-
        foreach $m (keys %minors_to_remove) {
          print $out "\n# Gotta lose this one (${dev}${m}) to make the disk look right.\n";
          $cmd = "parted -s -- $devfs_dev rm $m  || shellout";
          print $out qq(logmsg "$cmd"\n);
          print $out "$cmd\n";
        }

        print $out "\n";
        print $out qq(logmsg "New partition table for $devfs_dev:"\n);
        $cmd = "parted -s -- $devfs_dev print";
        print $out qq(logmsg "$cmd"\n);
        print $out "$cmd\n";
        print $out "### END partition $devfs_dev ###\n";
        print $out "\n";
        print $out "\n";
    }
}

# Usage:
#
#   _read_partition_info_and_prepare_soft_raid_devs( $out, $image_dir, $auto_install_script_conf );
# 
sub _read_partition_info_and_prepare_soft_raid_devs {

    my ($out, $image_dir, $file) = @_;

    # Load RAID modules.
    print $out qq(logmsg "Load software RAID modules."\n);
    print $out qq(modprobe linear\n);
    print $out qq(modprobe raid0\n);
    print $out qq(modprobe raid1\n);
    print $out qq(modprobe raid5\n);
    print $out qq(modprobe raid6\n);
    print $out qq(modprobe raid10\n);
    print $out qq(modprobe raid456\n);

    my $xml = XMLin($file, keyattr => { raid => "+name" }, forcearray => 1 );
    my @all_disks = reverse(get_all_disks($file));

    #
    # Create a lookup hash.  Contents are like:
    #   /dev/sda => DISK0
    #
    my %DISK_by_disk;
    my $i = 0;
    foreach my $disk (sort @all_disks) {
        $DISK_by_disk{$disk} = "DISK$i";
        $i++;
    }

    foreach my $md ( sort (keys %{$xml->{raid}}) ) {

        my @md_devices = split(/ /, $xml->{raid}->{$md}->{devices});
        my $devices;

        # Translate partitions in disk variables (disk autodetection compliant).
        foreach (@md_devices) {
            # m/^(.*)(p?\d+)$/;
            # 
            # New regex from patch provided by Thomas Zeiser <thomas.zeiser@rrze.uni-erlangen.de>
            #   Hi,
            #   
            #   here is a small bug fix to get HP's cciss/cXdYpZ correctly
            #   detected in
            #   Server.pm (relativ to 4.1.99.svn4556_bli-1):
            #
            m/^(.*[^p])(p?\d+)$/;
            my $disk = $1;
            my $part_no = $2;
            $devices .= '${' . $DISK_by_disk{$disk} . '}' . $part_no . ' ';
        }

        # yes | mdadm --create $name \
        #     --chunk $chunk_size \
        #     --level $raid_level \
        #     --raid-devices $raid_devices \
        #     --spare-devices ($total_devices - $raid_devices) \
        #     $devices

        my $cmd = qq(yes | mdadm --create $md \\\n);
        $cmd   .= qq(  --auto yes \\\n);
        $cmd   .= qq(  --level $xml->{raid}->{$md}->{raid_level} \\\n) if($xml->{raid}->{$md}->{raid_level});
        $cmd   .= qq(  --raid-devices $xml->{raid}->{$md}->{raid_devices} \\\n) if($xml->{raid}->{$md}->{raid_devices});
        $cmd   .= qq(  --spare-devices $xml->{raid}->{$md}->{spare_devices} \\\n) if($xml->{raid}->{$md}->{spare_devices});
        if($xml->{raid}->{$md}->{rounding}) {
            $xml->{raid}->{$md}->{rounding} =~ s/K$//;
            $cmd   .= qq(  --rounding $xml->{raid}->{$md}->{rounding} \\\n);
        }
        $cmd   .= qq(  --layout $xml->{raid}->{$md}->{layout} \\\n) if($xml->{raid}->{$md}->{layout});
        if($xml->{raid}->{$md}->{chunk_size}) {
            $xml->{raid}->{$md}->{chunk_size} =~ s/K$//;
            $cmd   .= qq(  --chunk $xml->{raid}->{$md}->{chunk_size} \\\n);
        }
        $cmd   .= qq(  $devices\n);

        print $out "\nlogmsg \"$cmd\"";
        print $out "\n$cmd\n";
    }
    #XXX Do we want to 
    #   - re-create UUIDs?
    #   - store partition vs. 

    #
    # This is where we should create the /etc/mdadm/mdadm.conf file.
    #
    #XXX
    #   - for DEVICE, we can literally list every device involved.  Ie:
    #       DEVICE /dev/sda1 /dev/sdb1 /dev/sdc1 etc...

    return 1;

}


# Usage:
# _read_partition_info_and_prepare_pvcreate_commands( $out, $image_dir, $auto_install_script_conf );
sub _read_partition_info_and_prepare_pvcreate_commands {
    my ($out, $image_dir, $file) = @_;

    my $xml_config = XMLin($file, keyattr => { disk => "+dev", part => "+num" }, forcearray => 1 );

    my @all_devices = get_all_devices($file);
    my %devfs_map = dev_to_devfs(@all_devices) or return undef;
    my $cmd;

    foreach my $dev (sort (keys ( %{$xml_config->{disk}} ))) {

        my (
            $highest_part_num,
            $m,
            $part,
        );

        my $devfs_dev = '$' . $dev2disk{$devfs_map{$dev}};

        ### BEGIN Populate the simple hashes. -BEF- ###
        my (
            %flags,
            %p_type,
            %p_name,
        );

        foreach my $m (sort (keys ( %{$xml_config->{disk}->{$dev}->{part}} ))) {
            $flags{$m}       = $xml_config->{disk}->{$dev}->{part}{$m}->{flags};
            $p_name{$m}      = $xml_config->{disk}->{$dev}->{part}{$m}->{p_name};
            $p_type{$m}      = $xml_config->{disk}->{$dev}->{part}{$m}->{p_type};
        }

        # Figure out what the highest partition number is. -BEF-
        foreach (sort { $a <=> $b } (keys ( %{$xml_config->{disk}->{$dev}->{part}} ))) {
            $highest_part_num = $_;
        }

        $m = "0";
        until ($m >= $highest_part_num) {

            $m++;
            unless (defined($p_type{$m})) { next; }

            $part = &get_part_name($dev, $m);
            $part =~ /^(.*?)(p?\d+)$/;
            $part = "\${".$dev2disk{$1}."}".$2;

            # Extended partitions can't be used by LVM. -AR-
            if ("$p_type{$m}" eq "extended") { next; }

            ### Deal with LVM flag for each partition. -AR-
            if (($flags{$m}) and ($flags{$m} ne "-")) {
                my @flags = split (/,/, $flags{$m});
                foreach my $flag (@flags) {
                    if ("$flag" eq "lvm") {
                        # Get volume group for this patition -AR-
                        my $vg_name = $xml_config->{disk}->{$dev}->{part}->{$m}->{lvm_group};
                        unless (defined($vg_name)) {
                            print "WARNING: LVM partition \"${dev}${m}\" is not assigned to any group!\n";
                            next;
                        }
                        # Get the version of the LVM metadata to use -AR-
                        foreach my $lvm (@{$xml_config->{lvm}}) {
                            my $version = $lvm->{version};
                            unless (defined($version)) {
                                # Default => get LVM2 metadata type.
                                $version = 2;
                            }
                            foreach my $lvm_group_name (@{$lvm->{lvm_group}}) {
                                if ($lvm_group_name->{name} eq $vg_name) {
                                    $cmd = "Initializing partition $part for use by LVM.";
                                    print $out qq(logmsg "$cmd"\n);

                                    $cmd = "pvcreate -M${version} -ff -y $part || shellout";
                                    print $out qq(logmsg "$cmd"\n);
                                    print $out "$cmd\n";
                                    goto part_done;
                                }
                            }
                        }
                    }
                }
part_done:
            }
        }
    }

   # Initialize software RAID volumes used for LVM (if present).
    my $xml = XMLin($file, keyattr => { raid => "+name" }, forcearray => 1 );
    foreach my $md ( sort (keys %{$xml->{raid}}) ) {
        my $vg_name = $xml->{raid}->{$md}->{lvm_group};
        unless ($vg_name) {
            next;
        }

        # Get the version of the LVM metadata to use.
        foreach my $lvm (@{$xml_config->{lvm}}) {
            my $version = $lvm->{version};
            unless (defined($version)) {
                # Default => get LVM2 metadata type.
                $version = 2;
            }
            foreach my $lvm_group_name (@{$lvm->{lvm_group}}) {
                if ($lvm_group_name->{name} eq $vg_name) {
                    $cmd = "pvcreate -M${version} -ff -y $md || shellout";
                    print $out qq(logmsg "$cmd"\n);
                    print $out "$cmd\n";
                }
            }
        }
    }
}

# Usage:  
# write_lvm_groups_commands( $out, $image_dir, $auto_install_script_conf );
sub write_lvm_groups_commands {
    
    my ($out, $image_dir, $file) = @_;

    my $xml_config = XMLin($file, keyattr => { lvm_group => "+name" }, forcearray => 1 );
    
    my $cmd;
    
    # Get all LVM blocks.
    foreach my $lvm (@{$xml_config->{lvm}}) {
        my @all_devices = get_all_devices($file);
        my %devfs_map = dev_to_devfs(@all_devices) or return undef;
        
        my $version = $lvm->{version};
        unless (defined($version)) {
            # Default => get LVM2 metadata type.
            $version = 2;
        }

        # Find the partitions assigned to each LVM group. -AR-    
        foreach my $group_name (sort (keys ( %{$lvm->{lvm_group}} ))) {
            my $part_list = "";

            foreach my $disk (@{$xml_config->{disk}}) {
                my $dev = $disk->{dev};
            
                # Figure out what the highest partition number is. -AR-
                my $highest_part_num = 0;
                foreach my $part ( @{$disk->{part}} ) {
                    my $num = $part->{num};
                    if ($num > $highest_part_num) {
                        $highest_part_num = $num;
                    }
                }
            
                # Evaluate the partition list for the current LVM group -AR-
                my $m = "0";
                foreach my $part (@{$disk->{part}}) {
                    $m++;
                    unless (defined($part->{lvm_group})) { next; }
                    if ($part->{lvm_group} eq $group_name) {
                        if (defined($part->{num})) {
                            $m = $part->{num};
                        }
                        my $part_name = &get_part_name($dev, $m);
                        if ($part_name =~ /^(.*?)(p?\d+)$/) {
                            $part_name = "\${".$dev2disk{$1}."}".$2;
                        }
                        $part_list .= " $part_name";
                    }
                }
            }

           # Find RAID disks assigned to the volume group.
            my $xml = XMLin($file, keyattr => { raid => "+name" }, forcearray => 1 );
            foreach my $md ( sort (keys %{$xml->{raid}}) ) {
                my $vg_name = $xml->{raid}->{$md}->{lvm_group};
                unless ($vg_name) {
                    next;
                }
                unless ($vg_name eq $group_name) {
                    next;
                }
                $part_list .= " $md";
            }

            if ($part_list ne "") {
                # Evaluate the volume group options -AR-
                my $vg_max_log_vols = $lvm->{lvm_group}->{$group_name}->{max_log_vols};
                if (defined($vg_max_log_vols)) { 
                    $vg_max_log_vols = "-l $vg_max_log_vols ";
                } else {
                    $vg_max_log_vols = ""; 
                }
                my $vg_max_phys_vols = $lvm->{lvm_group}->{$group_name}->{max_phys_vols};
                if (defined($vg_max_phys_vols)) { 
                    $vg_max_phys_vols = "-p $vg_max_phys_vols ";
                } else {
                    $vg_max_phys_vols = "";
                }
                my $vg_phys_extent_size = $lvm->{lvm_group}->{$group_name}->{phys_extent_size};
                if (defined($vg_phys_extent_size)) { 
                    $vg_phys_extent_size = "-s $vg_phys_extent_size ";
                } else {
                    $vg_phys_extent_size = ""; 
                }
                # Remove previous volume groups with $group_name if already present.
                $cmd = "lvremove -f /dev/${group_name} >/dev/null 2>&1 && vgremove $group_name >/dev/null 2>&1";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";
                # Write the command to create the volume group -AR-
                $cmd = "vgcreate -M${version} ${vg_max_log_vols}${vg_max_phys_vols}${vg_phys_extent_size}${group_name}${part_list} || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";
            } else {
                print "WARNING: LVM group \"$group_name\" doesn't have partitions!\n";
            }
        }
    }
}

# Usage:  
# write_lvm_volumes_commands( $out, $image_dir, $auto_install_script_conf );
sub write_lvm_volumes_commands {
    my ($out, $image_dir, $file) = @_;

    my $xml_config = XMLin($file, keyattr => { lvm_group => "+name" }, forcearray => 1 );
    
    my $lvm = @{$xml_config->{lvm}}[0];
    unless (defined($lvm)) {
        return;
    }
    
    foreach my $group_name (sort (keys ( %{$lvm->{lvm_group}} ))) {
        
        foreach my $lv (@{$lvm->{lvm_group}->{$group_name}->{lv}}) {
        
            my $cmd;    
        
            # Get logical volume name -AR-
            my $lv_name = $lv->{name};
            unless (defined($lv_name)) {
                print "WARNING: undefined logical volume name! skipping volume creation.\n";
                next;
            }
            # Get logical volume size -AR-
            my $lv_size = $lv->{size};
            unless (defined($lv_size)) {
                print "WARNING: undefined logical volume size! skipping volume creation.\n";
                next;
            }
            if ($lv_size eq '*') {
                $lv_size = '-l100%FREE';
            } else {
                $lv_size = '-L' . $lv_size;
            }
            # Get additional options (expressed in lvcreate format) -AR-
            my $lv_options = $lv->{lv_options};
            unless (defined($lv_options)) {
                $lv_options = "";
            }

            # Create the logical volume -AR-
            $cmd = "lvcreate $lv_options $lv_size -n $lv_name $group_name || shellout";
            print $out qq(logmsg "$cmd"\n);
            print $out "$cmd\n";
            
            # Enable the logical volume -AR-
            $cmd = "lvscan > /dev/null; lvchange -a y /dev/$group_name/$lv_name || shellout";
            print $out qq(logmsg "$cmd"\n);
            print $out "$cmd\n";
        }
    }
}

# Usage:  
# upgrade_partition_schemes_to_generic_style($image_dir, $config_dir);
sub upgrade_partition_schemes_to_generic_style {

    my ($module, $image_dir, $config_dir) = @_;
    
    my $partition_dir = "$config_dir/partitionschemes";
    
    # Disk types ide and scsi are pretty self explanatory.  Here are 
    # some others: -BEF-
    # o rd is a dac960 device (mylex extremeraid is an example)
    # o ida is a compaq smartscsi device
    # o cciss is a compaq smartscsi device
    #
    my @disk_types = qw( . rd ida cciss );  # The . is for ide and scsi disks. -BEF-
    
    foreach my $type (@disk_types) {
        my $dir;
        if ($type eq ".") {
            $dir = $image_dir . "/" . $partition_dir;
        } else {
            $dir = $image_dir . "/" . $partition_dir . "/" . $type;
        }

        if(-d $dir) {
            opendir(DIR, $dir) || die "Can't read the $dir directory.";
                while(my $device = readdir(DIR)) {
                
                    # Skip over any "dot" files. -BEF-
                    #
                    if ($device =~ /^\./) { next; }
                    
                    my $file = "$dir/$device";
                    
                    if (-f $file) {
                        my $autoinstall_script_conf_file = $image_dir . "/" . $config_dir . "/autoinstallscript.conf";
                        SystemImager::Common->save_partition_information($file, "old_sfdisk_file", $autoinstall_script_conf_file);
                    }
                }
            close(DIR);
        }
    }
}


sub _get_array_of_disks {

  my ($image_dir, $config_dir) = @_;
  my @disks;

  # Disk types ide and scsi are pretty self explanatory.  Here are 
  # some others: -BEF-
  # o rd is a dac960 device (mylex extremeraid is an example)
  # o ida is a compaq smartscsi device
  # o cciss is a compaq smartscsi device
  #
  my @disk_types = qw(ide scsi rd ida cciss);

  my $partition_dir = "$config_dir/partitionschemes";
  foreach my $type (@disk_types) {
    my $dir = $image_dir . $partition_dir . "/" . $type;
    if(-d $dir) {
      opendir(DIR, $dir) || die "Can't read the $dir directory.";
        while(my $device = readdir(DIR)) {

          # Skip over any "dot" files. -BEF-
          if ($device =~ /^\./) { next; }

          # Only process regular files.
          if (-f "$dir/$device") {

            # Keep the device name and directory.
            push @disks, "$type/$device";
          }
        
        }
      close(DIR);
    }
  }
  return @disks;
}

# Description:
# Read configuration information from /etc/systemimager/autoinstallscript.conf
# and write filesystem creation commands to the autoinstall script. -BEF-
#
# Usage:
# _write_out_mkfs_commands( $out, $image_dir, 
#                           $auto_install_script_conf, $raid);
#
sub _write_out_mkfs_commands {
    my ($out, $image_dir, $file) = @_;

    my $xml_config = XMLin($file, keyattr => { fsinfo => "+line" }, forcearray => 1 );

    my @all_devices = get_all_devices($file);
    my %devfs_map = dev_to_devfs(@all_devices) or return undef;
    my @d2dkeys = reverse sort keys %dev2disk;


    # Figure out if software RAID is in use. -BEF-
    #
    my $software_raid;
    foreach my $line (sort numerically (keys ( %{$xml_config->{fsinfo}} ))) {

        # If this line is a comment, skip over. -BEF-
        if ( $xml_config->{fsinfo}->{$line}->{comment} ) { next; }

        # If real_dev isn't set, move on. -BEF-
        unless ($xml_config->{fsinfo}->{$line}->{real_dev}) { next; }

        my $real_dev = $xml_config->{fsinfo}->{$line}->{real_dev};
        if ($real_dev =~ /\/dev\/md/) {
            $software_raid = "true";
        }
    }

    # The $part_type here is used to find and create all the swap partitions
    # before the other filesystems. This reduces the probability to have a OOM
    # condition during the filesystem creation.
    foreach my $part_type (0, 1) {
        foreach my $line (sort numerically (keys (%{$xml_config->{fsinfo}}))) {

            my $cmd = "";
            # If this line is a comment, skip over. -BEF-
            if ( $xml_config->{fsinfo}->{$line}->{comment} ) { next; }

            # If real_dev isn't set, move on. -BEF-
            unless ($xml_config->{fsinfo}->{$line}->{real_dev}) { next; }

            # If format="no" is set, then skip over this one. -BEF-
            my $format = $xml_config->{fsinfo}->{$line}->{format};
            if (($format) and ( "$format" eq "no")) { next; }

            # mount_dev should contain fs LABEL or UUID information. -BEF-
            my $mount_dev = $xml_config->{fsinfo}->{$line}->{mount_dev};

            my $real_dev = $devfs_map{$xml_config->{fsinfo}->{$line}->{real_dev}};
            my $mp = $xml_config->{fsinfo}->{$line}->{mp};
            my $fs = $xml_config->{fsinfo}->{$line}->{fs};
            my $options = $xml_config->{fsinfo}->{$line}->{options};
            my $mkfs_opts = $xml_config->{fsinfo}->{$line}->{mkfs_opts};
            unless ($mkfs_opts) { $mkfs_opts = ""; }

            # Remove options that may cause problems and are unnecessary during
            # the install.
            $options = _remove_mount_option($options, "errors=remount-ro");

            # Deal with filesystems to be mounted read only (ro) after install.
            # We still need to write to them to install them. ;)
            $options =~ s/\bro\b/rw/g;
            $options =~ s/\bnoauto\b/defaults/g;

            # software RAID devices (/dev/md*)
            if ($real_dev =~ /\/dev\/md/) {
                print $out qq(mkraid --really-force $real_dev || shellout\n)
                    unless (defined($xml_config->{raid}));
            } elsif( $real_dev =~ /^(.*?)(p?\d+)$/ ) {
                if ($dev2disk{$1}) {
                    $real_dev = "\${".$dev2disk{$1}."}".$2;
                }
            }

            # First of all look for swap partitions only.
            if ($part_type == 0) {
                # swap
                if ( $xml_config->{fsinfo}->{$line}->{fs} eq "swap" ) {
                    # create swap
                    $cmd = "mkswap -v1 $real_dev";

                    # add swap label if necessary
                    if ($mount_dev) {
                        if( $mount_dev =~ /^LABEL=(.*)/ ){
                            $cmd .= " -L $1";
                        }
                    }
                    $cmd .= " || shellout";

                    print $out qq(logmsg "$cmd"\n);
                    print $out "$cmd\n";

                    # swapon
                    $cmd = "swapon $real_dev || shellout";
                    print $out qq(logmsg "$cmd"\n);
                    print $out "$cmd\n";

                    print $out "\n";
                }
                next;
            }

            # OK, now that swap partitions commands have been written to the
            # autoinstall script, proceed with the other filesystems.

            # msdos or vfat
            if (($xml_config->{fsinfo}->{$line}->{fs} eq "vfat") or
                    ($xml_config->{fsinfo}->{$line}->{fs} eq "msdos")) {

                # create fs
                $cmd = "mkdosfs $mkfs_opts -v $real_dev || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                # mkdir
                $cmd = "mkdir -p /sysroot$mp || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                # mount
                $cmd = "mount $real_dev /sysroot$mp -t $fs -o $options || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                print $out "\n";

            # ext2,ext3,ext4
            } elsif (
                       ( $xml_config->{fsinfo}->{$line}->{fs} eq "ext2" ) 
                    or ( $xml_config->{fsinfo}->{$line}->{fs} eq "ext3" )
                    or ( $xml_config->{fsinfo}->{$line}->{fs} eq "ext4" )
                    ) {
                # create fs
                $cmd = "mke2fs -q -t $xml_config->{fsinfo}->{$line}->{fs} $real_dev || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                if ($mount_dev) {
                    # add LABEL if necessary
                    if ($mount_dev =~ /LABEL=/) {
                        my $label = $mount_dev;
                        $label =~ s/LABEL=//;

                        $cmd = "tune2fs -L $label $real_dev";
                        print $out qq(logmsg "$cmd"\n);
                        print $out "$cmd\n";
                    }

                    # add UUID if necessary
                    if ($mount_dev =~ /UUID=/) {
                        my $uuid = $mount_dev;
                        $uuid =~ s/UUID=//;

                        $cmd = "tune2fs -U $uuid $real_dev";
                        print $out qq(logmsg "$cmd"\n);
                        print $out "$cmd\n";
                    }
                }

                # mkdir
                $cmd = "mkdir -p /sysroot$mp || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                # mount
                $cmd = "mount $real_dev /sysroot$mp -t $fs -o $options || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                print $out "\n";

            # reiserfs
            } elsif ( $xml_config->{fsinfo}->{$line}->{fs} eq "reiserfs" ) {

                # create fs
                $cmd = "mkreiserfs -q $real_dev || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                if ($mount_dev) {
                    # add LABEL if necessary
                    if ($mount_dev =~ /LABEL=/) {
                        my $label = $mount_dev;
                        $label =~ s/LABEL=//;

                        $cmd = "reiserfstune -l $label $real_dev";
                        print $out qq(logmsg "$cmd"\n);
                        print $out "$cmd\n";
                    }

                    # add UUID if necessary
                    if ($mount_dev =~ /UUID=/) {
                        my $uuid = $mount_dev;
                        $uuid =~ s/UUID=//;

                        $cmd = "reiserfstune -u $uuid $real_dev";
                        print $out qq(logmsg "$cmd"\n);
                        print $out "$cmd\n";
                    }
                }

                # mkdir
                $cmd = "mkdir -p /sysroot$mp || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                # mount
                $cmd = "mount $real_dev /sysroot$mp -t $fs -o $options || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                print $out "\n";

            # jfs
            } elsif ( $xml_config->{fsinfo}->{$line}->{fs} eq "jfs" ) {

                # create fs
                $cmd = "jfs_mkfs -q $real_dev || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                if ($mount_dev) {
                    # add LABEL if necessary
                    if ($mount_dev =~ /LABEL=/) {
                        my $label = $mount_dev;
                        $label =~ s/LABEL=//;

                        $cmd = "jfs_tune -L $label $real_dev";
                        print $out qq(logmsg "$cmd"\n);
                        print $out "$cmd\n";
                    }

                    # add UUID if necessary
                    if ($mount_dev =~ /UUID=/) {
                        my $uuid = $mount_dev;
                        $uuid =~ s/UUID=//;

                        $cmd = "jfs_tune -U $uuid $real_dev";
                        print $out qq(logmsg "$cmd"\n);
                        print $out "$cmd\n";
                    }
                }

                # mkdir
                $cmd = "mkdir -p /sysroot$mp || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                # mount
                $cmd = "mount $real_dev /sysroot$mp -t $fs -o $options || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                print $out "\n";
	    
            # xfs
            } elsif ( $xml_config->{fsinfo}->{$line}->{fs} eq "xfs" ) {

                # create fs
                $cmd = "mkfs.xfs -f -q $real_dev || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                if ($mount_dev) {
                    # add LABEL if necessary
                    if ($mount_dev =~ /LABEL=/) {
                        my $label = $mount_dev;
                        $label =~ s/LABEL=//;

                        $cmd = "xfs_db -x -p xfs_admin -c 'label $label' $real_dev";
                        print $out qq(logmsg "$cmd"\n);
                        print $out "$cmd\n";
                    }

                    # add UUID if necessary
                    if ($mount_dev =~ /UUID=/) {
                        my $uuid = $mount_dev;
                        $uuid =~ s/UUID=//;

                        $cmd = "xfs_db -x -p xfs_admin -c 'uuid $uuid' $real_dev";
                        print $out qq(logmsg "$cmd"\n);
                        print $out "$cmd\n";
                    }
                }

                # mkdir
                $cmd = "mkdir -p /sysroot$mp || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                # mount
                $cmd = "mount $real_dev /sysroot$mp -t $fs -o $options || shellout";
                print $out qq(logmsg "$cmd"\n);
                print $out "$cmd\n";

                print $out "\n";
            }
        }
    }
}


# Description:
# Validate information in $auto_install_script_conf. -BEF-
#
# (Currently only validates line numbers, but this function is intended to be
#  expanded to do any necessary validation of this file.)
#
# Usage:
# validate_auto_install_script_conf( $auto_install_script_conf );
#
sub validate_auto_install_script_conf {

    my $file = $_[1];

    ############################################################################
    #
    # Don't allow duplicate line numbers in the fsinfo section. -BEF-
    #
    ############################################################################
    my %nodups;
    my $xml_config = XMLin($file, forcearray => 1 );
    foreach my $hash ( @{$xml_config->{fsinfo}} ) {

        $_ = ${$hash}{'line'};

        if ($nodups{$_}) {
            print qq(Doh!  There's more than one line numbered "$_" in "$file"!\n);
            print qq(We can't have that...  Please give each line a unique number.\n);
            exit 1;
        }
        $nodups{$_} = 1;
    }

}        


# Description:
# Read configuration information from /etc/systemimager/autoinstallscript.conf
# and generate commands to create an fstab file on the autoinstall client
# immediately after pulling down the image. -BEF-
#
# Usage:
# _write_out_new_fstab_file ( $image_dir, $auto_install_script_conf );
#
sub _write_out_new_fstab_file {

    my ($out, $image_dir, $file) = @_;

    my $xml_config = XMLin($file, keyattr => { fsinfo => "+line" }, forcearray => 1 );

    print $out qq(cat <<'EOF' > /sysroot/etc/fstab\n);

    foreach my $line (sort numerically (keys ( %{$xml_config->{fsinfo}} ))) {
        my $comment   = $xml_config->{fsinfo}->{$line}->{comment};
        if (defined($comment)) {
            print $out qq($comment\n);
            next;
        }
        my $mount_dev = $xml_config->{fsinfo}->{$line}->{mount_dev};
        my $real_dev = $xml_config->{fsinfo}->{$line}->{real_dev};
        unless ($mount_dev) {
            $mount_dev = $real_dev;
        }
        my $mp        = $xml_config->{fsinfo}->{$line}->{mp};
        my $options   = $xml_config->{fsinfo}->{$line}->{options};
        my $fs        = $xml_config->{fsinfo}->{$line}->{fs};
        my $dump      = $xml_config->{fsinfo}->{$line}->{dump};
        my $pass      = $xml_config->{fsinfo}->{$line}->{pass};


        # Update the root device. This will be used by systemconfigurator
        # (see below).
        if ($mp eq '/') {
            $rootdev = $mount_dev;
        } elsif ($mp eq '/boot') {
            $bootdev = $mount_dev;
        }

        print $out qq($mount_dev\t$mp\t$fs);
        if ($options)
            { print $out qq(\t$options); }

        if (defined $dump) { 
            print $out qq(\t$dump);

            # 
            # If dump don't exist, we certainly don't want to print pass
            # (it would be treated as if it were dump due to it's 
            # position), therefore we only print pass if dump is also 
            # defined.
            #
            if (defined $pass)  
                { print $out qq(\t$pass); }
        }

        # Store the real device as a comment.
        if ($real_dev) {
            if ($real_dev ne $mount_dev) {
                print $out qq(\t# $real_dev);
            }
        } else {
            print STDERR "WARNING: real_dev is not defined for $mount_dev!\n";
        }

        print $out qq(\n);
    }
    print $out qq(EOF\n);
}


# Description:
# Modify a sort so that 10 comes after 2.  
# Standard sort: (sort $numbers);               # 1,10,2,3,4,5,6,7,8,9
# Numerically:   (sort numerically $numbers);   # 1,2,3,4,5,6,7,8,9,10
#
# Usage:
# foreach my $line (sort numerically (keys ( %{hash} )))
#
sub numerically {
    $a <=> $b;
}


# Description:
# Read configuration information from /etc/systemimager/autoinstallscript.conf
# and generate commands to create an fstab file on the autoinstall client
# immediately after pulling down the image. -BEF-
#
# Usage:
# _write_out_umount_commands ( $image_dir, $auto_install_script_conf );
#
sub _write_out_umount_commands {

    my ($out, $image_dir, $file) = @_;

    my $xml_config = XMLin($file, keyattr => { fsinfo => "+line" }, forcearray => 1 );

    #
    # We can't use mp as a hash key, because not all fsinfo lines will have an 
    # mp entry.  Associate filesystems by mount points in a hash here, then we
    # can reverse sort by mount point below to unmount them all. -BEF-
    #
    my %fs_by_mp;   
    foreach my $line (reverse sort (keys ( %{$xml_config->{fsinfo}} ))) {

        if ( $xml_config->{fsinfo}->{$line}->{fs} ) { 

            #
            # We don't need to add filesystems that will not be formatted, and
            # therefore not mounted, to the list of filesystems to umount. -BEF-
            #
            my $format = $xml_config->{fsinfo}->{$line}->{format};
            if (($format) and ( "$format" eq "no")) { next; }

            my $mp = $xml_config->{fsinfo}->{$line}->{mp};
            my $fs = $xml_config->{fsinfo}->{$line}->{fs};

            # 
            # Don't include in hash below unless it's a supported filesystem. -BEF-
            #
            unless( 
                      ($fs eq "ext2") 
                   or ($fs eq "ext3") 
                   or ($fs eq "ext4") 
                   or ($fs eq "reiserfs")
                   or ($fs eq "msdos")
                   or ($fs eq "vfat")
                   or ($fs eq "jfs")
                   or ($fs eq "xfs")
                   or ($fs eq "proc")
                   or ($fs eq "sysfs")
            ) { next; }

            # 
            # Create the hash. -BEF-
            #
            $fs_by_mp{$mp} = $fs;

        }
    }

    #
    # Add this so that /proc gets umounted -- even if there is no proc entry in
    # the <fsinfo> section of the autoinstallscript.conf file.
    #
    #$fs_by_mp{'/proc'} = "proc";
    #$fs_by_mp{'/sys'} = "sysfs";

    #
    # If client uses devfs or udev, then unmount the bound /dev filesystem.
    #
    #$xml_config = XMLin($file, keyattr => { boel => "+devstyle"} );
    #if( defined($xml_config->{boel}->{devstyle}) 
    #    && (    ("$xml_config->{boel}->{devstyle}" eq "udev" )
    #         or ("$xml_config->{boel}->{devstyle}" eq "devfs") )
    #  ) {
    #    $fs_by_mp{'/dev'} = "/dev";
    #}

    #
    # Cycle through the mount points in reverse and umount those filesystems.
    # -BEF-
    #
    foreach my $mp (reverse sort (keys ( %fs_by_mp ))) {
       
        my $fs = $fs_by_mp{$mp};

        # umount
        my $cmd = "umount /sysroot$mp || mount -no remount,ro /sysroot/$mp || shellout";
        print $out qq(if [ ! \$kernel = "2.4" ]; then\n) if ($mp eq "/sys");
        print $out qq(logmsg "$cmd"\n);
        print $out "$cmd\n";
        print $out "fi\n" if ($mp eq "/sys");
        print $out "\n";
    }
}

sub show_disk_edits{
    my ($out) = shift;
    foreach (sort keys %dev2disk) {
        print $out qq(  echo " $_ -> \$$dev2disk{$_}"\n);
    }
}
sub edit_disk_names{
    my ($out) = shift;
    foreach (reverse sort keys %dev2disk) {
        print $out qq(    sed -i s:$_:\$$dev2disk{$_}:g /sysroot/\$file\n);
    }
}

# Prep the client for kexec
sub setup_kexec {
    my ($out) = shift;
    print $out "cmd=`chroot /sysroot scconf-bootinfo`\n";
    print $out "kexec_kernel=`echo \$cmd | cut -d' ' -f1`\n";
    print $out "kexec_initrd=`echo \$cmd | cut -d' ' -f3`\n";
    print $out "kexec_append=`echo \$cmd | cut -d' ' -f4-`\n";
    print $out "cp /sysroot/\$kexec_kernel /tmp\n";
    print $out "cp /sysroot/\$kexec_initrd /tmp\n";
    print $out "kexec_kernel=`basename \$kexec_kernel`\n";
    print $out "kexec_initrd=`basename \$kexec_initrd`\n";
}

#XXX use of SystemConfigurator is deprecated
#sub write_sc_command_pre {
#    my ( $out, $ip_assignment_method ) = @_;
#
#    # Fix device names in systemconfigurator config.
#    my $sc_conf_file = '/sysroot/etc/systemconfig/systemconfig.conf';
#    print $out "\n# Fix device names in boot-loader configuration.\n";
#    print $out "if [ -e $sc_conf_file ]; then\n";
#    unless ($bootdev) {
#        $bootdev = $rootdev;
#    }
#    my $bootdev_disk = $bootdev;
#    if ($bootdev_disk =~ /^\/dev\/([hs]|ps3|xv)d/) {
#        # Standard disk naming (hd*, sd*, xvd*, ps3d*).
#        $bootdev_disk =~ s/[0-9]+$//;
#    } elsif ($bootdev_disk =~ /^UUID|^LABEL/) {
#        # XXX: Boot device in UUID or LABEL form: do nothing,
#        # systemconfigurator will do everything is needed.
#    } else {
#        # Hardware RAID device.
#        $bootdev_disk =~ s/p[0-9]+$//;
#    }
#    print $out "    sed -i 's:[[:space:]]*BOOTDEV[[:space:]]*=.*:BOOTDEV = $bootdev_disk:g' $sc_conf_file\n";
#    print $out "    sed -i 's:[[:space:]]*ROOTDEV[[:space:]]*=.*:ROOTDEV = $rootdev:g' $sc_conf_file\n";
#    print $out "    sed -i 's:[[:space:]]*root=[^ \\t]*: root=$rootdev :g' $sc_conf_file\n";
#    print $out "    sed -i \"s:DEFAULTBOOT = systemimager:DEFAULTBOOT = \$IMAGENAME:g\" $sc_conf_file\n";
#    print $out "    sed -i \"s:LABEL = systemimager:LABEL = \$IMAGENAME:g\" $sc_conf_file\n";
#    print $out "fi\n";
#}

#sub write_sc_command_post {
#    my ( $out, $ip_assignment_method ) = @_;
#
#    # Configure the network device used to contact the image-server -AR-
#    print $out "\n# Configure the network interface used during the auto-installation.\n";
#    print $out "[ -z \$DEVICE ] && DEVICE=eth0\n";
#
#    my $sc_excludes_to = "/etc/systemimager/systemconfig.local.exclude";
#    my $sc_cmd = "chroot /sysroot/ systemconfigurator --verbose --excludesto=$sc_excludes_to";
#    my $sc_options = '';
#    my $sc_ps3_options = '';
#    if ($ip_assignment_method eq "replicant") {
#        $sc_options = " --runboot";
#        $sc_ps3_options = '';
#    } else {
#        ## FIXME - is --excludesto only for the static method?
#        $sc_options = '--confighw --confignet --configboot --runboot';
#        # PS3 doesn't need hardware and boot-loader configuration.
#        $sc_ps3_options = '--confignet';
#    }
#
#    print $out "\n";
#    print $out "# Run systemconfigurator.\n";
#    print $out "if grep -q PS3 /proc/cpuinfo; then\n";
#    print $out "    sc_options=\"$sc_ps3_options\"\n";
#    print $out "else\n";
#    print $out "    sc_options=\"$sc_options\"\n";
#    print $out "fi\n";
#    print $out "$sc_cmd \${sc_options} --stdin << EOL || shellout\n";
#
#    unless ($ip_assignment_method eq "replicant") {
#	print $out "[NETWORK]\n";
#	print $out "HOSTNAME = \$HOSTNAME\n";
#	print $out "DOMAINNAME = \$DOMAINNAME\n";
#    }
#    if ($ip_assignment_method eq "static") {
#	print $out "GATEWAY = \$GATEWAY\n";
#    }
#    print $out "\n";
#
#    print $out "[INTERFACE0]\n";
#    print $out "DEVICE = \$DEVICE\n";
#
#    if ($ip_assignment_method eq "dhcp") {
#	print $out "TYPE = dhcp\n";
#    }
#    elsif ($ip_assignment_method eq "static") {
#	print $out "TYPE = static\n";
#	print $out "IPADDR = \$IPADDR\n";
#	print $out "NETMASK = \$NETMASK\n";
#    }
#
#    print $out "EOL\n";
#}


sub append_variables_txt_with_ip_assignment_method {
    my ( $out, $ip_assignment_method ) = @_;

    # 
    # Potential values include:
    #   replicant
    #   static
    #   dhcp
    #
    print $out "echo IP_ASSIGNMENT_METHOD=$ip_assignment_method >> /tmp/variables.txt\n\n";
}

#    my ( $out, $ip_assignment_method ) = @_;
#
#    # Configure the network device used to contact the image-server -AR-
#    print $out "\n# Configure the network interface used during the auto-installation.\n";
#    print $out "[ -z \$DEVICE ] && DEVICE=eth0\n";
#
#    my $sc_excludes_to = "/etc/systemimager/systemconfig.local.exclude";
#    my $sc_cmd = "chroot /sysroot/ systemconfigurator --verbose --excludesto=$sc_excludes_to";
#    my $sc_options = '';
#    my $sc_ps3_options = '';
#    if ($ip_assignment_method eq "replicant") {
#        $sc_options = " --runboot";
#        $sc_ps3_options = '';
#    } else {
#        ## FIXME - is --excludesto only for the static method?
#        $sc_options = '--confighw --confignet --configboot --runboot';
#        # PS3 doesn't need hardware and boot-loader configuration.
#        $sc_ps3_options = '--confignet';
#    }
#
#    print $out "\n";
#    print $out "# Run systemconfigurator.\n";
#    print $out "if grep -q PS3 /proc/cpuinfo; then\n";
#    print $out "    sc_options=\"$sc_ps3_options\"\n";
#    print $out "else\n";
#    print $out "    sc_options=\"$sc_options\"\n";
#    print $out "fi\n";
#    print $out "$sc_cmd \${sc_options} --stdin << EOL || shellout\n";
#
#    unless ($ip_assignment_method eq "replicant") {
#	print $out "[NETWORK]\n";
#	print $out "HOSTNAME = \$HOSTNAME\n";
#	print $out "DOMAINNAME = \$DOMAINNAME\n";
#    }
#    if ($ip_assignment_method eq "static") {
#	print $out "GATEWAY = \$GATEWAY\n";
#    }
#    print $out "\n";
#
#    print $out "[INTERFACE0]\n";
#    print $out "DEVICE = \$DEVICE\n";
#
#    if ($ip_assignment_method eq "dhcp") {
#	print $out "TYPE = dhcp\n";
#    }
#    elsif ($ip_assignment_method eq "static") {
#	print $out "TYPE = static\n";
#	print $out "IPADDR = \$IPADDR\n";
#	print $out "NETMASK = \$NETMASK\n";
#    }
#
#    print $out "EOL\n";
#}


sub create_autoinstall_script{

    my (  
        $module, 
        $script_name, 
        $auto_install_script_dir, 
        $config_dir, 
        $image, 
        $overrides, 
        $image_dir, 
        $ip_assignment_method, 
        $post_install,
        $listing,
        $auto_install_script_conf,
        $autodetect_disks,
        $cmdline
    ) = @_;

    my $cmd;

    # Truncate the /etc/mtab file.  It can cause confusion on the autoinstall
    # client, making it think that filesystems are mounted when they really
    # aren't.  And because it is automatically updated on running systems, we
    # don't really need it for anything anyway. -BEF-
    #
    # We don't just remove it because, at least in the case of RedHat,
    # /proc/bus/usb will not be mounted and usb will not work the first time
    # the system boots because it fails to truncate a non-existant /etc/mtab
    #
    my $file="$image_dir/etc/mtab";
    if (-f $file) {
        open(MTAB, ">$file") || die "Can't open $file for truncating\n";
        close(MTAB);
    }
    
    $file = "$auto_install_script_dir/$script_name.master";
    my $template = "/etc/systemimager/autoinstallscript.template";
    open (my $TEMPLATE, "<$template") || die "Can't open $template for reading\n";
    open (my $MASTER_SCRIPT, ">$file") || die "Can't open $file for writing\n";

    $disk_no = 0;
    %dev2disk = ();

    my $delim = '##';
    while (<$TEMPLATE>) {
        SWITCH: {
            if (/^\s*${delim}SI_CREATE_AUTOINSTALL_SCRIPT_CMD${delim}\s*$/) {
                print $MASTER_SCRIPT "# $cmdline\n";
                last SWITCH;
            }
	        if (/^\s*${delim}VERSION_INFO${delim}\s*$/) {
	            print $MASTER_SCRIPT "# This master autoinstall script was created with SystemImager v${VERSION}\n";
	            last SWITCH;
	        }

	        if (/^\s*${delim}SET_IMAGENAME${delim}\s*$/) {
                print $MASTER_SCRIPT  q([ -z $IMAGENAME ] && ) . qq(IMAGENAME=$image\n);
	            last SWITCH;
	        }

	        if (/^\s*${delim}SET_OVERRIDES${delim}\s*$/) {
                if ($overrides) {
                    $overrides =~ s/,/ /g;
                    my @list = ();
                    foreach (split(/ /, $overrides)) {
                        if (-d $::main::config->default_override_dir() . '/' . $_) {
                            push(@list, $_);
                        } else {
                            print STDERR "WARNING: override $_ doesn't exist! (skipping)\n";
                        }
                    }
                    $overrides = join(' ', @list);
                } else {
                    $overrides = '';
                }
                print $MASTER_SCRIPT  q([ -z $OVERRIDES ] && ) .
                                      qq(OVERRIDES="$script_name \$GROUP_OVERRIDES \$HOSTNAME $overrides"\n);
	            last SWITCH;
	        }

	        if (/^\s*${delim}SET_DISKORDER${delim}\s*$/) {
                    # Set or unset disk autodetection.
                    if ($autodetect_disks) {
                        print $MASTER_SCRIPT qq(DISKORDER=sd,cciss,ida,rd,hd,xvd\n);
                    } else {
                        print $MASTER_SCRIPT qq(DISKORDER=\n);
                    }
	            last SWITCH;
	        }

	        if (/^\s*${delim}PARTITION_DISKS${delim}\s*$/) { 
	            _read_partition_info_and_prepare_parted_commands( $MASTER_SCRIPT,
	          						$image_dir, 
	          						$auto_install_script_conf);
	            last SWITCH;
	        }

                if (/^\s*${delim}CREATE_SOFT_RAID_DISKS${delim}\s*$/) { 
                _read_partition_info_and_prepare_soft_raid_devs( $MASTER_SCRIPT,
                    $image_dir, 
                    $auto_install_script_conf);
                    last SWITCH;
                }

                if (/^\s*${delim}INITIALIZE_LVM_PARTITIONS${delim}\s*$/) {
 	            _read_partition_info_and_prepare_pvcreate_commands( $MASTER_SCRIPT,
 	          						$image_dir,
 	          						$auto_install_script_conf);
                     last SWITCH;
                }

                if (/^\s*${delim}CREATE_LVM_GROUPS${delim}\s*$/) {
                    write_lvm_groups_commands( $MASTER_SCRIPT,
                                            $image_dir,
                                            $auto_install_script_conf);
                     last SWITCH;
                }

                if (/^\s*${delim}CREATE_LVM_VOLUMES${delim}\s*$/) {
                     write_lvm_volumes_commands( $MASTER_SCRIPT,
                                            $image_dir,
                                            $auto_install_script_conf);
                     last SWITCH;
                }
	        
                if (/^\s*${delim}CREATE_FILESYSTEMS${delim}\s*$/) {
	            _write_out_mkfs_commands( $MASTER_SCRIPT, 
	          			$image_dir, 
	          			$auto_install_script_conf);
	            last SWITCH;
	        }

	        if (/^\s*${delim}GENERATE_FSTAB${delim}\s*$/) {
                append_variables_txt_with_ip_assignment_method( $MASTER_SCRIPT, $ip_assignment_method );
	            _write_out_new_fstab_file( $MASTER_SCRIPT, 
	          			 $image_dir, 
	          			 $auto_install_script_conf );
	            last SWITCH;
	        }

	        if (/^\s*${delim}NO_LISTING${delim}\s*$/) {
	            unless ($listing) { print $MASTER_SCRIPT "NO_LISTING=yes\n"; }
	            last SWITCH;
	        }
            
            #if (/^\s*${delim}BOEL_DEVSTYLE${delim}\s*$/) {
            #_write_boel_devstyle_entry($MASTER_SCRIPT, $auto_install_script_conf);
            #    #    last SWITCH;
            #}

            #if (/^\s*${delim}SYSTEMCONFIGURATOR_PRE${delim}\s*$/) {
            #    write_sc_command_pre($MASTER_SCRIPT, $ip_assignment_method);
            #    last SWITCH;
            #}

            #if (/^\s*${delim}SYSTEMCONFIGURATOR_POST${delim}\s*$/) {
            #    write_sc_command_post($MASTER_SCRIPT, $ip_assignment_method);
            #    last SWITCH;
            #}

	        if (/^\s*${delim}UMOUNT_FILESYSTEMS${delim}\s*$/) {
	            _write_out_umount_commands( $MASTER_SCRIPT,
	          			  $image_dir, 
	          			  $auto_install_script_conf );
	            last SWITCH;
	        }

	        if (/^\s*${delim}MONITOR_POSTINSTALL${delim}\s*/) {
                    my $post_state = {'beep' => 103, 'reboot' => 104, 'kexec' => 104, 'shutdown' => 105, 'shell' => 106 };
                    print $MASTER_SCRIPT "    send_monitor_msg \"status=$post_state->{$post_install}:speed=0\"\n";
                    last SWITCH;
                }

	        if (/^\s*${delim}POSTINSTALL${delim}\s*/) {
	            
                if ($post_install eq "beep") {
                    # beep incessantly stuff
                    print $MASTER_SCRIPT "beep_incessantly";
                } elsif ($post_install eq "reboot") {
                    # reboot stuff
                    print $MASTER_SCRIPT "# reboot the autoinstall client\n";
                    print $MASTER_SCRIPT "echo reboot > /tmp/SIS_action\n";
                } elsif ($post_install eq "shutdown") {
                    # shutdown stuff
                    print $MASTER_SCRIPT "# shutdown the autoinstall client\n";
                    print $MASTER_SCRIPT "echo shutdown > /tmp/SIS_action\n";
                } elsif ($post_install eq "shell") {
                    # shell stuff
                    print $MASTER_SCRIPT "# Drop to debug shell\n";
                    print $MASTER_SCRIPT "echo shell > /tmp/SIS_action\n";
                } elsif ($post_install eq "kexec") {
                    # kexec imaged kernel
                    print $MASTER_SCRIPT "# kexec the autoinstall client\n";
                    print $MASTER_SCRIPT "echo kexec > /tmp/SIS_action\n";
                    # BUG: OL: Need full rework. kexec_append was computed using systemconfigurator scconf-bootinfo which is no longer supported
                    #print $MASTER_SCRIPT "# this is executed twice to support relocatable kernels from RHEL5\n";
                    #print $MASTER_SCRIPT "kexec --force --append=\"\$kexec_append\" --initrd=/tmp/\$kexec_initrd --reset-vga /tmp/\$kexec_kernel\n";
                    #print $MASTER_SCRIPT "kexec --force --append=\"\$kexec_append\" --initrd=/tmp/\$kexec_initrd --reset-vga --args-linux /tmp/\$kexec_kernel\n";
                }
                last SWITCH;
	        }

			if (/^\s*${delim}SHOW_DISK_EDITS${delim}\s*$/) {
				show_disk_edits( $MASTER_SCRIPT );
				last SWITCH;
			}
			if (/^\s*${delim}EDIT_DISK_NAMES${delim}\s*$/) {
				edit_disk_names( $MASTER_SCRIPT );
				last SWITCH;
			}

			if (/^\s*${delim}SETUP_KEXEC${delim}\s*$/) {
                if ($post_install eq "kexec") {
                    setup_kexec( $MASTER_SCRIPT );
                } else {
                    print $MASTER_SCRIPT "# Not needed for this post-install action\n";
                }
                last SWITCH;
            }

	        ### END end of autoinstall options ###
	        print $MASTER_SCRIPT $_;
        }
    }
    close($TEMPLATE);

    ### BEGIN overrides stuff ###
    # Create default overrides directory. -BEF-
    #
    my $override_dir = $config->default_override_dir;
    my $dir = "$override_dir/$script_name";
    if (! -d "$dir")  {
      mkdir("$dir", 0755) or die "FATAL: Can't make directory $dir\n";
      # Be sure to properly set the correct permissions bitmask in the
      # overrides, in fact according to MKDIR(2):
      #
      # [...] the permissions of the created directory are (mode & ~umask & 0777).
      #
      # A non-standard permission mask in the root of the clients can lead to
      # serious problems, so it's better to enforce the right bitmask directly
      # using a chmod() after the mkdir().
      #
      # The best solution here is to use the same permission mask of the image.
      chmod(((stat($image_dir))[2] & 07777), "$dir");
    }  
    
    close($MASTER_SCRIPT);
} # sub create_autoinstall_script 



# Description:
# Removes a mount option from a comma seperated option list.
#
# Usage:
# $options = _remove_mount_option($options, $pattern_to_remove);
# $options = _remove_mount_option($options, "errors=remount-ro");
#
sub _remove_mount_option {

    my ($options, $regex) = @_;

    my @array = split (/,/, $options);

    my $new_options = "";
    foreach (@array) {
        unless (m/$regex/) {
            if ("$new_options" eq "") {
                # First run through
                $new_options = "$_";
            } else {
                $new_options .= ",$_";
            }
        }
    }

    # We always use -o $options in the autoinstall script generation code,
    # so we return "defaults" rather than a null value. -BEF-
    unless($new_options) {
        $new_options = "defaults";
    }

    return $new_options;
}


# Description:
# Copy files needed for autoinstall floppy or CD to boot media or boot image.
#
# Usage:
# copy_boot_files_to_boot_media($kernel, $initrd, $local_cfg, $arch, $mnt_dir, $append_string);
sub copy_boot_files_to_boot_media {

    my ($class, $kernel, $initrd, $local_cfg, $arch, $mnt_dir, $append_string, $ssh_key) = @_;

    my $message_txt = "/etc/systemimager/pxelinux.cfg/message.txt";
    my $syslinux_cfg = "/etc/systemimager/pxelinux.cfg/syslinux.cfg";

    ############################################################################
    #
    #   Copy standard files to mount dir
    #
    my $cmd = "df $mnt_dir ; umount $mnt_dir";
    unless( copy($kernel, "$mnt_dir/kernel") ) {
        system($cmd);
        die "Couldn't copy $kernel to $mnt_dir!\n";
    }

    unless( copy($initrd, "$mnt_dir/initrd.img") ) {
        system($cmd);
        die "Couldn't copy $initrd to $mnt_dir!\n";
    }

    unless( copy($message_txt, "$mnt_dir/message.txt") ) {
        system($cmd);
        die "Couldn't copy $message_txt to $mnt_dir!\n";
    }

    if($local_cfg) {
        unless( copy($local_cfg, "$mnt_dir/local.cfg") ) {
            system($cmd);
            die "Couldn't copy $local_cfg to $mnt_dir!\n";
        }
    }

    if($ssh_key) {
        unless( copy($ssh_key, $mnt_dir) ) {
            system($cmd);
            die "Couldn't copy $ssh_key to $mnt_dir!\n";
        }
    }

    # Unless an append string was given on the command line, just copy over.
    unless ($append_string) {
        unless( copy("$syslinux_cfg","$mnt_dir/syslinux.cfg") ) {
            system($cmd);
            die "Couldn't copy $syslinux_cfg to $mnt_dir!\n";
        }
    } else {
        # Append to APPEND line in config file.
        my $infile = "$syslinux_cfg";
        my $outfile = "$mnt_dir/syslinux.cfg";
        open(INFILE,"<$infile") or croak("Couldn't open $infile for reading.");
            open(OUTFILE,">$outfile") or croak("Couldn't open $outfile for writing.");
                while (<INFILE>) {
                    if (/^\s*APPEND\s+/) { 
                        chomp;
		      # Limit of 255 specified in Documentation/i386/boot.txt
                        $_ = $_ . " $append_string\n";
			croak("kernel boot parameter string too long") unless (length() <= 255);
                    }
                    print OUTFILE;
                }
            close(OUTFILE);
        close(INFILE);
    }
    #
    ############################################################################


    ############################################################################
    #
    #   Do ia64 specific stuff
    #
    if ($arch eq "ia64") {

        use SystemImager::Common;

        my $efi_dir = SystemImager::Common->where_is_my_efi_dir();

        my $elilo_efi = "$efi_dir/elilo.efi";

        if (-f $elilo_efi) {
            copy($elilo_efi,  "$mnt_dir/elilo.efi") or croak("Couldn't copy $elilo_efi to $mnt_dir/elilo.efi $!");
        } else {
            print "\nCouldn't find elilo.efi executable. \n";
            print "You can download elilo from ftp://ftp.hpl.hp.com/pub/linux-ia64/.\n";
            print "If elilo.efi is already installed on your system, please submit a bug report, including\n";
            print "the location of your elilo.efi file, at: http://systemimager.org/support/\n\n";
            die;
        }

        _write_elilo_conf("$mnt_dir/elilo.conf", $append_string);

    }
    #
    ############################################################################
    
    return 1;

}



#XXX why are we creating a new elilo.conf file?  Shouldn't we work with the one the system provides?  -BEF-
# Description:
# Write new elilo.conf file to boot media
#
# Usage:
# _write_elilo_conf($file, $append_string);
sub _write_elilo_conf {

        my ($file, $append_string) = @_;
        
        open(ELILO_CONF,">$file") or croak("Couldn't open $file for writing.");
        
                print ELILO_CONF "timeout=20\n";
                
                if ($append_string) { 
                        print ELILO_CONF qq(append="$append_string"\n);
                }
                
                print ELILO_CONF "image=kernel\n";
                print ELILO_CONF "  label=linux\n";
                print ELILO_CONF "  read-only\n";
                print ELILO_CONF "  initrd=initrd.img\n";
                print ELILO_CONF "  root=/dev/ram\n";
        
        close(ELILO_CONF);
        return 1;
}


#
# Description:
#   Decide whether to "mount /dev /sysroot/dev -o bind", and write to master
#   autoinstall script.  
#
#   Clients should have one of the following entries in their 
#   autoinstallscript.conf file:
#
#       <boel devstyle="udev"/>
#       <boel devstyle="devfs"/>
#       <boel devstyle="static"/>
#
#   
# Usage:
#   _write_boel_devstyle_entry($MASTER_SCRIPT, $auto_install_script_conf);
#
#XXX no longer needed
#sub _write_boel_devstyle_entry {
#
#    my ($script, $file) = @_;
#
#    my $xml_config = XMLin($file, keyattr => { boel => "+devstyle"} );
#
#    if( defined($xml_config->{boel}->{devstyle}) 
#        && (    ("$xml_config->{boel}->{devstyle}" eq "devfs")
#             or ("$xml_config->{boel}->{devstyle}" eq "udev" ) )
#      ) {
#
#        my $cmd = q(mount /dev /sysroot/dev -o bind || shellout);
#        print $script qq(logmsg "$cmd"\n);
#        print $script qq($cmd\n);
#        
#    } else {
#
#        print $script qq(#not needed for this image\n);
#        
#    }
#}


# /* vi: set filetype=perl ai et ts=4 sw=4: */
