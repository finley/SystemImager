#!/bin/sh

#
# "SystemImager" - Copyright (C) 1999-2001 Brian Elliott Finley <brian@systemimager.org>
#
#   Others who have contributed to this code:
#     Curtis Zinzilieta <czinzilieta@valinux.com>
#     dann frazier <dannf@fc.hp.com>
#
# This file is: stage2.sh
#

. /etc/boel_lib

umount /oldroot/proc || shellout
mount proc /proc -t proc || shellout

# turn on devfs w/ compatability symlinks, if there's kernel support
grep devfs /proc/filesystems > /dev/null
if [ $? -eq 0 ]; then
  echo "devfs support detected - mounting /dev..."
  mount devfs -t devfs /dev || shellout
  devfsd /dev || shellout
else
  echo "No devfs support detected, not mounting /dev."
fi

### BEGIN load modules
echo "Loading default modules"
DEFAULT_MODULES="reiserfs xfs md raid0 raid1 raid5 linear"
for MODULE in $MODULES; do
  if ! (modprobe -l ${MODULE}.o | grep ${MODULE}.o) > /dev/null; then
    echo "Skipping $MODULE - assuming it is compiled into the kernel."
    continue
  fi
  echo "Loading $MODULE:"
  modprobe $MODULE || shellout
done

echo "Discovering hardware and loading driver modules..."
MODULES=`discover --module bridge scsi ide`
for MODULE in $MODULES; do
  if ! (modprobe -l ${MODULE}.o | grep ${MODULE}.o) > /dev/null; then
    echo "Skipping $MODULE - assuming it is compiled into the kernel."
    continue
  fi
  echo "Loading $MODULE:"
  modprobe $MODULE
done

echo "----------------------------------------------------------------"
echo "If your storage device(s) was not discovered, please file a bug."
echo "----------------------------------------------------------------"
### END load modules

# suck in variables planted by the stage 1 rcS script
. /oldroot/tmp/variables.txt

### BEGIN Are we installing over SSH?
if [ ! -z $SSH_DOWNLOAD_URL ]; then
  # create root's ssh dir
  mkdir /root/.ssh

  # If a private key exists, put it in the right place so this autoinstall
  # client can use it to authenticate itself to the imageserver.
  # (ssh1 style user private key)
  if [ -e /oldroot/floppy/identity ]; then
    PRIVATE_KEY=/root/.ssh/identity
    cp /oldroot/floppy/identity $PRIVATE_KEY || shellout
    chmod 600 $PRIVATE_KEY           || shellout
  fi
  # (ssh2 style user private key)
  if [ -e /oldroot/floppy/id_dsa ]; then
    PRIVATE_KEY=/root/.ssh/id_dsa
    cp /oldroot/floppy/id_dsa $PRIVATE_KEY || shellout
    chmod 600 $PRIVATE_KEY         || shellout
  fi

  ### BEGIN PRIVATE KEY ###
  # If we have a private key from the media above, go ahead and open a secure
  # tunnel to the imageserver and continue with the autoinstall like normal.
  if [ ! -z $PRIVATE_KEY ]; then
    # with the prep ready, start the ssh tunnel connection.
    # the sleep command executes remotely.  Just need something long here
    # as the connection will be severed when the newly imaged client reboots
    # 14400 = 4 hours...if we're not imaged by then....oh boy!
    #
    # Determine if we should run interactive and set redirection options appropriately.
    # So if the key is blank, go interactive. (Suggested by Don Stocks <don_stocks@leaseloan.com>)
    if [ -s $PRIVATE_KEY ]; then
      # key is *not* blank
      REDIRECTION_OPTIONS="> /dev/null 2>&1"
    else
      # key is blank - go interactive
      REDIRECTION_OPTIONS=""
    fi
    ssh -l $SSH_USER -n -f -L873:127.0.0.1:873 $IMAGESERVER sleep 14400 $REDIRECTION_OPTIONS
    if [ $? != 0 ]; then
      echo
      echo "ssh tunnel command to $IMAGESERVER failed!!!"
      echo "The command was: ssh -l $SSH_USER -n -f -L873:127.0.0.1:873 $IMAGESERVER sleep 14400"
      echo
      shellout
    fi

    # Since we're using SSH, change the $IMAGESERVER variable to reflect
    # the forwarded connection.
    IMAGESERVER=127.0.0.1
  ### END PRIVATE KEY ###
  else
    # Looks like we didn't get a private key from the floppy, so let's just
    # fire up sshd and wait for someone to connect to us to initiate the
    # next step of the autoinstall.

    # download authorized_keys
    # (public keys of users allowed to ssh *in* to this machine)
    files="authorized_keys"
    for file in $files
    do
      echo
      echo "snarfing $SSH_DOWNLOAD_URL/$file..."
      snarf $SSH_DOWNLOAD_URL/$file /root/.ssh/$file
      if [ $? != 0 ]; then
        echo
        echo "snarf of $SSH_DOWNLOAD_URL/$file failed!!!"
        echo
        shellout
      fi
    done

    # set permissions to 600 -- otherwise, sshd will refuse to use it
    chmod 600 /root/.ssh/authorized_keys || shellout

    # Since we're using SSH, change the $IMAGESERVER variable to reflect
    # the forwarded connection.
    IMAGESERVER=127.0.0.1

    # save variables for autoinstall script
    write_variables || shellout

    # create a private host key for this autoinstall client
    echo
    echo "Using ssh-keygen to create this hosts private key"
    echo
    ssh-keygen -N "" -f /etc/ssh/ssh_host_key || shellout

    # create necessary ptys, etc. for sshd
    mknod /dev/ptmx c 5 2                    || shellout
    chmod 666 /dev/ptmx                      || shellout
    mkdir /dev/pts                           || shellout
    echo "none /dev/pts devpts" > /etc/fstab || shellout
    mount /dev/pts                           || shellout

    # if hostname not set, try DNS
    if [ -z $HOSTNAME ]; then
      echo
      echo "Trying to get hostname via DNS..."
      echo
      get_hostname_by_dns
    fi

    if [ -z $HOSTNAME ]; then
      HOST_OR_IP=$IPADDR
    else
      HOST_OR_IP=$HOSTNAME
    fi

    echo
    echo
    echo "Starting sshd.  You must now go to your imageserver and issue"
    echo "the following command:"
    echo
    echo " \"pushupdate -continue-install -image <IMAGE> -client ${HOST_OR_IP}\"."
    echo
    echo
    
    # fire up sshd and wait
    sshd -f /etc/ssh/sshd_config -h /etc/ssh/ssh_host_key || shellout

    # Give sshd time to initialize before we yank the parent process
    # rug out from underneath it.
    sleep 15

    # remove rug
    exit 1
  fi
