#
# "SystemImager" 
#
#  Copyright (C) 1999-2002 Brian Elliott Finley <bef@bgsw.net>
#  Copyright (C) 2002 Bald Guy Software
#                     Brian Elliott Finley <bef@bgsw.net>
#
#   $Id$
#

package SystemImager::Server;

use lib "USR_PREFIX/lib/systemimager/perl";
use Carp;
use strict;
use File::Copy;
use File::Path;
use XML::Simple;
use vars qw($VERSION @mount_points %device_by_mount_point %filesystem_type_by_mount_point);

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
#   _write_elilo_conf
#   _write_out_mkfs_commands 
#   _write_out_new_fstab_file 
#   _write_out_umount_commands 
#   add2rsyncd 
#   copy_boot_files_to_boot_media
#   create_autoinstall_script
#   create_image_stub 
#   gen_rsyncd_conf 
#   get_full_path_to_image_from_rsyncd_conf 
#   get_image_path 
#   ip_quad_2_ip_hex
#   numerically 
#   remove_boot_file
#   remove_image_stub 
#   upgrade_partition_schemes_to_generic_style 
#   validate_auto_install_script_conf 
#   validate_ip_assignment_option 
#   validate_post_install_option 
#
################################################################################


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

  unless(($post_install eq "beep") or ($post_install eq "reboot") or ($post_install eq "shutdown")) { 
    die qq(\nERROR: -post-install must be beep, reboot, or shutdown.\n\n       Try "-help" for more options.\n);
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

sub get_image_path {
    my ($class,  $stub_dir, $imagename) = @_;

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
# my $path = SystemImager::Server->get_image_path( $rsync_stub_dir, $image );
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
    my @array = ( "ida", "cciss", "rd" );
    
    foreach my $dir (@array) {
	if ($disk =~ /^\/dev\/$dir\/c\d+d\d+$/) {
	    return $disk . "/part" . $num;
	}
    }
    return $disk . $num;
}

# Usage:  
# _read_partition_info_and_prepare_parted_commands( $image_dir, $auto_install_script_conf );
sub _read_partition_info_and_prepare_parted_commands {

    my ($image_dir, $file) = @_;

    my $xml_config = XMLin($file, keyattr => { disk => "+dev", part => "+num" }, forcearray => 1 );  

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

        my $devfs_dev = &dev_to_devfs($dev);

        print MASTER_SCRIPT "### BEGIN partition $devfs_dev ###\n";
        print MASTER_SCRIPT qq(echo "Partitioning $devfs_dev..."\n);
        print MASTER_SCRIPT qq(echo "Old partition table for $devfs_dev:"\n);
        print MASTER_SCRIPT "parted -s -- $devfs_dev print\n\n";

        print MASTER_SCRIPT "# Create disk label.  This ensures that all remnants of the old label, whatever\n";
        print MASTER_SCRIPT "# type it was, are removed and that we're starting with a clean label.\n";
        $cmd = "parted -s -- $devfs_dev mklabel $label_type || shellout";
        print MASTER_SCRIPT qq(echo "$cmd"\n);
        print MASTER_SCRIPT "$cmd\n\n";

        print MASTER_SCRIPT "# Get the size of the destination disk so that we can make the partitions fit properly.\n";
        print MASTER_SCRIPT qq(DISK_SIZE=`parted -s $devfs_dev print ) . q(| grep 'Disk geometry for' | sed 's/^.*-//g' | sed 's/\..*$//' `) . qq(\n);
        print MASTER_SCRIPT q([ -z $DISK_SIZE ] && shellout) . qq(\n);
        print MASTER_SCRIPT qq(END_OF_LAST_PRIMARY=0\n);

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
                $startMB{$m} = q($END_OF_LAST_LOGICAL);
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
            print MASTER_SCRIPT "\n";
	    
            $part = &get_part_name($dev, $m);
            $cmd = "Creating partition $part.";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            
            print MASTER_SCRIPT qq(START_MB=$startMB{$m}\n);
            print MASTER_SCRIPT qq(END_MB=$endMB{$m}\n);

            if($p_type{$m} eq "extended") {

                $cmd = qq(parted -s -- $devfs_dev mkpart $p_type{$m} ) . q($START_MB $END_MB) . qq( || shellout);

            } else {

                #
                # parted *always* (except for extended partitions) requires that you 
                # specify a filesystem type, even though it does nothing with it 
                # with the "mkpart" command. -BEF-
                #
                $cmd = qq(parted -s -- $devfs_dev mkpart $p_type{$m} ext2 ) . q($START_MB $END_MB) . qq( || shellout);

            }
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";
            
            # Leave info behind for the next partition. -BEF-
            if ("$p_type{$m}" eq "primary") {
                print MASTER_SCRIPT q(END_OF_LAST_PRIMARY=$END_MB) . qq(\n);
            
            } elsif ("$p_type{$m}" eq "extended") {
                print MASTER_SCRIPT q(END_OF_LAST_PRIMARY=$END_MB) . qq(\n);
                print MASTER_SCRIPT q(END_OF_LAST_LOGICAL=$START_MB) . qq(\n);
            
            } elsif ("$p_type{$m}" eq "logical") {
                print MASTER_SCRIPT q(END_OF_LAST_LOGICAL=$END_MB) . qq(\n);
            }
            
            #
            # If $id is set for a partition, we invoke sfdisk to tag the partition
            # id appropriately.  parted is lame (in the true sense of the word) in 
            # this regard and is incapable of # adding an arbitrary id to a 
            # partition. -BEF-
            #
            if ($id{$m}) {
                print MASTER_SCRIPT qq(# Use sfdisk to change the partition id.  parted is\n);
                print MASTER_SCRIPT qq(# incapable of this particular operation.\n);
                print MASTER_SCRIPT qq(sfdisk --change-id $devfs_dev $m $id{$m} \n);
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
              print MASTER_SCRIPT "echo $cmd";
              print MASTER_SCRIPT "$cmd";
            }
            
            ### Deal with flags for each partition. -BEF-
            if(($flags{$m}) and ($flags{$m} ne "-")) {
            
                # $flags{$m} will look something like "boot,lba,raid" or "boot" at this point.
                my @flags = split (/,/, $flags{$m});
                
                foreach my $flag (@flags) {
                    # Parted 1.6.0 doesn't seem to want to tag gpt partitions with lba.  Hmmm. -BEF-
                    if (($flag eq "lba") and ($label_type eq "gpt")) { next; }
                    $cmd = "parted -s -- $devfs_dev set $m $flag on || shellout\n";
                    print MASTER_SCRIPT "echo $cmd";
                    print MASTER_SCRIPT "$cmd";
                }
            }
        }

        # Kick the minors out.  (remove temporary partitions) -BEF-
        foreach $m (keys %minors_to_remove) {
          print MASTER_SCRIPT "\n# Gotta lose this one (${dev}${m}) to make the disk look right.\n";
          $cmd = "parted -s -- $devfs_dev rm $m  || shellout";
          print MASTER_SCRIPT qq(echo "$cmd"\n);
          print MASTER_SCRIPT "$cmd\n";
        }

        print MASTER_SCRIPT "\n";
        print MASTER_SCRIPT qq(echo "New partition table for $devfs_dev:"\n);
        $cmd = "parted -s -- $devfs_dev print";
        print MASTER_SCRIPT qq(echo "$cmd"\n);
        print MASTER_SCRIPT "$cmd\n";
        print MASTER_SCRIPT "### END partition $devfs_dev ###\n";
        print MASTER_SCRIPT "\n";
        print MASTER_SCRIPT "\n";
    }
}


sub _in_script_add_standard_header_stuff {
  my ($image, $script_name) = @_;
  print MASTER_SCRIPT << 'EOF';
#!/bin/sh

#
# "SystemImager"
#
#  Copyright (C) 1999-2001 Brian Elliott Finley <brian.finley@baldguysoftware.com>
#  Copyright (C) 2002 Bald Guy Software <brian.finley@baldguysoftware.com>
#
EOF

  print MASTER_SCRIPT "# This master autoinstall script was created with SystemImager v$VERSION\n";
  print MASTER_SCRIPT "\n";
  print MASTER_SCRIPT "VERSION=$VERSION\n";

  print MASTER_SCRIPT << 'EOF';

PATH=/sbin:/bin:/usr/bin:/usr/sbin:/tmp
ARCH=`uname -m \
| sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/`

shellout() {
    exec cat /etc/issue ; exit 1
}

mcast_group+2() {
    MCAST_GROUP=$(echo "scale=3; ($MCAST_GROUP + 2)" | bc)
}

# Pull in variables left behind by the linuxrc script.
# This information is passed from the linuxrc script on the autoinstall media 
# via /tmp/variables.txt.  Apparently the shell we use in BOEL is not 
# intelligent enough to take a "set -a" parameter.
#
. /tmp/variables.txt || shellout

EOF

  print MASTER_SCRIPT  q([ -z $IMAGENAME ] && ) . qq(IMAGENAME=$image\n);
  print MASTER_SCRIPT  q([ -z $OVERRIDES ] && ) . qq(OVERRIDES="$script_name"\n);
  print MASTER_SCRIPT << 'EOF';

### BEGIN Check to be sure this not run from a working machine ###
# Test for mounted SCSI or IDE disks
mount | grep [hs]d[a-z][1-9] > /dev/null 2>&1
[ $? -eq 0 ] &&  echo Sorry.  Must not run on a working machine... && shellout

# Test for mounted software RAID devices
mount | grep md[0-9] > /dev/null 2>&1
[ $? -eq 0 ] &&  echo Sorry.  Must not run on a working machine... && shellout

# Test for mounted hardware RAID disks
mount | grep c[0-9]+d[0-9]+p > /dev/null 2>&1
[ $? -eq 0 ] &&  echo Sorry.  Must not run on a working machine... && shellout
### END Check to be sure this not run from a working machine ###


### BEGIN Stop RAID devices before partitioning begins ###
# Q1) Why did they get started in the first place?  
# A1) So we can pull a local.cfg file off a root mounted software RAID system.
#     They may not be started on your system -- they would only be started if
#     you did the stuff in Q3 below.
#
# Q2) Why didn't my local.cfg on my root mounted software RAID work for me 
#     with the standard kernel flavour?
# A2) The standard kernel flavour uses modules for the software RAID drivers --
#     therefore, software RAID is not available at the point in the boot process
#     where BOEL needs to read the local.cfg file.  They are only pulled over 
#     when this script is run, which is, of course, only runnable if it was
#     pulled over the network using the settings that you would have wanted it
#     to get from the local.cfg file, which it couldn't.  Right?
#
# Q3) Whatever.  So how do I make it work with a local.cfg file on my root
#     mounted software RAID?  
# A3) Compile an autoinstall kernel with software RAID, and any other drivers 
#     you might need built in (filesystem, SCSI drivers, etc.).
#
# Find running raid devices
if [ -f /proc/mdstat ]; then
  RAID_DEVICES=` cat /proc/mdstat | grep ^md | sed 's/ .*$//g' `

  # raidstop will not run unless a raidtab file exists
  echo "" >> /etc/raidtab || shellout

  # turn dem pesky raid devices off!
  for RAID_DEVICE in ${RAID_DEVICES}
  do
    DEV="/dev/${RAID_DEVICE}"
    # we don't do a shellout here because, well I forgot why, but we don't.
    echo "raidstop ${DEV}" && raidstop ${DEV}
  done
fi
### END Stop RAID devices before partitioning begins ###


EOF
}


sub _mount_proc_in_image_on_client {

    #  The following allows a proc filesystem to be mounted in the fakeroot.
    #  This provides /proc to programs which are called by SystemImager
    #  (eg. System Configurator).

    print MASTER_SCRIPT "### BEGIN mount proc in image for tools like System Configurator ###\n";
    my $cmd = "mkdir -p /a/proc || shellout";
    print MASTER_SCRIPT qq(echo "$cmd"\n);
    print MASTER_SCRIPT "$cmd\n";
    $cmd = "mount proc /a/proc -t proc -o defaults || shellout";
    print MASTER_SCRIPT qq(echo "$cmd"\n);
    print MASTER_SCRIPT "$cmd\n";
    print MASTER_SCRIPT "### END mount proc in image for tools like System Configurator ###\n";
    print MASTER_SCRIPT "\n";
    print MASTER_SCRIPT "\n";

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
# dev_to_devfs( $dev );
#
sub dev_to_devfs {
    my ($dev) = @_;

    ## disks
    if ($dev =~ m{^/dev/(.*)/c(\d+)d(\d+)$}) {
        if ($1 eq "cciss") {
            return "/dev/" . $1 . "/disc" . $3 . "/disc";
        }
        else {
            return "/dev/" . $1 . "/c" . $2. "d" . $3 . "/disc";
        }
    }
    ## partitions
    elsif ($dev =~ m{^/dev/(.*)/c(\d+)d(\d+)p(\d+)$}) {
        ## the controller number is not taken into account here.
        ## its unknown how this should work w/ multiple controllers.
        if ($1 eq "cciss") {
            return "/dev/" . $1 . "/disc" . $3 . "/part" . $4;
        }
        else {
            return "/dev/" . $1 . "/c" . $2 . "d" . $3 . "/part" . $4;
        }
    }
    return $dev;
}


# Description:
# Read configuration information from /etc/systemimager/autoinstallscript.conf
# and write filesystem creation commands to the autoinstall script. -BEF-
#
# Usage:
# _write_out_mkfs_commands( $image_dir, $auto_install_script_conf );
#
sub _write_out_mkfs_commands {

    my ($image_dir, $file) = @_;

    my $xml_config = XMLin($file, keyattr => { fsinfo => "+line" }, forcearray => 1 );

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

    print MASTER_SCRIPT "### BEGIN swap and filesystem creation commands ###\n";
    print MASTER_SCRIPT qq(echo "Load additional filesystem drivers."\n);
    print MASTER_SCRIPT "modprobe reiserfs\n";
    print MASTER_SCRIPT "modprobe ext2\n";
    print MASTER_SCRIPT "modprobe ext3\n";
    print MASTER_SCRIPT "modprobe jfs\n";
    print MASTER_SCRIPT "modprobe xfs\n";
    print MASTER_SCRIPT "\n";


    if ($software_raid) {

        print MASTER_SCRIPT qq(# Must remove the /etc/raidtab created for the raidstop commands above.\n);
        print MASTER_SCRIPT qq(rm -f /etc/raidtab\n);
        print MASTER_SCRIPT qq(echo\n);
        print MASTER_SCRIPT qq(echo "Pull /etc/raidtab in image over to autoinstall client."\n);
        print MASTER_SCRIPT qq(rsync -av --numeric-ids \$IMAGESERVER::\$IMAGENAME/etc/raidtab /etc/raidtab || echo "No /etc/raidtab in the image directory, hopefully there's one in an override directory."\n);
      
        print MASTER_SCRIPT qq(echo "Pull /etc/raidtab from each override to autoinstall client."\n);
        print MASTER_SCRIPT  q(for OVERRIDE in $OVERRIDES) . qq(\n);
        print MASTER_SCRIPT qq(do\n);
        print MASTER_SCRIPT  q(    rsync -av --numeric-ids $IMAGESERVER::overrides/$OVERRIDE/etc/raidtab /etc/raidtab || echo "No /etc/raidtab in override $OVERRIDE, but that should be OK.") . qq(\n);
        print MASTER_SCRIPT qq(    echo\n);
        print MASTER_SCRIPT qq(done\n);

        print MASTER_SCRIPT qq(if [ -e /etc/raidtab ]; then\n);
		print MASTER_SCRIPT qq(    echo "Ah, good.  Found an /etc/raidtab file.  Proceeding..."\n);
		print MASTER_SCRIPT qq(else\n);
		print MASTER_SCRIPT qq(    echo "No /etc/raidtab file.  Please verify that you have one in your image, or in an override directory."\n);
		print MASTER_SCRIPT qq(    shellout\n);
		print MASTER_SCRIPT qq(fi\n);

        print MASTER_SCRIPT "\n";
        print MASTER_SCRIPT "# Load RAID modules, if necessary, and create software RAID devices.\n";
        print MASTER_SCRIPT "if [ ! -f /proc/mdstat ]; then\n";
        print MASTER_SCRIPT "  modprobe linear\n";
        print MASTER_SCRIPT "  modprobe raid0\n";
        print MASTER_SCRIPT "  modprobe raid1\n";
        print MASTER_SCRIPT "  modprobe raid5\n";
        print MASTER_SCRIPT "fi\n";
        print MASTER_SCRIPT "\n";

    }


    foreach my $line (sort numerically (keys ( %{$xml_config->{fsinfo}} ))) {
        
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

        my $real_dev = &dev_to_devfs($xml_config->{fsinfo}->{$line}->{real_dev});
        my $mp = $xml_config->{fsinfo}->{$line}->{mp};
        my $fs = $xml_config->{fsinfo}->{$line}->{fs};
        my $options = $xml_config->{fsinfo}->{$line}->{options};
        my $mkfs_opts = $xml_config->{fsinfo}->{$line}->{mkfs_opts};
        unless ($mkfs_opts) { $mkfs_opts = ""; }

        # Remove options that may cause problems and are unnecessary during the install.
        $options = _remove_mount_option($options, "errors=remount-ro");

        # Deal with filesystems to be mounted read only (ro) after install.  We 
        # still need to write to them to install them. ;)
        $options =~ s/\bro\b/rw/g;

        # software RAID devices (/dev/md*)
        if ($real_dev =~ /\/dev\/md/) {
            print MASTER_SCRIPT qq(mkraid --really-force $real_dev || shellout\n);
        }

        # swap
        if ( $xml_config->{fsinfo}->{$line}->{fs} eq "swap" ) {

            # create swap
            $cmd = "mkswap -v1 $real_dev || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            # swapon
            $cmd = "swapon $real_dev || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            print MASTER_SCRIPT "\n";

        # msdos or vfat
        } elsif (( $xml_config->{fsinfo}->{$line}->{fs} eq "vfat" ) or ( $xml_config->{fsinfo}->{$line}->{fs} eq "msdos" )){

            # create fs
            $cmd = "mkdosfs $mkfs_opts -v $real_dev || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            # mkdir
            $cmd = "mkdir -p /a$mp || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            # mount
            $cmd = "mount $real_dev /a$mp -t $fs -o $options || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";
            
            print MASTER_SCRIPT "\n";


        # ext2
        } elsif ( $xml_config->{fsinfo}->{$line}->{fs} eq "ext2" ) {

            # create fs
            $cmd = "mke2fs $real_dev || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            if ($mount_dev) {
                # add LABEL if necessary
                if ($mount_dev =~ /LABEL=/) {
                    my $label = $mount_dev;
                    $label =~ s/LABEL=//;
                
                    $cmd = "tune2fs -L $label $real_dev";
                    print MASTER_SCRIPT qq(echo "$cmd"\n);
                    print MASTER_SCRIPT "$cmd\n";
                }
                
                # add UUID if necessary
                if ($mount_dev =~ /UUID=/) {
                    my $uuid = $mount_dev;
                    $uuid =~ s/UUID=//;
                
                    $cmd = "tune2fs -U $uuid $real_dev";
                    print MASTER_SCRIPT qq(echo "$cmd"\n);
                    print MASTER_SCRIPT "$cmd\n";
                }
            }

            # mkdir
            $cmd = "mkdir -p /a$mp || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            # mount
            $cmd = "mount $real_dev /a$mp -t $fs -o $options || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";
            
            print MASTER_SCRIPT "\n";


        # ext3
        } elsif ( $xml_config->{fsinfo}->{$line}->{fs} eq "ext3" ) {

            # create fs
            $cmd = "mke2fs -j $real_dev || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            if ($mount_dev) {
                # add LABEL if necessary
                if ($mount_dev =~ /LABEL=/) {
                    my $label = $mount_dev;
                    $label =~ s/LABEL=//;
                
                    $cmd = "tune2fs -L $label $real_dev";
                    print MASTER_SCRIPT qq(echo "$cmd"\n);
                    print MASTER_SCRIPT "$cmd\n";
                }
                
                # add UUID if necessary
                if ($mount_dev =~ /UUID=/) {
                    my $uuid = $mount_dev;
                    $uuid =~ s/UUID=//;
                
                    $cmd = "tune2fs -U $uuid $real_dev";
                    print MASTER_SCRIPT qq(echo "$cmd"\n);
                    print MASTER_SCRIPT "$cmd\n";
                }
            }

            # mkdir
            $cmd = "mkdir -p /a$mp || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            # mount
            $cmd = "mount $real_dev /a$mp -t $fs -o $options || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";
            
            print MASTER_SCRIPT "\n";


        # reiserfs
        } elsif ( $xml_config->{fsinfo}->{$line}->{fs} eq "reiserfs" ) {

            # create fs
            $cmd = "echo y | mkreiserfs $real_dev || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            # mkdir
            $cmd = "mkdir -p /a$mp || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            # mount
            $cmd = "mount $real_dev /a$mp -t $fs -o $options || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";
            
            print MASTER_SCRIPT "\n";

        # jfs
        } elsif ( $xml_config->{fsinfo}->{$line}->{fs} eq "jfs" ) {

            # create fs
            $cmd = "mkfs.jfs -q $real_dev || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            # mkdir
            $cmd = "mkdir -p /a$mp || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            # mount
            $cmd = "mount $real_dev /a$mp -t $fs -o $options || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";
            
            print MASTER_SCRIPT "\n";
	    
        # xfs
        } elsif ( $xml_config->{fsinfo}->{$line}->{fs} eq "xfs" ) {

            # create fs
            $cmd = "mkfs.xfs -f -q $real_dev || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            # mkdir
            $cmd = "mkdir -p /a$mp || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";

            # mount
            $cmd = "mount $real_dev /a$mp -t $fs -o $options || shellout";
            print MASTER_SCRIPT qq(echo "$cmd"\n);
            print MASTER_SCRIPT "$cmd\n";
            
            print MASTER_SCRIPT "\n";

        }

    }
    
    print MASTER_SCRIPT "### END swap and filesystem creation commands ###\n";
    print MASTER_SCRIPT "\n";
    print MASTER_SCRIPT "\n";
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

    my ($image_dir, $file) = @_;

    my $xml_config = XMLin($file, keyattr => { fsinfo => "+line" }, forcearray => 1 );

    print MASTER_SCRIPT qq(\n);
    print MASTER_SCRIPT qq(\n);
    print MASTER_SCRIPT qq(### BEGIN generate new fstab file from autoinstallscript.conf ###\n);
    print MASTER_SCRIPT qq(cat <<'EOF' > /a/etc/fstab\n);

    foreach my $line (sort numerically (keys ( %{$xml_config->{fsinfo}} ))) {
        my $comment   = $xml_config->{fsinfo}->{$line}->{comment};
        my $mount_dev = $xml_config->{fsinfo}->{$line}->{mount_dev};
        unless ($mount_dev) 
            { $mount_dev = $xml_config->{fsinfo}->{$line}->{real_dev}; }
        my $mp        = $xml_config->{fsinfo}->{$line}->{mp};
        my $options   = $xml_config->{fsinfo}->{$line}->{options};
        my $fs        = $xml_config->{fsinfo}->{$line}->{fs};
        my $dump      = $xml_config->{fsinfo}->{$line}->{dump};
        my $pass      = $xml_config->{fsinfo}->{$line}->{pass};

        if ($comment) {
            print MASTER_SCRIPT qq($comment\n);

        } else {
            print MASTER_SCRIPT qq($mount_dev\t$mp\t$fs);
            if ($options)
                { print MASTER_SCRIPT qq(\t$options); }

            if (defined $dump) { 
                print MASTER_SCRIPT qq(\t$dump);

                # 
                # If dump don't exist, we certainly don't want to print pass
                # (it would be treated as if it were dump due to it's 
                # position), therefore we only print pass if dump is also 
                # defined.
                #
                if (defined $pass)  
                    { print MASTER_SCRIPT qq(\t$pass); }
            }

            print MASTER_SCRIPT qq(\n);
        }
    }
    print MASTER_SCRIPT qq(EOF\n);
    print MASTER_SCRIPT qq(### END generate new fstab file from autoinstallscript.conf ###\n);
    print MASTER_SCRIPT qq(\n);
    print MASTER_SCRIPT qq(\n);
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

    my ($image_dir, $file) = @_;

    my $xml_config = XMLin($file, keyattr => { fsinfo => "+line" }, forcearray => 1 );

    print MASTER_SCRIPT "### BEGIN Unmount filesystems ###\n";

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
                   or ($fs eq "reiserfs")
                   or ($fs eq "msdos")
                   or ($fs eq "vfat")
                   or ($fs eq "jfs")
                   or ($fs eq "xfs")
                   or ($fs eq "proc")
            ) { next; }

            # 
            # Create the hash. -BEF-
            #
            $fs_by_mp{$mp} = $fs;

        }
    }

    # Add this so that /proc gets umounted -- even if there is no proc entry in
    # the <fsinfo> section of the autoinstallscript.conf file.
    #
    $fs_by_mp{'/proc'} = "proc";

    # Cycle through the mount points in reverse and umount those filesystems.
    # -BEF-
    #
    foreach my $mp (reverse sort (keys ( %fs_by_mp ))) {
       
        my $fs = $fs_by_mp{$mp};

        # umount
        my $cmd = "umount /a$mp || shellout";
        print MASTER_SCRIPT qq(echo "$cmd"\n);
        print MASTER_SCRIPT "$cmd\n";
        print MASTER_SCRIPT "\n";

    }

    print MASTER_SCRIPT "### END Unmount filesystems ###\n";
    print MASTER_SCRIPT "\n";
    print MASTER_SCRIPT "\n";
}


