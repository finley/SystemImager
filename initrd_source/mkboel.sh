#!/bin/sh
#
# mkboel.sh
# this script creates a BOEL ramdisk given a set of components.
# for usage details, see the usage() function below.
#
# Copyright 2001 by dann frazier <dannf@fc.hp.com>
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

BUSYBOX_SBIN="halt ifconfig init klogd mkswap modprobe poweroff reboot route swapoff swapon syslogd update"
BUSYBOX_USR_SBIN="chroot"
BUSYBOX_BIN="cat chgrp chmod chown cp dd df dmesg echo false grep gunzip gzip hostname kill ln ls mkdir mknod more mount mv ping ps pwd rm rmdir sed sleep sync tar touch true umount uname zcat"
BUSYBOX_USR_BIN="[ ar clear cut dirname expr find free head id killall logger md5sum reset sort tail telnet test tr tty uniq uptime wc wget which whoami"

extra_blocks="0"
extra_inodes="0"
fs="ext2"
temp_dir=""

busybox_specified="false"
outfile_specified="false"

usage() {
  echo "mkboel.sh -busybox <busybox> -d <dev_ls-lR> [ -s <skeleton_dir> ]"
  echo "   [ -eb <extra_blocks> ] [ -ei <extra_inodes> ] [ -fs <ext2|cramfs> ]"
  echo "   [ -c<dir> <file1>,<file2>,...,<fileN> ] -o <outfile>"
  echo ""
}

cleanup_and_die() {
  rm -rf $temp_dir
  exit 1
}

if [ "`id -u`" -ne 0 ]; then
  echo "Must be run as root."
  exit 1
fi

## create a new temporary directory 
i=0
while [ -e /tmp/mkboel.tmp$i ]; do
  i=`expr $i + 1`
done

temp_dir=/tmp/mkboel.tmp$i
for dir in bin dev lib proc root sbin usr/bin usr/sbin etc/init.d var/run; do
  mkdir -p -m 755 $temp_dir/$dir
done
mkdir -m 1777 $temp_dir/tmp

if [ $? -ne 0 ]; then
  echo "Error:  Could not create $temp_dir."
  exit 1
fi
  
state="s0"
dest_dir=""
p=`basename $0`

