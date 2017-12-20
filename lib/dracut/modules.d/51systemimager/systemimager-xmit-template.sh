#!/bin/sh
#
# "SystemImager" 
#
#  Copyright (C) 1999-2017 Brian Elliott Finley <brian@thefinleys.com>
#
#  $Id$
#  vi: set filetype=sh et ts=4:
#
#  Code mainly written by Olivier LAHAYE.
#
# This file is a template file for new protocol support.
# The resulting file should be named systemimager-xmit-<protocolname>.sh

################################################################################
#
# init_transfer
# - download transfer config (example: download the .torrent files)
# - detect or get staging dir
# - create the staging dir if needed
# - get image size to download
# - check it fits in destination (staging dir or system)
#
################################################################################
#
function init_transfer() {
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
}

#################################################################################
# extract_image
#    => extract image in destination
#    => example: extract_image
#
################################################################################
#
function extract_image() {
}

#################################################################################
# install_overrides()
#    => extract overrides in /sysroot
#
################################################################################
#
function install_overrides() {
}

################################################################################
#
# INTERNAL functions below. will be prefixed with _
#
################################################################################

