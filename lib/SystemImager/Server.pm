#
# "SystemImager" - Copyright (C) 1999-2001 Brian Elliott Finley <brian@systemimager.org>
#
#   $Id$
#

package SystemImager::Server;

$version_number="1.5.0";
$VERSION = $version_number;

sub add2rsyncd {
    my ($class, $rsyncconf, $imagename, $imagedir) = @_;
    
    if(!_imageexists($rsyncconf, $imagename)) {
        open(OUT,">>$rsyncconf") or return undef;
        print OUT "[$imagename]\n\tpath=$imagedir\n\n";
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
    or ($ip_assignment_method eq "static_dhcp")
    or ($ip_assignment_method eq "dynamic_dhcp")
    or ($ip_assignment_method eq "static")
    or ($ip_assignment_method eq "replicant")
  ) { die qq(\nERROR: -ip-assignment must be static, static_dhcp, dynamic_dhcp, or replicant.\n\n       Try "-help" for more options.\n); }
  return 0;
}

sub get_full_path_to_image_from_rsyncd_conf {
        my $rsyncd_conf=$_[1];
	my $image=$_[2];

        my $path_to_image="";
	open (FILE, "<$rsyncd_conf") or die "FATAL: Couldn't open $rsyncd_conf for reading!\n";
	  while (<FILE>) {
	    if (/^\s*path\s*=.*$image/) { 
	      (my $junk, $path_to_image) = split (/=/);
	      $path_to_image =~ s/^\s+//;
	      $path_to_image =~ s/\s+$//;
	      $path_to_image =~ s/$image//;
	    }
	  }
	close FILE;
	return $path_to_image;
}

sub _gather_up_partition_info_for_each_disk_and_prepare_an_sfdisk_command {
    my $imagedir = $_[0];
    my $config_dir = $_[1];
    my $disk = $_[2];

    foreach $disk (@disks)  {

        _get_partition_information( $imagedir, $config_dir, $disk ); 

        _format_output_for_partitions_one_to_four( $disk );

        _format_output_for_logical_partitions_five_plus( $disk );

        # put final touch on sfdisk command
        $sfdisk_command = "sfdisk -L -uM /dev/$disk <<EOF || shellout\n" . $sfdisk_command . "EOF\n";

        # output disk partition section
        print MASTER_SCRIPT "# partition $disk\n";
        print MASTER_SCRIPT "echo partitioning $disk...\n";
        print MASTER_SCRIPT "sleep 1s\n";
        print MASTER_SCRIPT $sfdisk_command;
        print MASTER_SCRIPT "\n";

    }
}

sub _in_script_add_standard_header_stuff {
  my $image = $_[0];
  print MASTER_SCRIPT << 'EOF';
#!/bin/sh

#
# "SystemImager" - Copyright (C) 1999-2001 Brian Elliott Finley <brian@systemimager.org>
#
#
EOF

  print MASTER_SCRIPT "# This master autoinstall script was created with SystemImager v$version_number\n";
  print MASTER_SCRIPT "\n";
  print MASTER_SCRIPT "VERSION=$version_number\n";
  print MASTER_SCRIPT "IMAGENAME=$image\n";

  print MASTER_SCRIPT << 'EOF';
PATH=/sbin:/bin:/usr/bin:/usr/sbin:/tmp
ARCH=`uname -m \
| sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/`

shellout() {
  exec cat /etc/issue ; exit 1
}

### BEGIN Check to be sure this not run from a working machine ###
# test for mounted SCSI or IDE disks
mount | grep [hs]d[a-z][1-9] > /dev/null 2>&1
[ $? -eq 0 ] &&  echo Sorry.  Must not run on a working machine... && shellout

# test for mounted software RAID devices
mount | grep md[0-9] > /dev/null 2>&1
[ $? -eq 0 ] &&  echo Sorry.  Must not run on a working machine... && shellout

# test for mounted hardware RAID disks
mount | grep c[0-9]+d[0-9]+p > /dev/null 2>&1
[ $? -eq 0 ] &&  echo Sorry.  Must not run on a working machine... && shellout
### END Check to be sure this not run from a working machine ###

# Pull in variables left behind by the linuxrc script.
# This information is passed from the linuxrc script on the autoinstall media via /tmp/variables.txt
# Apparently the shell on the autoinstall media is not intelligent enough to take a "set -a" parameter
. /tmp/variables.txt || shellout

### BEGIN Stop RAID devices before partitioning begins ###
# Why did they get started in the first place?  So we can pull a local.cfg
# file off a root mounted RAID system.  We do this even if a system does not
# use RAID, in case you are using a disk that was previously part of a RAID
# array.

# find running raid devices
RAID_DEVICES=`cat /proc/mdstat | grep ^md | mawk '{print "/dev/" $1}'`

# get raidstop utility if any raid devices exist
if [ ! -z "${RAID_DEVICES}" ]
then
  rsync -av --numeric-ids $IMAGESERVER::${ARCH}-boot/raidstop /tmp/ || shellout
fi

# raidstop will not run unless a raidtab file exists
touch /etc/raidtab || shellout

# turn dem pesky raid devices off!
for RAID_DEVICE in ${RAID_DEVICES}
do
  # we don't do a shellout here because, well I forgot why, but we don't.
  echo "raidstop ${RAID_DEVICE}" && raidstop ${RAID_DEVICE}
done
### END Stop RAID devices before partitioning begins ###

EOF
}

