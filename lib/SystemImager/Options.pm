#
#   "SystemImager"
#
#   Copyright (C) 2003 Brian Elliott Finley <finley@mcs.anl.gov>
#
#       $Id$
#

package SystemImager::Options;

use strict;

################################################################################
#
# Subroutines in this module include:
#
#   confedit_options_body
#   confedit_options_header
#   copyright
#   generic_footer
#   generic_options_help_version
#   getimage_options_body
#   getimage_options_header
#   mkclientnetboot_options_body
#   mkclientnetboot_options_header
#   pushupdate_options_body
#   pushupdate_options_header
#   updateclient_options_body
#   updateclient_options_header
#
################################################################################


#
# Usage:
#
#   $version_info .= SystemImager::Options->copyright();
#
sub copyright {

return << "EOF";
Copyright (C) 1999-2003 Brian Elliott Finley <brian\@bgsw.net>
Please see CREDITS for a full list of contributors.

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->pushupdate_options_header();
#
sub pushupdate_options_header {

return << "EOF";
Usage: si_pushupdate [OPTION]... --client HOSTNAME   --server HOSTNAME --image IMAGENAME --updateclient-options "[OPTION]..."
  or   si_pushupdate [OPTION]... --clients-file FILE --server HOSTNAME --updateclient-options "[OPTION]..."

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->confedit_options_header();
#
sub confedit_options_header {

return << "EOF";
Usage:  confedit --file CONF_FILE --entry "MODULE" [--data "DATA"]

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->getimage_options_header();
#
sub getimage_options_header {

return << "EOF";
Usage: si_getimage [OPTION]...  --golden-client HOSTNAME --image IMAGENAME

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->updateclient_options_header();
#
sub updateclient_options_header {

return << "EOF";
Usage: si_updateclient [OPTION]... --server HOSTNAME --image IMAGENAME

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->generic_options_help_version();
#
sub generic_options_help_version {

return << "EOF";
Options:
    (options can be presented in any order and may be abbreviated)

 --help
    Display this output.

 --version
    Display version and copyright information.

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->pushupdate_options_body();
#
sub pushupdate_options_body {

return << "EOF";
 --client HOSTNAME
    Host name of the client you want to update.  When used with
    --continue-install, the name of the client to autoinstall.

 --clients-file FILE
    Read host names and images to process from FILE.  Image names in this file
    will override an imagename specified as part of --updateclient-options. 

    File format is:

        client1     imagename
        client2     other_imagename
        client3     other_imagename

 --image IMAGENAME
    Name of image to install or update client with.  This setting will override
    an imagename specified as part of --updateclient-options.

 --updateclient-options "[OPTION]..."
    Pass all options within \"quotes\" to si_updateclient directly.  Note that
    si_updateclient\'s --image option need not be specified as it will be
    overridden by si_pushupdate\'s --image option, or by settings in the file
    specified with --clients-file.
    
 --range N-N
    Number range used to create a series of host names based on the --client
    option.  For example, "--client www --range 1-3" will cause si_pushupdate
    to use www1, www2, and www3 as host names.  If no --range is given with 
    --client, then si_pushupdate assumes that only one client is to be updated.

 --domain DOMAINNAME
    If this option is used, DOMAINNAME will be appended to the client host
    name(s).

 --concurrent-processes N
    Number of concurrent process to run.  If this option is not used, N will
    default to 1.

 --continue-install
    Hosts should be treated as autoinstall clients waiting for further
    instruction.

 --ssh-user USERNAME
    Username for ssh connection _to_ the client.  Seperate from 
    si_updateclient\'s --ssh-user option.

 --log "STRING"
    Quoted string for log file format.  See the rsyncd.conf man page for
    options.  Note that this is for logging that happens on the imageserver and
    is in addition to the --log option that gets passed to si_updateclient.


Options for --updateclient-options:
    (The following options will be passed on to the si_updateclient command.)

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->confedit_options_body();
#
sub confedit_options_body {

return << 'EOF';
 --file CONF_FILE
    Path to configuration file to manipulate.

 --entry "MODULE"
    Name of the module to add or remove.  You _must_ specify --data, or MODULE
    will be removed.

 --data "DATA"
    Acts as a boolean flag, as well as specifying "DATA".  If specified, 
    the module specified by --entry will be added.  If not specified, the
    module specified by --entry will be removed.

Example:
    confedit \
      --file  flamethrower.conf \
      --entry "boot-ia64-standard" \
      --data  "DIR = /usr/share/systemimager/boot/ia64/standard \n OPT2 = Value"
              (Note the use of "\n" to seperate lines for multi-line entries.)

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->updateclient_options_body();
#
sub updateclient_options_body {

return << "EOF";
 --server HOSTNAME
    Hostname or IP address of the imageserver.

 --image IMAGENAME
    Image from which the client should be updated.

 --override OVERRIDE
    Override directory to use.  Multiple overrides can be specified.
    (Ie: -override THIS -override THAT)

 --directory "DIRECTORY"
    Absolute path of directory to be updated.  
    (defaults to "/")

 --no-bootloader
    Don\'t run bootloader setup (lilo, grub, etc.) after update completes.

 --autoinstall
    Autoinstall this client the next time it reboots.  
    (conflicts with -no-bootloader)

 --flavor FLAVOR
    The boot flavor to used for doing an autoinstall.  
    (assumes -autoinstall).

 --configure-from DEVICE   
    Only used with -autoinstall.  Stores the network configuration for DEVICE
    in the /local.cfg file so that the same settings will be used during the
    autoinstall process.

 --ssh-user USERNAME
    Username for ssh connection from the client.  Only needed if a secure
    connection is required.

 --reboot
    Reboot client after update completes.

 --dry-run
    Only shows what would have been updated.

 --no-delete
    Do not delete any file on the client, only update different files
    and download newer.

 --log "STRING"
    Quoted string for log file format.  See the rsyncd.conf man page for 
    options.

Tip: Use \"si_lsimage --server HOSTNAME\" to get a list of available images.

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->getimage_options_body();
#
sub getimage_options_body {

return << "EOF";
 --golden-client HOSTNAME
    Hostname or IP address of the \"golden\" client.

 --image IMAGENAME
    Where IMAGENAME is the name to assign to the image you are retrieving.
    This can be either the name of a new image if you want to create a new
    image, or the name of an existing image if you want to update an image.

 --ssh-user USERNAME
    Username for ssh connection to the client.  Only needed if a secure
    connection is required.

 --log "STRING"
    Quoted string for log file format.  See \"man rsyncd.conf\" for options.

 --quiet
    Don\'t ask any questions or print any output (other than errors). In this
    mode, no warning will be given if the image already exists on the server.

 --directory PATH
    The full path and directory name where you want this image to be stored.
    The directory bearing the image name itself will be placed inside the
    directory specified here.

 --exclude PATH
    Don\'t pull the contents of PATH from the golden client.  PATH must be
    absolute (starting with a "/").  
			  
    To exclude a single file use:
        --exclude /directoryname/filename

    To exclude a directory and it's contents use:
        --exclude /directoryname/

    To exclude the contents of a directory, but pull the directory itself use:
        --exclude "/directoryname/*"

 --exclude-file FILE
    Don\'t pull the PATHs specified in FILE from the golden client.

 --update-script [YES|NO]
    Update the \$image.master script?  Defaults to NO if --quiet.  If not
    specified you will be prompted to confirm an update.

 --listing
    Show each filename as it is copied over during install.  This is
    useful to increase the verbosity of the installation when you need more
    informations for debugging.  Do not use this option if your console
    device is too slow (e.g. serial console), otherwise it could be the
    bottleneck of your installation. 

 --autodetect-disks
    Try to detect available disks on the client when installing instead of
    using devices specified in autoinstallscript.conf.

The following options affect the autoinstall client after autoinstalling:

 --ip-assignment METHOD
    Where METHOD can be DHCP, STATIC, or REPLICANT.

    DHCP
        A DHCP server will assign IP addresses to clients installed with this
        image.  They may be assigned a different address each time.  If you
        want to use DHCP, but must ensure that your clients receive the same
        IP address each time, see "man si_mkdhcpstatic".

    STATIC
        The IP address the client uses during autoinstall will be permanently
        assigned to that client.

    REPLICANT
        Don't mess with the network settings in this image.  I'm using it as a
        backup and quick restore mechanism for a single machine.

 --post-install ACTION
    Where ACTION can be beep, reboot, or shutdown.

    beep 
        Clients will beep incessantly after succussful completion of an
        autoinstall.  (default)

    reboot 
        Clients will reboot themselves after successful completion of an
        autoinstall.

    shutdown 
        Clients will halt themselves after successful completion of an
        autoinstall.

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->generic_footer();
#
sub generic_footer {

return << "EOF";
Download, report bugs, and make suggestions at:
http://systemimager.org/

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->mkclientnetboot_options_header();
#
sub mkclientnetboot_options_header {

return << "EOF";
Usage: si_mkclientnetboot --netboot   --clients "HOST1 HOST2 ..."
  or   si_mkclientnetboot --localboot --clients "HOST1 HOST2 ..."

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->mkclientnetboot_options_body();
#
sub mkclientnetboot_options_body {

return << "EOF";
 --netboot
    Configure the network bootloader for the specified clients, so that it boots
    them from the network.

 --localboot
    Configure the network bootloader for the specified clients, so that they
    boot from their local disk.

 --clients "HOST1 HOST2 ..."
    A space seperated list of host names and/or dotted quad IP addresses.  This
    server (assuming it is a boot server) will be told to let these clients net
    boot from this server, at least until they've completed a successful
    SystemImager autoinstall.

EOF
}


return 1;

