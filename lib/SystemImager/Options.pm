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
#   XXX grep me for ^sub
#
################################################################################


#
# Usage:
#
#   $help = $help . SystemImager::Options->pushupdate_options_header();
#
sub pushupdate_options_header {

return << "EOF";
Usage: pushupdate [OPTION]... --client HOSTNAME   --server HOSTNAME --image IMAGENAME --updateclient-options "[OPTION]..."
  or   pushupdate [OPTION]... --clients-file FILE --server HOSTNAME --updateclient-options "[OPTION]..."

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->updateclient_options_header();
#
sub updateclient_options_header {

return << "EOF";
Usage: updateclient [OPTION]... --server HOSTNAME --image IMAGENAME

EOF
}


#
# Usage:
#
#   $help = $help . SystemImager::Options->generic_options_help_version_header();
#
sub generic_options_help_version_header {

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
    Pass all options within \"quotes\" to updateclient directly.  Note that
    updateclient\'s --image option need not be specified as it will be
    overridden by pushupdate\'s --image option, or by settings in the file
    specified with --clients-file.
    
 --range N-N
    Number range used to create a series of host names based on the -client
    option.  For example, "-client www -range 1-3" will cause pushupdate to use
    www1, www2, and www3 as host names.  If no -range is given with -client, 
    then pushupdate assumes that only one client is to be updated.

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
    Username for ssh connection _to_ the client.  Seperate from updateclient\'s
    --ssh-user option.

 --log "STRING"
    Quoted string for log file format.  See the rsyncd.conf man page for
    options.  Note that this is for logging that happens on the imageserver and
    is in addition to the --log option that gets passed to updateclient.


Options for --updateclient-options:
    (The following options will be passed on to the updateclient command.)

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

 --log "STRING"
    Quoted string for log file format.  See the rsyncd.conf man page for 
    options.

Tip: Use \"lsimage --server HOSTNAME\" to get a list of available images.

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

return 1;