sub _are_we_using_megabytes_or_sectors {
    # are we using megabytes or sectors (prepareclient -explicit-geometry)
    if ( grep(/^Units = megabytes/, @partitions)) {
      for (@partitions) {
        if(/^\/dev/) {
          # get rid of newline
          chomp;

          # get rid of an asterisk that may be indicating a boot partition (Linux doesn't need this)
          $_ =~ s/\*//g;

          # get rid of + signs -- we're not going to worry about those...
          $_ =~ s/\+//g;

          # split on space(s) and assign values to variables
          (my $device, my $start, my $end, my $megabytes, my $blocks, my $id) = split(/ +/);

          # round down if there is a minus sign on the value
          if ($megabytes =~ /-/) {
            $megabytes =~ s/-//g;
            $megabytes--;
          }

          # figure out what the starting device is (probably partition 1)
          if (($megabytes != "0") and ($start < $lowest_partition_start_point)) { 
            $lowest_partition_start_point = $start; 
            $start_device = $device; 
          }

          # create the megabytes by device hash
          $megabytes_by_device{$device} = $megabytes;

          # create the Id by device hash
          $id_by_device{$device} = $id;
        }
      }

      # get number of partitions
      $number_of_partitions = (keys %id_by_device);

    } elsif ( grep(/^Units = sectors/, @partitions)) {

      ### BEGIN do stuff for disks partitioned in sectors (prepareclient -explicit-geometry)

        ### BEGIN partitioning output ###
        $sfdisk_command_part_one = "sfdisk -L -uS /dev/$disk <<EOF\n";
        $sfdisk_command_part_two = "";
  
        # gather up partition information
        open (PARTITIONS, "<$imagedir$config_dir/partitionschemes/${disk}")
        || die "Cannot open $imagedir$config_dir/partitionschemes/$disk for reading\n";
          @partitions = <PARTITIONS>;
        close(PARTITIONS);

        for (@partitions) {
          if(/^\/dev/) {
            # get rid of newline
            chomp;

            # get rid of an asterisk that may be indicating a boot partition (Linux doesn't need this)
            $_ =~ s/\*//g;

            # split on space(s) and assign values to variables
            (my $dev, my $start, my $end, my $sectors, my $id) = split(/ +/);

            # continue compiling sfdisk command
            $sfdisk_command_part_one = $sfdisk_command_part_one . "$dev : start= $start, size= $sectors, Id=$id\n";
          }
        }
        $sfdisk_command = $sfdisk_command_part_one . $sfdisk_command_part_two . "EOF\n";
        ### END partitioning output ###

        # output disk partition section
        print MASTER_SCRIPT "# partition $disk\n";
        print MASTER_SCRIPT "echo partitioning $disk...\n";
        print MASTER_SCRIPT "sleep 1s\n";
        print MASTER_SCRIPT $sfdisk_command;
        print MASTER_SCRIPT "\n";

      ### END do stuff for disks partitioned in sectors (prepareclient -explicit-geometry)
    }
}

