#!/bin/bash
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
#    Copyright (C) 2017-2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#    Purpose:
#      This file hosts functions related to torrent deployment

################################################################################
#
# init_transfer
# download .torrent files in /torrents
# detect or get staging dir
# create the staging dir
# get image size to download
# check it fits
#
function init_transfer() {
    loginfo "Initializing image transfer. Using BITTORRENT protocol"
    _get_torrents_directory # Retreive all .torrent files
    # detect or get staging dir
    [ -z "${STAGING_DIR}" ] && STAGING_DIR=/tmp/tmpfs_staging
    # create the staging dir if needed
    mkdir -p ${STAGING_DIR} || shellout "Failed to create ${STAGING_DIR}"
    # get image size to download
    IMAGESIZE=`get_image_size`
    write_variables # keep track of $STAGING_DIR and $IMAGESIZE variable accross dracut scripts logic
    loginfo "Image size: $IMAGESIZE"
    # check it fits in destination (staging dir or system)
}

################################################################################
#
# Usage: get_scripts_directory
#
function get_scripts_directory() {
    loginfo "Retrieving ${SCRIPTS_DIR} directory..."
    CMD="rsync -a ${IMAGESERVER}::${SCRIPTS}/ ${SCRIPTS_DIR}/"
    logdetail "$CMD"
    $CMD >/dev/null 2>&1 || shellout "Failed to retrieve ${SCRIPTS_DIR} directory..."
}

################################################################################
#
# get_image_size
#    => Returns the image size to be downloaded using torrent protocol.
#
################################################################################
#
function get_image_size() {
	echo $((`grep -aEo ':lengthi[0-9]+e' ${TORRENTS_DIR}/${IMAGENAME}.torrent |grep -Eo '[0-9]+'` / 1024))
}

#################################################################################
# download_image <image_name> <dest_dir>
#    => Download the image into destination directory
#    => example: download_image oscarimage_sda /tmp/staging/
#
################################################################################
download_image() {
	loginfo "Downloading image"
        torrent=${TORRENTS_DIR}/$1.torrent
        destination=$2

        # Bittorrent log file
        bittorrent_log=/tmp/bittorrent-`basename ${torrent}`.log
        # Time to poll bittorrent events
        bittorrent_polling_time=${BITTORRENT_POLLING_TIME:-5}
        # Wait after the download is finished to seed the other peers
        bittorrent_seed_wait=${BITTORRENT_SEED_WAIT:-n}
        # Minimum upload rate threshold (in KB/s), if lesser stop seeding
        bittorrent_upload_min=${BITTORRENT_UPLOAD_MIN:-50}

        # Start downloading.
        /bin/bittorrent-console --no_upnp --no_start_trackerless_client --max_upload_rate 0 --display_interval 1 --rerequest_interval 1 --bind ${IPADDR} --save_in ${destination} ${torrent} > $bittorrent_log &
        pid=$!
        if [ ! -d /proc/$pid ]; then
            logmsg "error: couldn't run bittorrent-console!"
            shellout
        fi
        unset pid

        # Wait for BitTorrent log to appear.
        while [ ! -e $bittorrent_log ]; do
            sleep 1
        done
         # Checking download...
        while :; do
            while :; do
                status=`grep 'percent done:' $bittorrent_log | sed -ne '$p' | sed 's/percent done: *//' | sed -ne '/^[0-9]*\.[0-9]*$/p'`
                [ ! -z "$status" ] && break
            done
            logmsg "percent done: $status %"
            if [ "$status" = "100.0" ]; then
                # Sleep until upload rate reaches the minimum threshold
                while [ "$bittorrent_seed_wait" = "y" ]; do
                    sleep $bittorrent_polling_time
                    while :; do
                        upload_rate=`grep 'upload rate:' $bittorrent_log | sed -ne '$p' | sed 's/upload rate: *\([0-9]*\)\.[0-9]* .*$/\1/' | sed -ne '/^\([0-9]*\)$/p'`
                        [ ! -z $upload_rate ] && break
                    done
                    logmsg "upload rate: $upload_rate KB/s"
                    [ $upload_rate -lt $bittorrent_upload_min ] && break
                done
                logmsg "Download completed"
                unset bittorrent_log upload_rate counter
                break
            fi
            sleep $bittorrent_polling_time
        done

        unset bittorrent_polling_time
        unset bittorrent_seed_wait
        unset bittorrent_upload_min
        unset torrent
        unset destination
}

