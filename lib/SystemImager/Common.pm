package SystemImager::Common;

#
# "SystemImager"
#
#  Copyright (C) 2001-2002 Bald Guy Software <brian.finley@baldguysoftware.com>
#
#    $Id$
#

use strict;
use vars qw($version_number $VERSION);

$version_number="SYSTEMIMAGER_VERSION_STRING";
$VERSION = $version_number;

sub check_if_root{
	unless($< == 0) { die "Must be run as root!\n"; }
}

sub get_response {
	my $garbage_in=<STDIN>;
	chomp $garbage_in;
	unless($garbage_in) { $garbage_in = $_[1]; }
	my $garbage_out = $garbage_in;
	return $garbage_out;
}

# Usage:
# get_boot_flavors($arch, $where)
#   return the list of available boot flavors for a given arch for a given
#   version of SystemImager.
#   $where is a string that specifies where to look.  if $where contains
#   a "/", then we assume $where is a local directory.  otherwise, we
#   assume $where is a remote machine & we look in the standard place.
sub get_boot_flavors {
    my ($class, $arch, $where) = @_;

    my %allflavors = ();
    $_ = $where;

    # if $where contains a "/", we look in a local directory named $where
    # otherwise, we look on a remote server named $where
    if (m{.*/.*}) {
	my $autoinstall_bootdir = $where;
	opendir BOOTDIR, "$autoinstall_bootdir/$arch" or return undef;
	my @dirlist = readdir BOOTDIR;

	for my $file (@dirlist) {
	    unless (($file eq ".") or ($file eq "..")) {
		$allflavors{$file} = 1;
	    }
	}
	close BOOTDIR;
    }
    else {
	my $server = $where;
	my $cmd = "rsync $server"."::boot/$arch/";
	open(RSYNC, "$cmd |")
	    or do { print "Error running rsync: $!\n"; return undef; };
	while (<RSYNC>) {
	    if (/.*\s(\S+)$/) {
		unless (($1 eq ".") or ($1 eq "..")) {
		    $allflavors{$1} = 1;
		}
	    }
	}
	close RSYNC or return undef;
    }

    return %allflavors;
}

## A pure perl which command
# example: SystemImager::Common->which($file,$ENV{PATH}) || croak "$file not found in your path.";
sub which {
    my ($class, $file, $path) = @_;
    
    foreach my $dir (split(/:/,$path)) {
      if(-x "$dir/$file") {
        return 1;
      }
    }
    return 0;
}

# Usage:
# write_auto_install_script_conf_header($partition_tool, $file);
sub write_auto_install_script_conf_header {

    my ($module, $partition_tool, $file) = @_;

    # Open up the file that we'll be putting our generic partition info in. -BEF-
    open (DISK_FILE, ">$file") or die ("FATAL: Couldn't open $file for writing!"); 
        print DISK_FILE qq(<!--\n);
        print DISK_FILE qq(  This file contains partition information about the disks on your golden\n);
        print DISK_FILE qq(  client.  It is stored here in a generic format that is used by your\n);
        print DISK_FILE qq(  SystemImager server to create an autoinstall script for cloning this\n);
        print DISK_FILE qq(  system.\n);
        print DISK_FILE qq(  \n);
        print DISK_FILE qq(  This output was brought to you by the partition tool "$partition_tool".\n);
        print DISK_FILE qq(  And by the numbers 4 and 5 and the letter Q.\n);
        print DISK_FILE qq(  \n);
        print DISK_FILE qq(  You can change the information in this file to affect how your target\n);
        print DISK_FILE qq(  machines are installed.  See "man autoinstallscript.conf" for details.\n);
        print DISK_FILE qq(-->\n);
        print DISK_FILE qq(\n);
        print DISK_FILE qq(<config>\n);

    close (DISK_FILE) or die ("FATAL: Couldn't close $file!"); 
}

