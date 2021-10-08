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
#      This file is for NFS deployment protocol support.

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
    shellout "No yet implemented"
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

	echo 123456789
}

################################################################################
# download_image
#    => Download the image ${IMAGENAME}
#    => example: download_image
#
################################################################################
#
function download_image() {
	loginfo "Downloading image"
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
	#send_monitor_msg "status=107:speed=0" # 107=extracting
	update_client_status 107 0 # 107=extracting
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