#################################################################################
# extract_image <image_path> <dest_dir>
#    => extract image in destination
#    => example: extract_image /tmp/staging/oscar_image_sda.tar.gz /sysroot
#
################################################################################
#
function extract_image() {
	loginfo "Extracting image to /sysroot"
	#send_monitor_msg "status=107:speed=0" # 107=extracting
	update_client_status 107 0 # 107=extracting
}

################################################################################
# install_overrides
#    => extract overrides in /sysroot
#
################################################################################
#
function install_overrides() {
	loginfo "Installing overrides"
	loginfo "Installing overrides"
}

################################################################################
# terminate_transfer()
#    => stops any remaining processes related to transfert
#       (ssh tunnels, torrent seeding processes, ...)
#
################################################################################
function terminate_transfer() {
	loginfo "Terminating transfer processes."
}

###############################################################################
#
# INTERNAL functions below. will be prefixed with _
#
################################################################################


################################################################################
#
# Usage: _get_torrents_directory
# Dowload image .torrent files from the server into ${TORRENTS_DIR}
#
_get_torrents_directory() {
    loginfo "Retrieving ${TORRENTS_DIR} directory..."

    if [ -n "$FLAMETHROWER_DIRECTORY_PORTBASE" ]; then
        #
        # We're using Multicast, so we should already have a directory 
        # full of scripts.  Break out here, so that we don't try to pull
        # the scripts dir again (that would be redundant).
        #
        MODULE_NAME="autoinstall_torrents"
        DIR="${TORRENTS_DIR}"
        RETRY=7
        flamethrower_client
    else
        mkdir -p ${TORRENTS_DIR}
        CMD="rsync -a ${IMAGESERVER}::${TORRENTS}/ ${TORRENTS_DIR}/"
        logdetail "$CMD"
        $CMD || shellout "Failed to retreive ${TORRENTS_DIR} directory..."
    fi
}

################################################################################
#
#   Autodetect a staging directory for the bittorrent tarball
#
#   Usage: bittorrent_autodetect_staging_dir torrent
#
bittorrent_autodetect_staging_dir() {
    torrent=${TORRENTS_DIR}/$1.torrent
    if [ ! -f $torrent ]; then
        logmsg "warning: torrent file $torrent does not exist!"
        return
    fi

    # List of preferred staging directory (/tmp = ramdisk staging)
    preferred_dirs="/tmp /sysroot/tmp `df 2>/dev/null | sed '1d' | sed 's/[[:space:]]\+/ /g' | cut -d' ' -f6`"

    # Use a breathing room of 100MiB (this should be enough for a lot of cases)
    breathing_room=102400

    # Evaluate torrent size
    # torrent_size=$((`/bin/torrentinfo-console $torrent | sed -ne 's/^file size\.*: \([0-9]\+\).*$/\1/p'` / 1024 + $breathing_room))
    torrent_size=$((`_get_torrent_filesize $torrent` + $breathing_room))

    # Find a directory to host the image tarball
    for dir in $preferred_dirs; do
        [ ! -d $dir ] && continue;
        dir_space=`df $dir 2>/dev/null | sed '1d' | sed 's/[[:space:]]\+/ /g' | cut -d' ' -f4 | sed -ne '$p'`
        [ -z $dir_space ] && continue
        [ $torrent_size -lt $dir_space ] && echo $dir && return
    done
}

################################################################################
#
#   Stop bittorrent client.
#
#   Usage: bittorrent_stop
#
bittorrent_stop() {
    # Try to kill all the BitTorrent processes
    btclient="bittorrent-console"

    logmsg "killing BitTorrent client..."
    killall -15 $btclient >/dev/null 2>&1

    # Forced kill after 5 secs.
    sleep 5
    killall -9 $btclient >/dev/null 2>&1

    # Remove bittorrent logs.
    rm -rf /tmp/bittorrent*.log
    unset btclient
}