sub _get_partition_information {
    my $imagedir = $_[0];
    my $config_dir = $_[1];
    my $disk = $_[2];

    %id_by_device = ();
    %megabytes_by_device = ();
    $lowest_partition_start_point = "10000000";  # some random large number

    open (PARTITIONS, "<$imagedir$config_dir/partitionschemes/$disk")
    || die "Cannot open $imagedir$config_dir/partitionschemes/$disk for reading\n";
      @partitions = <PARTITIONS>;
    close(PARTITIONS);

    _are_we_using_megabytes_or_sectors();
}

sub _format_output_for_logical_partitions_five_plus {
      my $disk = $_[0];

      my $partition_number = "5";
      if ($number_of_partitions > "4") {
        until ($partition_number == $number_of_partitions) {
          my $device = "/dev/$disk$partition_number";
          my $megabytes = $megabytes_by_device{$device};
          my $id = $id_by_device{$device};
          $sfdisk_command = $sfdisk_command . "$device : start= , size= $megabytes, Id=$id\n";
          $partition_number++;
        } 

        my $device = "";
        if ($disk =~ /c[0-9]+d[0-9]+/ )
          { $device = "/dev/$disk" . "p" . "$partition_number"; }
        else
          { $device = "/dev/$disk" . "$partition_number"; }

        my $id = $id_by_device{$device};
        $sfdisk_command = $sfdisk_command . "$device : start= , size= , Id=$id\n";
      }
}

sub _format_output_for_partitions_one_to_four {
      my $disk = $_[0];

      # format output for partitions 1-4 (must do these backwards)
      $sfdisk_command = "";
      my $has_a_non_null_partition_been_created = "no";
      foreach my $partition_number (4, 3, 2, 1) {

        my $device = "";
        if ( $disk =~ /c[0-9]+d[0-9]+/ )
        {
            $device = "/dev/$disk" . "p" . "$partition_number";
        }
        else
        {
            $device = "/dev/$disk" . "$partition_number";
        }

        my $megabytes = $megabytes_by_device{$device};
        my $id = $id_by_device{$device};
        if ($megabytes == "0") {
          $sfdisk_command = "$device : start= 0, size= 0, Id=0\n" . $sfdisk_command;
          next;
        } 
        if ($has_a_non_null_partition_been_created eq "no") { $megabytes = ""; }
        if ($device eq $start_device) {
          $sfdisk_command = "$device : start= $lowest_partition_start_point, size= $megabytes, Id=$id\n" . $sfdisk_command;
          $has_a_non_null_partition_been_created = "yes";
        } else {
          $sfdisk_command = "$device : start= , size= $megabytes, Id=$id\n" . $sfdisk_command;
          $has_a_non_null_partition_been_created = "yes";
        }
      }
}

sub _in_script_give_a_custom_partitioning_example {
  print MASTER_SCRIPT << 'EOF';
# Partition the disk (see the sfdisk man page for customization details)
#
# Below is an example of how to customize a disk.  This can be useful if your clients
# have disks of differing sizes or geometries.  Here is a description of the sfdisk
# command presented in the example below:
#
# line 1 -- the sfdisk command and arguments (-uM means "units are MB)
# line 2 -- this is a comment
# line 3 -- start at the beginning of the disk 0, give 22M /dev/sda1 (/boot)
# line 4 -- start where the last partition left off, and add 512M /dev/sda2 for swap, partition type 82
# line 5 -- start where the last partition left off, and add 6000M /dev/sda3 (/)
# line 6 -- start where the last partition left off, and give the remaining space to /dev/sda4 (/var)
# line 7 -- the EOF statement indicating to sfdisk that we are finished giving it commands
#
# <<<< BEGIN EXAMPLE >>>>
#sfdisk -uM /dev/sda <<EOF
## partition    start_of_partition      size_in_megabytes       partition_type
#  /dev/sda1 :  start= 0,          	size= 22,               Id=83
#  /dev/sda2 :  start= ,                size= 512,              Id=82
#  /dev/sda3 :  start= ,                size= 6000,             Id=83
#  /dev/sda4 :  start= ,                size= ,                 Id=83
#EOF
# <<<< END EXAMPLE >>>>

EOF
}

