#!/bin/bash
#
# "SystemImager" 
#
#  Copyright (C) Olivier Lahaye 2018 <olivier.lahaye@cea.fr>
#
#  $Id$
#  vi: set filetype=sh et ts=4:
#
#  Code mainly written by Olivier LAHAYE.
#
# This file is the docker protocol plugin for systemimager.

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
    loginfo "Initializing image transfer. Using DOCKER protocol"
    shellout "No yet implemented"
    # TODO: setup variables for certificates so docker won't fail.
    # they should be stored in /scripts/docker/certs/
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
#    => Returns the image size to be downloaded in bytes.
#
################################################################################
function get_image_size() {
	FULL_SIZE=`docker -h ${IMAGESERVER} ps -a --filter "name=${IMAGENAME}" --format "{{.Names}}|{{.Size}}"`
	SIZE1=${FULL_SIZE%%\(*}
	SIZE2=`echo ${FULL_SIZE##*virtual }|sed 's/)//'`
	# need to convert size to MB ($SIZE1 format is "<value> <unit>")
	IMAGE_SIZE=(( `convert2MB $SIZE1` + `convert $SIZE2` ))
	echo $IMAGE_SIZE
}

################################################################################
# download_image
#    => Download the image ${IMAGENAME}
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
	CMD_OUTPUT="> ${IMAGENAME}.tar"
    else
	[ -n "${NO_LISTING}" ] && loginfo "Quietly installing image in /sysroot"
        IMAGE_DEST=/sysroot
	CMD_OUTPUT="| tar xpf -"
    fi

    # Check that destination has enough space to save the image.
    DEST_SPACE=`get_free_space ${IMAGE_DEST}`
    [ $IMAGESIZE -lt $DEST_SPACE ] || logwarn "Not enought space on ${IMAGE_DEST} ($IMAGESIZE > $DEST_SPACE)"

    # Effectively download the image into ${IMAGE_DEST}
    CMD="cd ${IMAGE_DEST}; docker -H ${IMAGESERVER} export ${IMAGENAME} ${CMD_OUTPUT}"
    logaction "${CMD}"
    eval "${CMD}" || shellout "Failed to download image using DOCKER protocol"

    stop_report_task 101 # 101: status=finalizing...
}

################################################################################
# extract_image
#    => extract image in destination
#    => example: extract_image
#
################################################################################
#
function extract_image() {
	loginfo "Extracting image to /sysroot"
	send_monitor_msg "status=107:speed=0" # 107=extracting
	update_client_status 107 0
	if [ "${TMPFS_STAGING}" = "y" ]; then
		cd /sysroot
		logaction "tar xpf ${STAGING_DIR}/${IMAGENAME}.tar"
		tar xpf ${STAGING_DIR}/${IMAGENAME}.tar || shellout "Failed to extract image to /sysroot"
		rm -f ${STAGING_DIR}/${IMAGENAME}.tar
	fi
}

################################################################################
# install_overrides()
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
	loginfo "Terminating transfer processes."
}

################################################################################
#
# INTERNAL functions below. will be prefixed with _
#
################################################################################

