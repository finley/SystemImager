#!/bin/bash
#
# "SystemImager" 
#
#  Copyright (C) 1999-2017 Brian Elliott Finley <brian@thefinleys.com>
#                     2017 Olivier Lahaye
#
#  $Id$
#  vi: set filetype=sh et ts=4:
#
#
# This file hosts functions related to flamethrower deployment


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
    flamethrower_client
} 

################################################################################
#
# get_image_size <image_name>
#    => Returns the image size to be downloaded in MB (power of ten).
#  TODO
function get_image_size() {
	SIZE_BYTES=`LC_ALL=C rsync -av --numeric-ids "${IMAGESERVER}::${IMAGENAME}" | grep "total size" | sed -e "s/,//g" -e "s/total size is \([-0-9]*\).*/\1/"`
        # Report it in MB (power of ten)
	echo $((SIZE_BYTES / 1000))
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

    loginfo "Downloading image"
    # TODO

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
	loginfo "Moving image from ${STAGING_DIR} to /sysroot"

	# Check that there is enought space on destination.
	IMAGESIZE=`du -sk ${STAGING_DIR}`
	DEST_SPACE=`get_free_space /sysroot`
	[ $IMAGESIZE -gt $DEST_SPACE ] || logwarn "Not enought space on /sysroot ($IMAGESIZE > $DEST_SPACE)"

	# Continue anyway (we cannot know truly if we will fail. df / will ommit /usr if filesystems are different)
	logaction "rsync -aHS${VERBOSE_OPT} --exclude=lost+found/ --numeric-ids ${STAGING_DIR}/ /sysroot/"
	rsync -aHS${VERBOSE_OPT} --exclude=lost+found/ --numeric-ids ${STAGING_DIR}/ /sysroot/ > /dev/null 2>&1 || shellout "Move from staging dir to disk failed"
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
    # TODO
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

################################################################################
#
# INTERNAL functions below. will be prefixed with _
#
################################################################################