for argument in $@; do
  if [ "$state" == "s0" ]; then
    case $argument in
      -busybox ) state="looking_for_busybox" ;;
           -d  ) state="looking_for_dev_ls-lR" ;;
           -c* ) state="looking_for_file_list"
	         dest_dir=`echo $argument | cut -b 3-`
		 ;;
	   -eb ) state="looking_for_extra_blocks" ;;
	   -ei ) state="looking_for_extra_inodes" ;;
	   -s  ) state="looking_for_skeleton_dir" ;;
	   -fs ) state="looking_for_fs" ;;
	   -o  ) state="looking_for_out_file";;
	     * ) echo "Invalid argument: $argument"
	         usage
	         exit 1
		 ;;
    esac
  elif [ "$state" == "looking_for_busybox" ]; then
    if [ ! -f "$argument" ]; then
      echo "Error:  Couldn't find $argument."
      cleanup_and_die
    fi
    busybox_specified="true"
    cp -a $argument $temp_dir/bin
    applets=""
    busybox_delimiter_found="false"
    TMPFILE=`mktemp /tmp/$p.XXXXXX` || exit 1
    $temp_dir/bin/busybox > $TMPFILE 2>&1
    while :; do
      read line
      if [ $? -ne 0 ]; then
        break
      fi
      if [ "$busybox_delimiter_found" == "false" ]; then
        echo "$line" | grep "Currently defined functions:" > /dev/null
	if  [ $? -eq 0 ]; then
	  busybox_delimiter_found="true"
	fi
      else
	applets="$applets $line"
      fi
    done < $TMPFILE
    rm $TMPFILE
    if [ "$busybox_delimiter_found" == "false" ]; then
      echo "Error:  this doesn't look like a busybox binary."
      echo "Maybe you're using a newer version that lists available"
      echo "applets in a different way."
    fi

    for applet in $applets; do
      if [ "$applet" == "busybox" ]; then
        continue
      fi
      done="false"
      applet=`echo $applet | sed s/","/""/`
      for file in $BUSYBOX_BIN; do
        if [ "$applet" == "$file" ]; then
	  ln $temp_dir/bin/busybox $temp_dir/bin/$applet
	  done="true"
	  break
	fi
      done
      if [ "$done" == "true" ]; then
        continue
      fi
      for file in $BUSYBOX_USR_BIN; do
        if [ "$applet" == "$file" ]; then
	  ln $temp_dir/bin/busybox $temp_dir/usr/bin/$applet
	  done="true"
	  break
	fi
      done
      if [ "$done" == "true" ]; then
        continue
      fi
      for file in $BUSYBOX_SBIN; do
        if [ "$applet" == "$file" ]; then
	  ln $temp_dir/bin/busybox $temp_dir/sbin/$applet
	  done="true"
	  break
	fi
      done
      if [ "$done" == "true" ]; then
        continue
      fi
      for file in $BUSYBOX_USR_SBIN; do
        if [ "$applet" == "$file" ]; then
	  ln $temp_dir/bin/busybox $temp_dir/usr/sbin/$applet
	  done="true"
	  break
	fi
      done
      if [ "$done" == "false" ]; then
        echo
        echo "********** WARNING **********"
        echo "I don't know which directory to link $applet into."
	echo "I'm going to link it into /bin - but my data should be updated."
        echo "********** WARNING **********"
	echo
	ln $temp_dir/bin/busybox $temp_dir/bin/$applet
      fi
    done
    state="s0"
  elif [ "$state" == "looking_for_dev_ls-lR" ]; then
    if [ ! -f "$argument" ]; then
      echo "Error: $argument does not exist or is not a regular file."
      cleanup_and_die
    fi
    ./dupdevs.sh $temp_dir/dev < $argument
    if [ $? -ne 0 ]; then
      echo "Error: Creation of /dev entries failed."
      cleanup_and_die
    fi
    state="s0"
  elif [ "$state" == "looking_for_file_list" ]; then
    # this should really check if dest_dir is a subdirectory of $temp_dir
    TMPFILE=`mktemp /tmp/$p.XXXXXX` || exit 1
    IFS=","
    echo "$argument" > $TMPFILE
    read filelist < $TMPFILE
    rm $TMPFILE
    for file in $filelist; do
      if [ ! -f $file ]; then
        echo "Error:  $file does not exist, or is not a regular file."
	cleanup_and_die
      fi
      cp -a $file $temp_dir/$dest_dir
    done
    state="s0"
  elif [ "$state" == "looking_for_extra_blocks" ]; then
    extra_blocks="$argument"
    state="s0"
  elif [ "$state" == "looking_for_extra_inodes" ]; then
    extra_inodes="$argument"
    state="s0"
  elif [ "$state" == "looking_for_skeleton_dir" ]; then
    if [ ! -d "$argument" ]; then
      echo "$argument does not exist, or is not a directory."
      exit 1
    fi
    cp -a $argument/* $temp_dir
    if [ $? -ne 0 ]; then
      echo "Error copying over skeleton directory"
      exit 1
    fi
    state="s0"
  elif [ "$state" == "looking_for_fs" ]; then
    if [ "$argument" != "ext2" ] && [ "$argument" != "cramfs" ]; then
      echo "Invalid filesystem."
      exit 1
    fi
    fs=$argument
    state="s0"
  elif [ "$state" == "looking_for_out_file" ]; then
    outfile_specified="true"
    outfile="$argument"
    state="s0"
  fi
done

if [ "$busybox_specified" != "true" ]; then
  echo "Error: busybox binary not specified."
  usage
  cleanup_and_die
fi
if [ "$outfile_specified" != "true" ]; then
  echo "Error: no outfile specified."
  usage
  cleanup_and_die
fi

./mklibs.sh -v -d $temp_dir/lib $temp_dir/lib/* $temp_dir/bin/* \
  $temp_dir/sbin/* $temp_dir/usr/bin/* $temp_dir/usr/sbin/*
  
if [ $? -ne 0 ]; then
  echo "Error:  library creation failed."
  exit 1
fi

chown 0 -R $temp_dir
chgrp 0 -R $temp_dir

if [ "$fs" == "ext2" ]; then
  dd if=/dev/zero of=$outfile bs=1k \
    count=$(expr $(du -s $temp_dir | cut -f 1) + $extra_blocks + 256)
  if [ $? -ne 0 ]; then
    echo "Error: ramdisk creation failed."
    cleanup_and_die
  fi
  mke2fs -N $(expr $(find $temp_dir -printf "%i\n" | sort | uniq | wc -l | \
                     tr -d [:blank:] ) + $extra_inodes + 10) -m 0 -q -F $outfile
  if [ $? -ne 0 ]; then
    echo "Error: ext2 filesystem creation failed."
    cleanup_and_die
  fi

  i=0
  while [ -a /tmp/mkboel_mnt$i ]; do
    i=`expr $i + 1`
  done
  TMP_MNT=/tmp/mkboel_mnt$i
  mkdir $TMP_MNT
  mount $outfile $TMP_MNT -o loop
  if [ $? -ne 0 ]; then
    echo "Error: unable to mount file."
    cleanup_and_die
  fi
  TMP_TARFILE=`mktemp /tmp/$p.XXXXXX` || exit 1
  curdir=$(pwd)
  cd $temp_dir
  tar -c * > $TMP_TARFILE
  cd $curdir
  cd $TMP_MNT
  tar x < $TMP_TARFILE
  rm $TMP_TARFILE
  if [ $? -ne 0 ]; then
    echo "Error: Couldn't remove file /tmp/$TMP_TARFILE."
    cleanup_and_die
  fi
  cd $curdir
  if [ $? -ne 0 ]; then
    echo "Error: extraction of files to ramdisk fs failed."
    cleanup_and_die
  fi
  umount $TMP_MNT
  if [ $? -ne 0 ]; then
    echo "Error: unable to unmount $TMP_MNT."
    cleanup_and_die
  fi
  rm -rf $temp_dir
  rmdir $TMP_MNT
  if [ $? -ne 0 ]; then
    echo "Warning: unable to remove $TMP_MNT."
  fi
else
  echo "Error: the filesystem $fs is not currently supported."
  cleanup_and_die
fi