sub _create_arrays_of_device_files_by_device_type {
    my $device = $_[0];
    my $mount_point = $_[1];
    my $filesystem_type = $_[2];

    # get software RAID devices that are not using LABEL= or UUID=
    if ($device =~ /\/dev\/md/) { push (@software_raid_devices, $device); }

    # swap
    if ($filesystem_type eq "swap") { push (@swap_devices, $device); }

    # ext2
    if ($filesystem_type eq "ext2") { 
      push (@ext2_devices, $device);
      push (@mount_points, $mount_point);
    }

    # ext3
    if ($filesystem_type eq "ext3") { 
      push (@ext3_devices, $device);
      push (@mount_points, $mount_point);
    }

    # reiserfs
    if ($filesystem_type eq "reiserfs") { 
      push (@reiserfs_devices, $device);
      push (@mount_points, $mount_point);
    }
}

sub _in_script_stop_RAID_devices_before_partitioning {
  if (@software_raid_devices) {
    print MASTER_SCRIPT "# Pull /etc/raidtab over to autoinstall client\n";
    print MASTER_SCRIPT "rsync -av --numeric-ids \$IMAGESERVER::\$IMAGENAME/etc/raidtab /etc/raidtab || shellout\n";
    print MASTER_SCRIPT "\n";
    print MASTER_SCRIPT "# get software RAID utilities\n";
    print MASTER_SCRIPT "rsync -av --numeric-ids \$IMAGESERVER::${ARCH}-boot/mkraid /tmp/ || shellout\n";
    print MASTER_SCRIPT "rsync -av --numeric-ids \$IMAGESERVER::${ARCH}-boot/raidstart /tmp/ || shellout\n";
    print MASTER_SCRIPT "rsync -av --numeric-ids \$IMAGESERVER::${ARCH}-boot/raidstop /tmp/ || shellout\n";
    print MASTER_SCRIPT "\n";

    print MASTER_SCRIPT << 'EOF';
# Stop RAID devices before partitioning begins
# Why did they get started in the first place?  So we can pull a local.cfg
# file off a root mounted RAID system.
RAID_DEVICES=`cat /proc/mdstat | grep ^md | mawk '{print "/dev/" $1}'`
for RAID_DEVICE in ${RAID_DEVICES}
do
  echo "raidstop ${RAID_DEVICE}" && raidstop ${RAID_DEVICE}
done

EOF

  }
}


sub _add_proc_to_list_of_filesystems_to_mount_on_autoinstall_client {
  #  The following allows a proc filesystem to be mounted in the fakeroot.
  #  This provides /proc to programs which are called by SystemImager
  #  (eg. System Configurator).

  push (@mount_points, '/proc');
  $device_by_mount_point{'/proc'} = 'proc';
  $filesystem_type_by_mount_point{'proc'} = 'proc';
}

sub _get_list_of_IDE_and_SCSI_devices {
  my $imagedir = $_[0];
  my $config_dir = $_[1];

  $partition_dir="$config_dir/partitionschemes";
  if(-d "$imagedir$partition_dir") {
    opendir(PARTITIONSCHEMES, "$imagedir$partition_dir") || die "$program_name: Can't read the $imagedir$partition_dir directory";
        # Skip anything that begins with a "." or an "rd"
        push(@disks, grep( !/^rd$/, grep( !/^\..*/, readdir(PARTITIONSCHEMES) ) ) );
    close(PARTITIONSCHEMES);
  }
}


sub _get_list_of_hardware_RAID_devices {
  my $imagedir = $_[0];
  my $config_dir = $_[1];

  $partition_dir="$config_dir/partitionschemes/rd";
  if(-d "$imagedir$partition_dir") {
    opendir(PARTITIONSCHEMES, "$imagedir$partition_dir") || die "$program_name: Can't read the $imagedir$partition_dir directory";
        # Skip anything that begins with a "."
        push(my @hardware_raid_disks, grep( !/^\..*/, readdir(PARTITIONSCHEMES) ) );

        # add the rd/ bit to each device
        for (@hardware_raid_disks) {
          $_ =~ s/^/rd\//;
          push(@disks, $_);
        }
    close(PARTITIONSCHEMES);
  }
}