fi
### END Are we installing over SSH?

# If hostname was not set in /floppy/local.cfg or by DHCP, figure it now
# get hosts file if necessary
if [ -z $HOSTNAME ]; then
  file="hosts"
  echo "Using rsync to copy $IMAGESERVER::$SCRIPTS/$file..."
  rsync -aL $IMAGESERVER::$SCRIPTS/$file /tmp/

  if [ -e /tmp/hosts ]; then
    # add escape characters to IPADDR so that it can be used to find HOSTNAME below
    IPADDR_ESCAPED=`echo "$IPADDR" | sed -e 's/\./\\\./g'`

    # get HOSTNAME by parsing hosts file
    echo "Looking for hostname of this host int /tmp/hosts by IP: $IPADDR ..."

    # Command summary by line:
    # 1: convert tabs to spaces -- contains a literal tab: <ctrl>+<v> then <tab>
    # 2: remove comments
    # 3: add a space at the beginning of every line
    # 4: get line with IP address (no more no less)
    # 5: get hostname or hostname.domain.name
    # 6: strip .domain.name if necessary -- $DOMAINNAME was set earlier by dhcp
    HOSTNAME=`
      sed 's/       / /g' /tmp/hosts \
      | sed 's/#.*//g' \
      | sed 's/^/ /' \
      | grep " $IPADDR_ESCAPED " \
      | mawk '{print $2}' \
      | sed "s/.$DOMAINNAME//g"
    `
  fi

  # if hostname not set, try DNS
  if [ -z $HOSTNAME ]; then
    echo
    echo "Trying to get hostname via DNS..."
    echo
    get_hostname_by_dns
  fi
      
  if [ -z $HOSTNAME ]; then
    echo
    echo "Couldn't find this hosts name in /tmp/hosts or via DNS!!!"
    echo
    shellout
  fi
fi

echo
echo "This host's name is ${HOSTNAME}."

# try to get an autoinstall script based on $HOSTNAME
file="${HOSTNAME}.sh"
echo
echo "I will now try to get the autoinstall script:  $file"
rsync -aL $IMAGESERVER::$SCRIPTS/$file /tmp/
if [ $? != 0 ]; then
  echo "rsync copy of $IMAGESERVER::$SCRIPTS/$file failed!!!"

  # try to get the generic master file, since no specific file was found
  # strip off trailing numerics, and use that for an autoinstall script name
  BASE_HOSTNAME=`echo $HOSTNAME \
  | sed "s/[0-9]*$//"` 

  file="${BASE_HOSTNAME}.master"
  echo
  echo "I will now try to get the autoinstall script:  $file"
  rsync -aL $IMAGESERVER::$SCRIPTS/$file /tmp/
  if [ $? != 0 ]; then
    # we really failed, no more fallback
    echo
    echo "rsync copy of $IMAGESERVER::$SCRIPTS/$file failed!!!"
    echo
    echo "All attempts to get an autoinstall script have failed!!!"
    echo
    shellout
  fi
fi

# pass all variables set here on to the hostname.sh script
write_variables || shellout

# run the autoinstall script that was dynamically created by getimage
if [ -f /tmp/$file ]; then
  chmod 755 /tmp/$file || shellout
  echo
  echo "I will now run the autoinstall script: $file"
  echo
  /tmp/$file || shellout
fi

exit 0
