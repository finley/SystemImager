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
	# Initial torrent client configuration
	mkdir -p ${STAGING_DIR}/transmission-cli
	cat > ${STAGING_DIR}/transmission-cli/settings.json <<EOF
{
	"dht-enabled": true,
	"pex-enabled": true,
	"utp-enabled": true,
	"idle-seeding-limit": 30,
	"idle-seeding-limit-enabled": false
}
EOF
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
	#bittorrent_upload_min=${BITTORRENT_UPLOAD_MIN:-50}

	# Start downloading.
	#/bin/bittorrent-console --no_upnp --no_start_trackerless_client --max_upload_rate 0 --display_interval 1 --rerequest_interval 1 --bind ${IPADDR} --save_in ${destination} ${torrent} > $bittorrent_log &
	/usr/bin/transmission-cli -U -D -g ${STAGING_DIR}/transmission-cli -w ${destination} ${torrent} >& ${bittorrent_log} &
	pid=$!
	if [ ! -d /proc/$pid ]; then
		logmsg "error: couldn't run transmission-cli (torrent client)!"
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
			status=`tr '\r' '\n' < ${bittorrent_log} | grep "Progress:" | tail -n 1 | cut -d',' -f1 | cut -d' ' -f2`| tr -d '%'
			[ ! -z "$status" ] && break
	    done
	    logmsg "percent done: $status %"
	    if [ "$status" = "100.0" ]; then
			logmsg "Download completed"
		# Sleep until no peer uploads
			if [ "$bittorrent_seed_wait" = "y" ]; then
				logmsg "Waiting for peers to complete download"
		    	while :; do
		    		sleep $bittorrent_polling_time
					upload_peers_count=`tr '\r' '\n' </tmp/transmission.log| grep "Seeding, uploading to" | tail -n 1 | cut -d' ' -f4`
					[ ${upload_peers_count:=0} -eq 0 ] && break
		    	done
		    	logmsg "Upload peers: $upload_peers_count"
		    	[ ${upload_peers_count:=0} -eq 0 ] && break
			fi
			logmsg "No peers to seed. Exitting torrent client."
			break
	    fi
	    sleep $bittorrent_polling_time
	done

	unset bittorrent_log
	unset upload_peers_count
	unset bittorrent_polling_time
	unset bittorrent_seed_wait
	#unset bittorrent_upload_min
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
	update_client_status 107 0 # 107=extracting
	cd /sysroot
	# TODO: handle multiple layers (a torrent with multiple layers)
	IMAGE_TARBALL=`/usr/bin/transmission-show ${IMAGENAME}.torrent | sed -n '/^FILES$/,$p' | tail -n +2 | sed '/^$/d;s/^  //;s/ (.*$//'`
	# BUG: if torrent contains more than a single archive, IMAGE_TARBALL will contain all of them leading to error
	case ${IMAGE_TARBALL} in
		*.tar)
			tar xpvf ${IMAGE_TARBALL}
			;;
		*.tar.gz)
			tar xpvzf ${IMAGE_TARBALL}
			;;
		*.tar.bz2)
			tar xpvjf ${IMAGE_TARBALL}
			;;
		*.tar.xz)
			tar xpvJf ${IMAGE_TARBALL}
			;;
		*.zip)
			unzip ${IMAGE_TARBALL}
			;;
		*)
			logerror "Unknown archive type"
			;;
	esac
	loginfo "Cleaning up image tarball"
	rm -f ${IMAGE_TARBALL}

}

################################################################################
# install_overrides
#    => extract overrides in /sysroot
#
################################################################################
#
function install_overrides() {
	loginfo "Installing overrides"
}

################################################################################
# terminate_transfer()
#    => stops any remaining processes related to transfert
#       (ssh tunnels, torrent seeding processes, ...)
#
################################################################################
function terminate_transfer() {
	# TODO: déplacer l'attente du seeding ici (ça permet d'extraire plus vite)
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
    btclient="transmission-cli"

    logmsg "killing BitTorrent client..."
    killall -15 $btclient >/dev/null 2>&1

    # Forced kill after 5 secs.
    sleep 5
    killall -9 $btclient >/dev/null 2>&1

    # Remove bittorrent logs.
    rm -rf /tmp/bittorrent*.log
    unset btclient
}

