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
#      This file hosts functions related to rsync deployment

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
    CMD="rsync -a ${IMAGESERVER}::${SCRIPTS}/ ${SCRIPTS_DIR}/"
    logdetail "$CMD"
    $CMD >/dev/null 2>&1 || shellout "Failed to retrieve ${SCRIPTS_DIR} directory..."
}

################################################################################
#
# get_image_size <image_name>
#    => Returns the image size to be downloaded in MB (power of ten).
#
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
    if [ "${TMPFS_STAGING}" = "y" ]; then
	[ -n "${NO_LISTING}" ] && loginfo "Quietly downloading image in staging dir: ${STAGING_DIR}"
        # Deposit image into tmpfs
        IMAGE_DEST=${STAGING_DIR}
        loginfo "TMPFS_STAGING=${TMPFS_STAGING} -- Staging in ${IMAGE_DEST}"
    else
	[ -n "${NO_LISTING}" ] && loginfo "Quietly installing image in /sysroot"
        IMAGE_DEST=/sysroot
    fi

    # Check that destination has enough space to save the image.
    DEST_SPACE=`get_free_space ${IMAGE_DEST}`
    [ $IMAGESIZE -lt $DEST_SPACE ] || logwarn "Not enought space on ${IMAGE_DEST} ($IMAGESIZE > $DEST_SPACE)"

    # Effectively download the image into ${IMAGE_DEST}
    loginfo "Downloading image for ${IMAGE_DEST}"
    logdetail "excluding the following directories or files:"
    logdetail "$(cat /lib/systemimager/files-to-exclude-from-image.txt)"
    logaction "rsync -aHS${VERBOSE_OPT} --exclude-from=/lib/systemimager/files-to-exclude-from-image.txt --numeric-ids ${IMAGESERVER}::${IMAGENAME}/ ${IMAGE_DEST}/"
    if [ $NO_LISTING ]; then
        rsync -aHS${VERBOSE_OPT} --exclude-from=/lib/systemimager/files-to-exclude-from-image.txt --numeric-ids ${IMAGESERVER}::${IMAGENAME}/ ${IMAGE_DEST}/ > /dev/null 2>&1 || shellout "Image download to [${IMAGE_DEST}] failed!"
    else
        rsync -aHS${VERBOSE_OPT} --exclude-from=/lib/systemimager/files-to-exclude-from-image.txt --numeric-ids ${IMAGESERVER}::${IMAGENAME}/ ${IMAGE_DEST}/ || shellout "Image download to [${IMAGE_DEST}] failed!"
    fi
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
	logaction "rsync -aHS${VERBOSE_OPT} --exclude-from=/lib/systemimager/files-to-exclude-from-image.txt --numeric-ids ${STAGING_DIR}/ /sysroot/"
	rsync -aHS${VERBOSE_OPT} --exclude-from=/lib/systemimager/files-to-exclude-from-image.txt --numeric-ids ${STAGING_DIR}/ /sysroot/ > /dev/null 2>&1 || shellout "Move from staging dir to disk failed"
    fi
    # Nothing to do if rsync was not using staging dir.
}

################################################################################
# install_overrides
#    => extract overrides in /sysroot
#
################################################################################
#
function install_overrides() {
    loginfo "Installing overrides"
    logaction "rsync -av --numeric-ids $IMAGESERVER::overrides/$OVERRIDE/ /sysroot/"
    rsync -av --numeric-ids $IMAGESERVER::overrides/$OVERRIDE/ /sysroot/ > /dev/console || logwarn "Override directory $OVERRIDE doesn't seem to exist, but that may be OK."
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