sub _compile_hash_of_ext2_partitions_to_label {
  my $imagedir = $_[0];

  %devices_by_label = ();
  $file="$imagedir/etc/systemimager/devices_by_label.txt";
  if (-e $file) {
    open (LABELS, "<$file") || die "program_name: Failed to open $file for reading\n";
    while (<LABELS>) {
      # remove carriage returns
      chomp;

      # Skip the line if it starts with a '#'
      if (m@(^\s*\#)@) { next; }

      # turn all tabs into single spaces -- Note: <ctrl-v><tab>
      s/	/ /g;

      # Remove spaces from the beginning of the line
      s/^ +//;

      # Skip blank lines
      if (m@(^$)@) { next; }

      # split on space(s) and assign values to variables
      (my $label, my $device) = split(/ +/);

      # Create hash to be used in labelling
      $devices_by_label{$label} = $device;

      # get software RAID devices that are using LABEL=
      if ($device =~ /\/dev\/md/) { push (@software_raid_devices, $device); }
    }
    close (LABELS);
  }
}

sub _get_info_on_devices_for_software_RAID_swap_and_filesystems {
  my $imagedir = $_[0];

  %device_by_mount_point          = ();
  %filesystem_type_by_mount_point = ();
  %mount_options_by_mount_point   = ();
  open (FSTAB, "<$imagedir/etc/fstab") || die "Failed to open $imagedir/etc/fstab for reading!\n";
  while (<FSTAB>) {
    # Skip the line if it starts with a '#' or if it is for a floppy device
    if (m@(^\s*\#)|(/dev/fd)@) { next; }

    # turn all tabs into single spaces -- Note: <ctrl-v><tab>
    s/	/ /g;

    # Remove spaces from the beginning of the line
    s/^ +//;

    # Skip blank lines
    if (m@(^$)@) { next; }

    # split on space(s) and assign values to variables
    (my $device, my $mount_point, my $filesystem_type, my $mount_options) = split(/ +/);

    # Create hashes to be used in mounting and unmounting
    $device_by_mount_point{$mount_point}     = $device;
    $filesystem_type_by_mount_point{$mount_point} = $filesystem_type;
    $mount_options_by_mount_point{$mount_point}   = $mount_options;

    _create_arrays_of_device_files_by_device_type( $device, $mount_point, $filesystem_type);
  }
  close FSTAB;
}

sub create_autoinstall_script{
  my $master_script=$_[1];
  my $config_dir=$_[2];
  my $image=$_[3];
  my $imagedir=$_[4];
  my $ip_assignment_method=$_[5];
  my $post_install=$_[6];

  open (MASTER_SCRIPT, ">$master_script") || die "$program_name: Can't open $master_script for writing\n";

  _in_script_add_standard_header_stuff($image);

  _get_list_of_hardware_RAID_devices( $imagedir, $config_dir );

  _get_list_of_IDE_and_SCSI_devices( $imagedir, $config_dir );

  _get_info_on_devices_for_software_RAID_swap_and_filesystems($imagedir);

  _add_proc_to_list_of_filesystems_to_mount_on_autoinstall_client();

  _compile_hash_of_ext2_partitions_to_label( $imagedir ); 

  _in_script_stop_RAID_devices_before_partitioning();

  _in_script_give_a_custom_partitioning_example(); 

  _gather_up_partition_info_for_each_disk_and_prepare_an_sfdisk_command( $imagedir, $config_dir, $disk );


  ### BEGIN Write out software RAID device creation commands ###
  if (@software_raid_devices) {
    print MASTER_SCRIPT "# create software RAID devices\n";
    foreach my $device (sort @software_raid_devices) {
      print MASTER_SCRIPT "mkraid --really-force $device || shellout\n";
    }
    print MASTER_SCRIPT "\n";
  }
  ### END Write out software RAID device creation commands ###


  ### BEGIN Write out swap creation commands ###
  if (@swap_devices) {
    print MASTER_SCRIPT "# initialize swap devices\n";
    foreach my $device (sort @swap_devices) {
      print MASTER_SCRIPT "mkswap -v1 $device || shellout\n";
      print MASTER_SCRIPT "swapon $device || shellout\n";
    }
    print MASTER_SCRIPT "\n";
  }
  ### END Write out swap creation commands ###


  ### BEGIN Write out ext2 creation commands ###
  if (@ext2_devices) {
    print MASTER_SCRIPT "# format ext2 devices\n";
    foreach my $device (sort @ext2_devices) {
      if ($device =~ /LABEL=/) {
        ### BEGIN this do for labelled devices
        foreach my $label (keys %devices_by_label) {
          if ($device eq $label) {
            # get device
            my $device = $devices_by_label{$label};
            # strip out LABEL= bit so that we're left with just the actual label
            $label =~ s/LABEL=//;
            print MASTER_SCRIPT "mke2fs -L $label $device || shellout\n";
          }
        }
        ### END this do for labelled devices
      } else {
        ### BEGIN this do for non-labelled devices
        print MASTER_SCRIPT "mke2fs $device || shellout\n";
        ### END this do for non-labelled devices
      }
    }
    print MASTER_SCRIPT "\n";
  }
  ### END Write out ext2 creation commands ###


### BEGIN Write out ext3 creation commands ###
if (@ext3_devices) {
  print MASTER_SCRIPT "# format ext3 devices\n";
  print MASTER_SCRIPT "#   SystemImager will use the default parameters to create an appropriately\n";
  print MASTER_SCRIPT "#   sized journal (given the size of the filesystem) stored internally in the\n";
  print MASTER_SCRIPT "#   filesystem.\n";
  print MASTER_SCRIPT "#\n";
  print MASTER_SCRIPT "#   In the future, I hope to detect and re-create journals of an appropriate\n";
  print MASTER_SCRIPT "#   size.  Currently we don't deal with non-hidden journals or journals on a\n";
  print MASTER_SCRIPT "#   device other than the filesystem device itself.\n";
  print MASTER_SCRIPT "#\n";
  print MASTER_SCRIPT "#   If you require different journal options, simply make the changes here in\n";
  print MASTER_SCRIPT "#   this <image>.master script.\n";

  foreach my $device (sort @ext3_devices) {
    if ($device =~ /LABEL=/) {
      ### BEGIN this do for labelled devices
      foreach my $label (keys %devices_by_label) {
        if ($device eq $label) {
          # get device
          my $device = $devices_by_label{$label};
          # strip out LABEL= bit so that we're left with just the actual label
          $label =~ s/LABEL=//;
          print MASTER_SCRIPT "mke2fs -j -L $label $device || shellout\n";
        }
      }
      ### END this do for labelled devices
    } else {
      ### BEGIN this do for non-labelled devices
      print MASTER_SCRIPT "mke2fs -j $device || shellout\n";
      ### END this do for non-labelled devices
    }
  }

  print MASTER_SCRIPT "\n";
}
### END Write out ext3 creation commands ###


### BEGIN Write out reiserfs creation commands ###
if (@reiserfs_devices) {
  print MASTER_SCRIPT "# get mkreiserfs utility\n";
  print MASTER_SCRIPT "rsync -av --numeric-ids \$IMAGESERVER::${ARCH}-boot/mkreiserfs /tmp/ || shellout\n";
  print MASTER_SCRIPT "\n";
  print MASTER_SCRIPT "# format reiserfs devices\n";
  foreach my $device (sort @reiserfs_devices) {
    print MASTER_SCRIPT "# rupasov is the default, but we are explicit here anyway\n";
    print MASTER_SCRIPT "echo \"y\" | mkreiserfs -h rupasov $device || shellout\n";
  }
  print MASTER_SCRIPT "\n";
}
### END Write out ext2 creation commands ###


### BEGIN Write out mkdir and mount commands ###
# be sure to pre-pend /a to each target directory being created
print MASTER_SCRIPT "# create mount points and mount filesystems\n";
foreach $mount_point (sort (@mount_points)) {
  my $device = $device_by_mount_point{$mount_point};
  print MASTER_SCRIPT "mkdir -p /a$mount_point || shellout\n";

  ### BEGIN this do for labelled devices
  if ($device =~ /LABEL=/) {
    foreach my $label (keys %devices_by_label) {
      if ($device eq $label) {
        # get device
        $device = $devices_by_label{$label};
        next;
      }
    }
  }
  ### END this do for labelled devices

  # Be sure to use proper mount options -- such as -notail for root mounted
  # reiserfs filesystems.  Thanks go to Matthew Marlowe <mmarlowe@jalan.com>
  # for finding this bug (root mounted reiserfs needing the -notail option).
  my $mount_options   = $mount_options_by_mount_point{$mount_point};

  my $filesystem_type = $filesystem_type_by_mount_point{$mount_point};

  # ext3 filesystems are mounted as ext2 for autoinstall purposes
  if($filesystem_type eq "ext3") { $filesystem_type = "ext2" }

  if ($mount_options) {
    # Deal with filesystems to be mounted read only (ro) after install.  We 
    # still need to write to them to install them. ;)
    $mount_options =~ s/^ro$/rw/;
    $mount_options =~ s/^ro,/rw,/;
    $mount_options =~ s/,ro$/,rw/;
    $mount_options =~ s/,ro,/,rw,/;

    # add commands to master script
    print MASTER_SCRIPT "mount $device /a$mount_point -t $filesystem_type -o $mount_options || shellout\n";
  } else {
    # add commands to master script
    print MASTER_SCRIPT "mount $device /a$mount_point -t $filesystem_type || shellout\n";
  }
  print MASTER_SCRIPT "\n";
}
### END Write out mkdir and mount commands ###


### BEGIN pull the image down ###
print MASTER_SCRIPT << 'EOF';
# Filler up!
#
# If we are installing over ssh, we must limit the bandwidth used by 
# rsync with the --bwlimit option.  This is because of a bug in ssh that
# causes a deadlock.  The only problem with --bwlimit is that it slows 
# down your autoinstall significantly.  We try to guess which one you need:
# o if you ran getimage with -ssh-user, we presume you need --bwlimit
# o if you ran getimage without -ssh-user, we presume you don't need 
#   --bwlimit and would rather have a faster autoinstall.
#
# Both options are here for your convenience.  We have done our best to 
# choose the one you need and have commented out the other.
#
EOF

if ($ssh_user) {
  # using ssh
  print MASTER_SCRIPT "rsync -av --bwlimit=10000 --numeric-ids \$IMAGESERVER::\$IMAGENAME/ /a/ || shellout\n\n";
  print MASTER_SCRIPT "#rsync -av --numeric-ids \$IMAGESERVER::\$IMAGENAME/ /a/ || shellout\n\n";
} else {
  # not using ssh
  print MASTER_SCRIPT "#rsync -av --bwlimit=10000 --numeric-ids \$IMAGESERVER::\$IMAGENAME/ /a/ || shellout\n\n";
  print MASTER_SCRIPT "rsync -av --numeric-ids \$IMAGESERVER::\$IMAGENAME/ /a/ || shellout\n\n";
}
### END pull the image down ###

### BEGIN graffiti ###
print MASTER_SCRIPT "# Leave notice of which image is installed on the client\n";
print MASTER_SCRIPT "echo \$IMAGENAME > /a/etc/systemimager/IMAGE_LAST_SYNCED_TO || shellout\n\n";
### END graffiti ###

### BEGIN System Configurator setup ###

if ($ip_assignment_method eq "static") { 

  print MASTER_SCRIPT <<'EOF';
chroot /a/ systemconfigurator --configsi --stdin <<EOL || shellout

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

} elsif ($ip_assignment_method eq "static_dhcp") {
  print MASTER_SCRIPT <<'EOF';
chroot /a/ systemconfigurator --configsi --stdin <<EOL || shellout

[INTERFACE0]
DEVICE = eth0
TYPE = dhcp

EOL

EOF

} elsif ($ip_assignment_method eq "replicant") {
  print MASTER_SCRIPT << 'EOF';
chroot /a/ systemconfigurator --runboot || shellout

EOF

} else { # aka elsif ($ip_assignment_method eq "dynamic_dhcp")
  print MASTER_SCRIPT <<'EOF';
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

print MASTER_SCRIPT "# unmount the freshly filled filesystems\n";
foreach $mount_point (reverse sort @mount_points) {
    print MASTER_SCRIPT "echo -n umount /a$mount_point/ ... \n";
    print MASTER_SCRIPT "umount /a$mount_point/ && echo Done! || shellout\n";
}
print MASTER_SCRIPT "\n";

print MASTER_SCRIPT "# No need to manually stop software RAID devices -- the autodetect support\n";
print MASTER_SCRIPT "# in the kernel will do that for us.\n";
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
  beep
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
}

