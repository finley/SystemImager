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
#      This file hosts functions related to flamethrower deployment


################################################################################
#
# init_transfer
# - download transfer config (example: download the .torrent files)
# - detect or get staging dir
# - create the staging dir if needed
# - get image size to download
# - check it fits in destination (staging dir or system)
#
function init_transfer() {
    loginfo "Initializing image transfer. Using RSYNC protocol"
    [ -z "${STAGING_DIR}" ] && STAGING_DIR=/tmp/tmpfs_staging
    mkdir -p ${STAGING_DIR} || shellout "Failed to create ${STAGING_DIR}"
    IMAGESIZE=`get_image_size`
    write_variables # keep track of $STAGING_DIR and $IMAGESIZE variable accross dracut scripts logic
    loginfo "Image size: $IMAGESIZE"
}

################################################################################
#
# Usage: get_scripts_directory
#
function get_scripts_directory() {
    loginfo "Retrieving ${SCRIPTS_DIR} directory..."
    #
    # We're using Multicast, so we should already have a directory 
    # full of scripts.  Break out here, so that we don't try to pull
    # the scripts dir again (that would be redundant).
    #
    MODULE_NAME="autoinstall_scripts"
    DIR="${SCRIPTS_DIR}"
    RETRY=7
    loginfo "flamethrower client started for scripts download to ${SCRIPTS_DIR}"
    flamethrower_client
} 

################################################################################
#
# get_image_size <image_name>
#    => Returns the image size to be downloaded in MB (power of ten).
function get_image_size() {
	SIZE_BYTES=`LC_ALL=C rsync -av --numeric-ids "${IMAGESERVER}::${IMAGENAME}" | grep "total size" | sed -e "s/,//g" -e "s/total size is \([-0-9]*\).*/\1/"`
        # Report it in MB (power of ten)
	echo $((SIZE_BYTES / 1000))
	# BUG: 1000 or 1024?
	# BUG/TODO: flamethrower requires rsync to get image size?
	# => Can't we get an ${IMAGENAME}.size using udp-reciever? (would avoid the need to start rsyncd on server)
}

################################################################################
# download_image
#    => Download the image ${IMAGENAME} into destination directory
#    => example: download_image
#
################################################################################
#
function download_image() {
    # Start si_monitor progress and status report.
    loginfo "Starting monitor progress report task..."
    start_report_task

    MODULE_NAME="${IMAGENAME}"
    RETRY=7
    loginfo "Downloading image"
    if [ "${TMPFS_STAGING}" = "y" ]; then
        DIR="${STAGING_DIR}"
	FLAMETHROWER_TARPIPE=""
        loginfo "flamethrower client started for image ${IMAGENAME} download and extract to /sysroot"
    else
	DIR="/sysroot"
        FLAMETHROWER_TARPIPE="y"
        loginfo "flamethrower client started for image ${IMAGENAME} download to staging dir ${STAGING_DIR}"
    fi
    flamethrower_client

    stop_report_task 101 # 101: status=finalizing...
}

#################################################################################
# extract_image
#    => extract image in /sysroot
#    => example: extract_image /sysroot
#
################################################################################
#
function extract_image() {
    loginfo "Extracting image to /sysroot"
    #send_monitor_msg "status=107:speed=0" # 107=extracting
    update_client_status 107 0 # 107=extracting
    if [ "${TMPFS_STAGING}" = "y" ]; then
        # Need to move the image into /sysroot from staging dir.
	loginfo "Extracting image from ${STAGING_DIR}/multicast.tar to /sysroot"

	# Check that there is enought space on destination.
	IMAGESIZE=`du -sk ${STAGING_DIR}/multicast.tar`
	DEST_SPACE=`get_free_space /sysroot`
	[ $IMAGESIZE -gt $DEST_SPACE ] || logwarn "Not enought space on /sysroot ($IMAGESIZE > $DEST_SPACE)"

	[ -z "${NO_LISTING}" ] && VERBOSE_OPT=v
	# Continue anyway (we cannot know truly if we will fail. df / will ommit /usr if filesystems are different)
	logaction "tar x${VERBOSE_OPT}f ${STAGING_DIR}/multicast.tar -C /sysroot"
	tar x${VERBOSE_OPT}f ${STAGING_DIR}/multicast.tar -C /sysroot || shellout "Image extraction failed failed"
    fi
    # Nothing to do if flamethrower was not using staging dir.
}

################################################################################
# install_overrides
#    => extract overrides in /sysroot
#
################################################################################
#
function install_overrides() {
    loginfo "Installing overrides"

    MODULE_NAME="override_${OVERRIDE}"
    DIR="/sysroot"
    RETRY=7
    FLAMETHROWER_TARPIPE=y
    loginfo "Downloading override $OVERRIDE/ to /sysroot"
    flamethrower_client || logwarn "Override directory $OVERRIDE doesn't seem to exist, but that may be OK."
    # TODO: move OVERRIDE to /sysroot
}

################################################################################
# terminate_transfer()
#    => stops any remaining processes related to transfert
#       (ssh tunnels, torrent seeding processes, ...)
#
################################################################################
function terminate_transfer() {
	loginfo "Terminating transfer processes."
	# Nothing to do. flamethrower_client will terminate once download is done.
}

################################################################################
#
# INTERNAL functions below. will be prefixed with _
#
################################################################################