sub create_autoinstall_script{

    my (  
        $module, 
        $script_name, 
        $auto_install_script_dir, 
        $config_dir, 
        $image, 
        $image_dir, 
        $ip_assignment_method, 
        $post_install,
        $no_listing,
        $auto_install_script_conf,
        $ssh_user
    ) = @_;

    my $rsync_opts = "-a";
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
    open (MASTER_SCRIPT, ">$file") || die "Can't open $file for writing\n";
    
    _in_script_add_standard_header_stuff($image, $script_name);
    
    _read_partition_info_and_prepare_parted_commands( $image_dir, $auto_install_script_conf );
    
    _write_out_mkfs_commands( $image_dir, $auto_install_script_conf );
    
    _mount_proc_in_image_on_client();

    if ($no_listing) {

        # Display a spinner instead of the standard file listing.  A dannf feature. -BEF-
        print MASTER_SCRIPT q(echo -n "Quietly installing image...|")   . "\n";
        print MASTER_SCRIPT q({ while :; do)                            . "\n";
        print MASTER_SCRIPT q(echo -ne "\b/";  sleep 1;)                . "\n";
        print MASTER_SCRIPT q(echo -ne "\b-";  sleep 1;)                . "\n";
        print MASTER_SCRIPT q(echo -ne "\b\\\"; sleep 1;)               . "\n";
        print MASTER_SCRIPT q(echo -ne "\b|";  sleep 1;)                . "\n";
        print MASTER_SCRIPT q(done)                                     . "\n";
        print MASTER_SCRIPT q(}&)                                       . "\n";
        print MASTER_SCRIPT q(pid=$!)                                   . "\n";

    } else {
        
        # Display the standard file listing. -BEF-
        $rsync_opts .= "v";
    }

    $rsync_opts .= " --exclude=lost+found/ --numeric-ids";

    ### BEGIN pull the image down ###
    print MASTER_SCRIPT qq(# Filler up!\n);
    print MASTER_SCRIPT qq(if [ ! -z \$MCAST_GROUP ]; then \n);
    print MASTER_SCRIPT qq(# Use multicast \n);
    print MASTER_SCRIPT qq(    mcast_group+2 \n);
    print MASTER_SCRIPT qq(    echo "udp-receiver --portbase \${MCAST_GROUP} -- | tar -xv -C /a" \n);
    print MASTER_SCRIPT qq(    udp-receiver --portbase \${MCAST_GROUP} | tar -xv -C /a || shellout \n);
    print MASTER_SCRIPT qq( \n);
    print MASTER_SCRIPT qq(else \n);
    print MASTER_SCRIPT qq(    # Use rsync \n);
    print MASTER_SCRIPT qq(    echo "rsync $rsync_opts \${IMAGESERVER}::\${IMAGENAME}/ /a/" \n);
    print MASTER_SCRIPT qq(    rsync $rsync_opts \${IMAGESERVER}::\${IMAGENAME}/ /a/ || shellout \n);
    print MASTER_SCRIPT qq( \n);
    print MASTER_SCRIPT qq(fi \n);
    ### END pull the image down ###

    if ($no_listing) {
        print MASTER_SCRIPT '(kill $pid && shellout)'   . "\n";
        print MASTER_SCRIPT 'kill $pid'                 . "\n";
        print MASTER_SCRIPT 'echo "done."'              . "\n";
    }   

    ### BEGIN graffiti ###
    print MASTER_SCRIPT "# Leave notice of which image is installed on the client\n";
    print MASTER_SCRIPT "echo \$IMAGENAME > /a/etc/systemimager/IMAGE_LAST_SYNCED_TO || shellout\n";
    ### END graffiti ###
    
    _write_out_new_fstab_file( $image_dir, $auto_install_script_conf );
    
    ### BEGIN overrides stuff ###
    # Create default overrides directory. -BEF-
    #
    my $dir = "/var/lib/systemimager/overrides/$script_name";
    if (! -d "$dir")  {
      mkdir("$dir", 0755) or die "FATAL: Can't make directory $dir\n";
    }  
    
    ### BEGIN overrides ###
    print MASTER_SCRIPT  q(### BEGIN overrides ###) . qq(\n);
    print MASTER_SCRIPT  q(if [ ! -z $MCAST_GROUP ]; then) . qq(\n);
    print MASTER_SCRIPT  q(    # Use multicast) . qq(\n);
    print MASTER_SCRIPT  q(    #) . qq(\n);
    print MASTER_SCRIPT  q(    # A single cast will catch any and all override directories at once.) . qq(\n);
    print MASTER_SCRIPT  q(    #) . qq(\n);
    print MASTER_SCRIPT  q(    mcast_group+2) . qq(\n);
    print MASTER_SCRIPT  q(    echo "udp-receiver --portbase ${MCAST_GROUP} -- | tar -xv -C /a") . qq(\n);
    print MASTER_SCRIPT  q(    echo udp-receiver --portbase ${MCAST_GROUP} | tar -xv -C /a || shellout) . qq(\n);
    print MASTER_SCRIPT  q(    ) . qq(\n);
    print MASTER_SCRIPT  q(else) . qq(\n);
    print MASTER_SCRIPT  q(    # Use rsync) . qq(\n);
    print MASTER_SCRIPT  q(    for OVERRIDE in $OVERRIDES) . qq(\n);
    print MASTER_SCRIPT  q(    do) . qq(\n);
    print MASTER_SCRIPT  q(        echo "rsync -av --numeric-ids $IMAGESERVER::overrides/$OVERRIDE/ /a/") . qq(\n);
    print MASTER_SCRIPT  q(        rsync -av --numeric-ids $IMAGESERVER::overrides/$OVERRIDE/ /a/ || echo "Override directory $OVERRIDE doesn't seem to exist, but that may be OK.") . qq(\n);
    print MASTER_SCRIPT  q(    done) . qq(\n);
    print MASTER_SCRIPT  q(fi) . qq(\n);
    print MASTER_SCRIPT  q(### END overrides ###) . qq(\n);
    ### END overrides ###
    
    print MASTER_SCRIPT   qq(\n\n);

    print MASTER_SCRIPT qq(##################################################################\n);
    print MASTER_SCRIPT qq(#\n);
    print MASTER_SCRIPT qq(# Uncomment the line below to leave your hostname blank.\n);
    print MASTER_SCRIPT qq(# Certain distributions use this as an indication to take on the\n);
    print MASTER_SCRIPT qq(# hostname provided by a DHCP server.  The default is to have\n);
    print MASTER_SCRIPT qq(# SystemConfigurator assign your clients the hostname that\n);
    print MASTER_SCRIPT qq(# corresponds to the IP address the use during the install.\n);
    print MASTER_SCRIPT qq(# (If you used to use static_dhcp, is your man.)\n);
    print MASTER_SCRIPT qq(#\n);
    print MASTER_SCRIPT qq(#HOSTNAME=""\n);

    print MASTER_SCRIPT   qq(\n\n);

    ### BEGIN System Configurator setup ###
    print MASTER_SCRIPT "### BEGIN systemconfigurator ###\n";
    # System Configurator for static IP
    if ($ip_assignment_method eq "static") { 
        print MASTER_SCRIPT <<'EOF';
# Configure the client's hardware, network interface, and boot loader.
chroot /a/ systemconfigurator --configsi --excludesto=/etc/systemimager/systemconfig.local.exclude --stdin <<EOL || shellout

[NETWORK]
HOSTNAME = $HOSTNAME
DOMAINNAME = $DOMAINNAME
GATEWAY = $GATEWAY

[INTERFACE0]
DEVICE = eth0
TYPE = static
IPADDR = $IPADDR
NETMASK = $NETMASK
EOL
EOF

    } elsif ($ip_assignment_method eq "replicant") {
        print MASTER_SCRIPT << 'EOF';
# Configure the client's boot loader.
chroot /a/ systemconfigurator --runboot || shellout
EOF

    } else { # aka elsif ($ip_assignment_method eq "dhcp")
        print MASTER_SCRIPT <<'EOF';
# Configure the client's hardware, network interface, and boot loader.
chroot /a/ systemconfigurator --configsi --stdin <<EOL || shellout

[NETWORK]
HOSTNAME = $HOSTNAME
DOMAINNAME = $DOMAINNAME

[INTERFACE0]
DEVICE = eth0
TYPE = dhcp
EOL
EOF

    }  ### END System Configurator setup ###
    print MASTER_SCRIPT "### END systemconfigurator ###\n";

    print MASTER_SCRIPT qq(\n\n);

    _write_out_umount_commands( $image_dir, $auto_install_script_conf );

    print MASTER_SCRIPT  qq(# Tell the image server we're done.\n);
    print MASTER_SCRIPT  qq(rsync \$IMAGESERVER::scripts/imaging_complete > /dev/null 2>&1\n);

    print MASTER_SCRIPT "\n";

    print MASTER_SCRIPT "# Take network interface down\n";
    print MASTER_SCRIPT "ifconfig eth0 down || shellout\n";
    print MASTER_SCRIPT "\n";
    
    if ($post_install eq "beep") {
        print MASTER_SCRIPT << 'EOF';
# Cause the system to make noise and display an "I'm done." message
ralph="sick"
count="1"
while [ $ralph="sick" ]
do
    echo -n -e "\\a"
    [ $count -lt 60 ] && echo "I've been done for $count seconds.  Reboot me already!"
    [ $(($count / 60 * 60)) = $count ] && echo "I've been done for $(($count / 60)) minutes now.  Reboot me already!"
    sleep 1
    count=$(($count + 1))
done


EOF


    } elsif ($post_install eq "reboot") {
        #reboot stuff
        print MASTER_SCRIPT "# reboot the autoinstall client\n";
        print MASTER_SCRIPT "shutdown -r now\n";
        print MASTER_SCRIPT "\n";
    } elsif ($post_install eq "shutdown") {
       #shutdown stuff
       print MASTER_SCRIPT "# shutdown the autoinstall client\n";
       print MASTER_SCRIPT "shutdown -h now\n";
       print MASTER_SCRIPT "\n";
    }
    ### END end of autoinstall options ###

    close(MASTER_SCRIPT);
} # sub create_autoinstall_script 



# Usage:
# my $ip_hex = ip_quad_2_ip_hex($ip_address);
sub ip_quad_2_ip_hex {

    my ($ip_address) = $_[1];

    my ($a, $b, $c, $d) = split(/\./, $ip_address);

    # Figure out the hex equivalent of the IP address
    my $ip_hex = sprintf("%02X%02X%02X%02X", $a, $b, $c, $d);

    return $ip_hex;
}



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
    my $cmd = "umount $mnt_dir";
    unless( copy($kernel, "$mnt_dir/kernel") ) {
        system($cmd);
        print "Couldn't copy $kernel to $mnt_dir!\n";
        exit 1;
    }

    unless( copy($initrd, "$mnt_dir/initrd.img") ) {
        system($cmd);
        print "Couldn't copy $initrd to $mnt_dir!\n";
        exit 1;
    }

    unless( copy($message_txt, "$mnt_dir/message.txt") ) {
        system($cmd);
        print "Couldn't copy $message_txt to $mnt_dir!\n";
        exit 1;
    }

    if($local_cfg) {
        unless( copy($local_cfg, "$mnt_dir/local.cfg") ) {
            system($cmd);
            print "Couldn't copy $local_cfg to $mnt_dir!\n";
            exit 1;
        }
    }

    if($ssh_key) {
        unless( copy($ssh_key, $mnt_dir) ) {
            system($cmd);
            print "Couldn't copy $ssh_key to $mnt_dir!\n";
            exit 1;
        }
    }

    # Unless an append string was given on the command line, just copy over.
    unless ($append_string) {
        unless( copy("$syslinux_cfg","$mnt_dir/syslinux.cfg") ) {
            system($cmd);
            print "Couldn't copy $syslinux_cfg to $mnt_dir!\n";
            exit 1;
        }
    } else {
        # Append to APPEND line in config file.
        my $infile = "$syslinux_cfg";
        my $outfile = "$mnt_dir/syslinux.cfg";
        open(INFILE,"<$infile") or croak("Couldn't open $infile for reading.");
            open(OUTFILE,">$outfile") or croak("Couldn't open $outfile for writing.");
                while (<INFILE>) {
                    if (/APPEND/) { 
                        chomp;
                        $_ = $_ . " $append_string\n";
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
            exit 1;
        }

        _write_elilo_conf("$mnt_dir/elilo.conf", $append_string);

    }
    #
    ############################################################################
    
    return 1;

}



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
        print ELILO_CONF "append=$append_string\n";
      }

      print ELILO_CONF "image=kernel\n";
      print ELILO_CONF "  label=linux\n";
      print ELILO_CONF "  read-only\n";
      print ELILO_CONF "  initrd=initrd.img\n";
      print ELILO_CONF "  root=/dev/ram\n";

    close(ELILO_CONF);
    return 1;
}