# Usage:
# write_auto_install_script_conf_footer($file);
sub write_auto_install_script_conf_footer {

    my ($module, $file) = @_;

    # Open up the file that we'll be putting our generic partition info in. -BEF-
    open (DISK_FILE, ">>$file") or die ("FATAL: Couldn't open $file for appending!"); 
        print DISK_FILE "</config>\n";
    close (DISK_FILE) or die ("FATAL: Couldn't close $file!"); 
}


# Usage:
# save_partition_information($old_sfdisk_file, $partition_tool, $destination_file);
# save_partition_information($disk, $partition_tool, $file);
sub save_partition_information {
    my ($module, $disk, $partition_tool, $file) = @_;
    my ($label_type, $disk_size, $dev);


    if ($partition_tool eq "old_sfdisk_file") {
      $dev = "$disk";
      $label_type = "msdos";

    } else {
      $dev = "/dev/$disk";

      # Determine Label Type. -BEF-
      $label_type = _get_disk_label_type($partition_tool, $disk);
  
      # Make sure the tools we have available will work with this label type -BEF-
      _validate_label_type_and_partition_tool_combo($disk, $partition_tool, $label_type);
  
    }
 
    # Open up the file that we'll be putting our generic partition info in. -BEF-
    open (DISK_FILE, ">>$file") or die ("FATAL: Couldn't open $file for appending!"); 

    print DISK_FILE qq(  <disk dev=\"$dev\" label_type=\"$label_type\" unit_of_measurement=\"MB\">\n);

      # Output is very different with these different tools, so we need seperate
      # chunks of code here. -BEF-
      if ($partition_tool eq "parted") {
        my $cmd = "parted -s -- /dev/$disk print";
        my @partition_tool_output;

        # Catch output. -BEF-
        open (PARTITION_TOOL_OUTPUT, "$cmd|"); 
          @partition_tool_output = <PARTITION_TOOL_OUTPUT>;
        close (PARTITION_TOOL_OUTPUT);

        # Find partitions that are closest to the end of the disk. -BEF-
        my $end_of_last_partition_on_disk = 0;
        foreach (@partition_tool_output) {
            if (/^\d+\s+/) {
                my $end_of_this_partition = unpack("x17 A12", $_);
                $end_of_this_partition =~ s/\+//g;
                $end_of_this_partition =~ s/\-//g;
                if (! $end_of_this_partition ) { next; }    # If value was just "-", it's now blank. -BEF-
                if ( $end_of_this_partition > $end_of_last_partition_on_disk ) {
                    $end_of_last_partition_on_disk = $end_of_this_partition;
                }
            }
        }

        # Produce output. -BEF-
        foreach (@partition_tool_output) {

          # If we're looking at a line of info for a partition, process into generic
          # output. -BEF-
          if (/^\d+\s+/) {

            my ($minor, $startMB, $endMB, $partition_type, $fstype, $id, $flags, $name);

            chomp;

            if ($label_type eq "gpt") {

              # Unfortunately, parted doesen't produce it's output in a comma delimited
              # format, or even produce a n/a value such as "-" for fields that don't
              # contain any info.  Parted does, however, use a fixed width printing
              # template.  Below is a sample that I am basing the following fixed width
              # unpack on.  Hopefully, there will be no need for these widths to change
              # between now and the time that we have a better way of doing this.  The
              # pipe symbols "|" indicate where I've decided to start each field. -BEF-
              #
              # Sean Dague may have some better ideas on how to parse this output without
              # modifying parted. -BEF-
              #
              # Disk geometry for /dev/sdb: 0.000-17366.445 megabytes
              # Disk label type: GPT
              #          10        20        30        40        50        60        70        80
              # 12345678901234567890123456789012345678901234567890123456789012345678901234567890
              #     5           12          12          12                    22
              # 1234512345678901212345678901212345678901212345678901234567890121 -> to the end
              # |    |           |           |           |                     |
              # Minor    Start       End     Filesystem  Name                  Flags
              # 1          0.017     20.000                                    boot, lba
              # 2         21.000     40.000  FAT                               lba
              # 3         41.000  17366.429                                    lba
              ($minor, $startMB, $endMB, $fstype, $name, $flags) = unpack("A5 A12 A12 A12 A22 A*", $_);

              # In the case of a gpt partition, they're all primary, and parted doesn't
              # produce output to indicate this.
              $partition_type = "primary";

            } elsif ($label_type eq "msdos") {

              # Same as above, but the output is a little different for an msdos labelled disk.
              #
              # Disk geometry for /dev/sda: 0.000-17366.445 megabytes
              # Disk label type: msdos
              #          10        20        30        40        50        60        70        80
              # 12345678901234567890123456789012345678901234567890123456789012345678901234567890
              #     5           12          12        10          10
              # 1234512345678901212345678901212345678901212345678901 -> to the end
              # |    |           |           |         |           |
              # Minor    Start       End     Type      Filesystem  Flags
              # 1          0.016     17.000  primary   ext2        boot
              # 2         17.000  17366.000  extended              
              # 5         17.016  15409.000  logical   ext2        
              # 6      15409.016  17366.000  logical   linux-swap  
              ($minor, $startMB, $endMB, $partition_type, $fstype, $flags) = unpack("A5 A12 A12 A10 A10 A*", $_);

            }

            # $fstype may not be set, such as in the case of an extended
            # partition.  parted will also report no fstype, even if an 
            # fstype was chosen at partition time, if there is no filesystem
            # on the partition.  Additionally, parted will not report the
            # fstype specified at partition time, but rather will identify
            # the type of fs with which the partition was formatted.  This 
            # diatribe is with regards to parted <= parted-1.6.0-pre10. -BEF-
            #
            unless ($fstype) { $fstype = "-"; }
            $fstype = lc "$fstype";  # parted may report some fstypes in uppercase (parted 1.4.xx). -BEF-
            if ($fstype eq "fat") {  # parted 1.4.xx apparently reports all fat partitions as simply FAT. -BEF-
              my $device = $disk . $minor;
              my $device_size = _get_device_size($partition_tool,$device);
              if ($device_size < 500) {
                $fstype = "fat16";     
              } else {
                $fstype = "fat32";     
              }
            }

            my $size = $endMB - $startMB;

            if ($endMB == $end_of_last_partition_on_disk) {
                $size = "*";
            }

            unless($id) { $id=""; }

            _print_to_auto_install_conf_file( $minor, $size, $partition_type, $id, $name, $flags );

          }

        } # while (@partition_tool_output)

      } elsif ($partition_tool eq "sfdisk") {

        my $cmd = "sfdisk -l -uM /dev/$disk";

        local *PARTITION_TOOL_OUTPUT;
        open (PARTITION_TOOL_OUTPUT, "$cmd|"); 
          _turn_sfdisk_output_into_generic_partitionschemes_file($disk, \*PARTITION_TOOL_OUTPUT);
        close (PARTITION_TOOL_OUTPUT);

      } elsif ($partition_tool eq "old_sfdisk_file") {

        my $file = $disk;

        local *PARTITION_TOOL_OUTPUT;
        open (PARTITION_TOOL_OUTPUT, "<$file") or croak("Couldn't open $file for reading!"); 
          _turn_sfdisk_output_into_generic_partitionschemes_file($file, \*PARTITION_TOOL_OUTPUT);
        close (PARTITION_TOOL_OUTPUT);

      }

    print DISK_FILE "  </disk>\n";

    close (DISK_FILE);
}


# Usage:
# _turn_sfdisk_output_into_generic_partitionschemes_file($disk);
# _turn_sfdisk_output_into_generic_partitionschemes_file($old_sfdisk_file);
sub _turn_sfdisk_output_into_generic_partitionschemes_file {

    my ($disk, $PARTITION_TOOL_OUTPUT) = @_;
    my $units;

    my @partition_tool_output = <$PARTITION_TOOL_OUTPUT>;

    # Find partitions that are closest to the end of the disk. -BEF-
    my $end_of_last_partition_on_disk = 0;
    foreach (@partition_tool_output) {
        # Regex matches out the end of partition info if it is a number (if it 
        # isn't (i.e. '-') we didn't care about it anyway

        # /dev/\S+   = device name
        # \*?        = 0 or 1 '*' characters (bootable flag) (note \+? used as well)
        #        device   boot  start     end 
        if (m{^/dev/\S+\s+\*?\s+\d+\+?\s+(\d+)}) {
            my $end_of_this_partition = $1;
            if ( $end_of_this_partition > $end_of_last_partition_on_disk ) {
                $end_of_last_partition_on_disk = $end_of_this_partition;
            }
        }
    }

    # Produce output. -BEF-
    foreach (@partition_tool_output) {

      # If we catch the "Units =" line, and we confirm that the sfdisk output is using
      # megabytes or sectors, then we're good to go. -BEF-
      #
      if ((m|^Units =|) and (m|^Units = megabytes|)) {
        $units = "megabytes";
      } elsif ((m|^Units =|) and (m|^Units = sectors|)) {
        $units = "sectors";
      } 

      if (m|^/dev/|) {
        
        # Make sure that units has been set. -BEF-
        #
        unless ($units) {
          print "FATAL:  Your sfdisk output does not appear to be in megabytes or sectors,\n";
          print "        and I just don't know what to do with it!  The disk in question is:\n";
          die   "        $disk\n";
        }
     
        chomp;                             # Get rid of "newline".
     
        s/^\D+//;                          # Strip off /dev/device stuff, leaving just the 
                                           #   device's minor number.
        my $bootable;
        if (/\*/) { $bootable = "true"; }  # Remember if this is a bootable partition.
     
        s/\*//g;                           # Strip out the bootable indicator, so that we have
                                           #   the same number of fields for each minor device.
     
        # Split the remaining datar up into it's components. -BEF-
        #
        my ($minor, $startMB, $endMB, $startSECTORS, $endSECTORS, $junkMB, $junkBLOCKS, $junkSECTORS, $id) = split;
        if ($units eq "megabytes") {
          ($minor, $startMB, $endMB, $junkMB, $junkBLOCKS, $id) = split;

          # We're not keeping track of partitions that aren't there, 
          # so let's just move along, shall we? -BEF-
          #
          if (($startMB eq "0") and ($endMB eq "-")) { next; }

        } elsif ($units eq "sectors") {
          ($minor, $startSECTORS, $endSECTORS, $junkSECTORS, $id) = split;

          # We're not keeping track of partitions that aren't there, 
          # so let's just move along, shall we? -BEF-
          #
          if (($startMB eq "0") and ($endMB eq "-")) { next; }

          # What we've really got here, are sectors, not megabytes.  Let's turn 'em into
          # megabytes, eh? -BEF-
          #
          # sectors * 512 bytes per sector / 1024 bytes per kilobyte / 1024 kilobytes per megabyte = megabytes!
          #               
          $startMB = $startSECTORS * 512 / 1024 / 1024;
          $endMB   = $endSECTORS * 512 / 1024 / 1024;

          # Round down to 3 decimal places of precision. -BEF-
          $startMB = sprintf("%.3f", $startMB);
          $endMB = sprintf("%.3f", $endMB);
        }

        my ($partition_type, $fstype, $name, $flags);
     
        # Get rid of "+" signs.  We're not going to worry about these -- yet.  -BEF-
        #
        $startMB =~ s/\+//g; 
        $endMB   =~ s/\+//g;               
     
        # Get rid of "-" signs.  We're not going to worry about these -- yet.  We
        # must do this down here, as the "-" character is also used to indicate a
        # n/a value in certain fields.  If we strip it out before the split(), we
        # may end up with fewer fields in certain lines of output, therefore
        # knocking our results out of whack! -BEF-
        #
        $startMB =~ s/\-//g;                
        $endMB   =~ s/\-//g;               
     
        # Figure out what the fstype is based on sfdisk's Id tag.  As far as parted (the tool 
        # will be used to re-create this info) is concerned, the following fstypes are valid:
        # ext3, ext2, fat32, fat16, hfs, jfs, linux-swap, ntfs, reiserfs, hp-ufs, sun-ufs, xfs
        #
        # Also figure out what the partition type is (primary, extended, or logical), and any
        # other flags that may be set.  Valid flags from parted's perspective are:
        # boot, root, swap, hidden, raid, lvm, lba, hp-service
        #
        if ($id eq "0") {         # 0  Empty
          $partition_type = "-";
     
        } elsif ($id eq "4") {  # 4  FAT16 <32M
     
        } elsif ($id eq "5") {  # 5  Extended
          $partition_type = "extended";
     
        } elsif ($id eq "6") {  # 6  FAT16
     
        } elsif ($id eq "7") {  # 7  HPFS/NTFS
     
        } elsif ($id eq "b") {  # b  Win95 FAT32
     
        } elsif ($id eq "c") {  # c  Win95 FAT32 (LBA)
          $flags = "lba";
     
        } elsif ($id eq "e") {  # e  Win95 FAT16 (LBA)
          $flags = "lba";
     
        } elsif ($id eq "f") {  # f  Win95 Ext'd (LBA)
          $partition_type = "extended";
          $flags = "lba";
     
        } elsif ($id eq "14") {  # 14  Hidden FAT16 <32M
          $flags = "hidden";
     
        } elsif ($id eq "16") {  # 16  Hidden FAT16
          $flags = "hidden";
     
        } elsif ($id eq "17") {  # 17  Hidden HPFS/NTFS
          $flags = "hidden";
     
        } elsif ($id eq "1b") {  # 1b  Hidden Win95 FAT32
          $flags = "hidden";
     
        } elsif ($id eq "1c") {  # 1c  Hidden Win95 FAT32 (LBA)
          $flags = "hidden, lba";
     
        } elsif ($id eq "1e") {  # 1e  Hidden Win95 FAT16 (LBA)
          $flags = "hidden, lba";
     
        } elsif ($id eq "41") {  # 41  PPC PReP Boot

        } elsif ($id eq "82") {  # 82  Linux swap
     
        } elsif ($id eq "83") {  # 83  Linux
     
        } elsif ($id eq "85") {  # 85  Linux extended
          $partition_type = "extended";
     
        } elsif ($id eq "8e") {  # 8e  Linux LVM
          $flags = "lvm";
     
        } elsif ($id eq "ef") {  # ef  EFI (FAT-12/16/32)
     
        } elsif ($id eq "fd") {  # fd  Linux raid autodetect
          $flags = "raid";
     
        } else {
          print qq(\n\n);
          print qq(FATAL:  I don't quite know how to interpret the Id tag of "$id" on partition\n);
          print qq(        number "$minor" on disk "/dev/$disk".  Please submit a bug report, including\n);
          print qq(        this output, at http://systemimager.org/support/.  Thanks!  -Brian\n);
          exit 1;
        }
     
        # Add boot flag to flags, if necessary.
        if ($bootable) {
          if ($flags) { 
            $flags = "boot, " . $flags;
          } else {
            $flags = "boot";
          }
        }
     
        # If the partition_type is still not known, figure it out by deduction. -BEF-
        unless ($partition_type) {
          if ($minor < "5") {
            # Can't have primary partitions over 4, so if it's not explicitly set
            # as an extended partition, it must be a primary. -BEF-
            $partition_type = "primary";
          } else {
            # Otherwise, it's only logical.  -BEF-
            $partition_type = "logical";
          }
        }
     
        my $size = $endMB - $startMB;

        if ($endMB == $end_of_last_partition_on_disk) {
            $size = "*";
        }

        _print_to_auto_install_conf_file( $minor, $size, $partition_type, $id, $name, $flags );
     
      }
    }
}


# Usage:
# _print_to_auto_install_conf_file($minor, $startMB, $endMB, $partition_type, $id, $name, $flags);
sub _print_to_auto_install_conf_file {

    my ($minor, $size, $partition_type, $id, $name, $flags) = @_;

    # Name may not be set in some cases.
    unless ($name) { $name = "-"; }

    # If we still have no flags, go ahead and produce a n/a value of "-", and
    # make sure that there are no spaces in between flags.
    if ($flags) { 
      $flags =~ s/\s+//g;
    } else {
      $flags = "-";  # Set to n/a value. -BEF-
    }
    
    # Begin output for a line.
    print DISK_FILE qq(    <part  num="$minor"  size="$size"  p_type="$partition_type"  p_name="$name"  flags="$flags");

    # id= is optional, and should only be used when needed. -BEF-
    if (
        ("$id" eq "41")  # 41  PPC PReP Boot 
       ) {
        print DISK_FILE qq(  id="$id");
    }
    print DISK_FILE qq( />\n);
}


# Usage: 
# my $label_type = _get_disk_label_type($partition_tool, $disk);
sub _get_disk_label_type {

    my ($partition_tool, $disk) = @_;
    my $label_type;

    # If we're using parted, simply take the label_type from the 4th item of
    # the "Disk label type: <type>" line of output.
    # 
    if ($partition_tool eq "parted") {
      my $cmd = "parted -s -- /dev/$disk print";
      open (TMP, "$cmd|"); 
        while (<TMP>) {
	  if (/Disk label type:/) {
	    (my $Disk, my $label, my $type, $label_type) = split;
            $label_type = lc $label_type;
	  }
	}
      close (TMP);

    # If we're using sfdisk, then we search for a partition Id of 0xee.  sfdisk
    # represents this with a line in it's output that looks like this:
    #
    #  "/dev/sdb1 : start=        1, size=35566479, Id=ee"
    #
    } elsif ($partition_tool eq "sfdisk") {
      my $cmd = "sfdisk -d /dev/$disk";
      open (TMP, "$cmd|"); 
        while (<TMP>) {
	  if (/Id=ee/) { $label_type = "gpt"; }
	}
      close (TMP);

      # sfdisk assumes every label type will be msdos, so unless we get a hit
      # in the above loop, we also assume the label type is msdos.
      unless ($label_type) { $label_type = "msdos"; }
    }
    return $label_type;
}


# Usage:
# _validate_label_type_and_partition_tool_combo($disk, $partition_tool, $label_type);
sub _validate_label_type_and_partition_tool_combo {

    my ($disk, $partition_tool, $label_type) = @_;

    if (($label_type eq "gpt") and ($partition_tool eq "sfdisk")) {
      print qq(FATAL:  I'm dreadfully sorry, but I must give up.  You appear to have a GPT\n);
      print qq(        style partition label on /dev/$disk, but do not have "parted"\n);
      print qq(        installed.  Please install "parted" (partition editor) and try again.\n);
      print qq(        You can find parted at http://www.gnu.org/software/parted/.\n);
      exit 1;
    }
}


# Usage: 
# my $device_size = _get_device_size($partition_tool,$device);
sub _get_device_size {

    my ($partition_tool, $device) = @_;
    my $device_size;

    # If we're using parted, simply take the device_size from the 
    # the "Disk geometry for /dev/sdb: 0.000-17366.445 megabytes"
    # line of output. -BEF-
    # 
    if ($partition_tool eq "parted") {
      my $cmd = "parted -s -- /dev/$device print";
      open (TMP, "$cmd|"); 
        while (<TMP>) {
	  if (/Disk geometry for/) {
            (my $junk, $_) = split (/-/);
            ($device_size, $junk) = split;
	  }
	}
      close (TMP);

    # If we're using sfdisk, it spits out a single number in bytes.  Divide by 1024 
    # and we're done. -BEF-
    #
    } elsif ($partition_tool eq "sfdisk") {
      my $cmd = "sfdisk -s /dev/$device";
      open (TMP, "$cmd|"); 
        while (<TMP>) {
          chomp;
          my $device_size_in_bytes = $_;
          $device_size = ($device_size_in_bytes / 1024);
          $device_size = sprintf("%.3f", $device_size);
	}
      close (TMP);
    }
    return $device_size;
}


