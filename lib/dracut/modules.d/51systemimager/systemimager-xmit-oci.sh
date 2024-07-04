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
#      This file is the OCI protocol plugin for systemimager.
#      It supports retrieving image from a registry hub for these formats:
#      - Docker V1
#      - Docker V2
#      - OCI V1
#      It also supports images with multiple architectures

################################################################################
#
# get_token
# - authenticate and retreive the JWT token
#
get_token() {
    local repo=$1
    local scope="repository:$repo:pull"
    if test -n "$DOCKER_USER$DOCKER_PASS"
    then
        user_ident_opt="-u \"$DOCKER_USER:$DOCKER_PASS\""
    fi
    local auth_resp=$(curl -s $user_ident_opt "https://auth.docker.io/token?service=registry.docker.io&scope=$scope")
    echo $(echo $auth_resp | jq -r .token)
}

################################################################################
#
# init_transfer
# - download transfer config (example: download the .torrent files)
# - detect or get staging dir
# - create the staging dir if needed
# - get image size to download
# - check if fits in destination (staging dir or system)
#
function init_transfer() {
    loginfo "Initializing image transfer. Using DOCKER protocol"
    shellout "No yet implemented"
    # TODO: setup variables for certificates so docker won't fail.
    # they should be stored in /scripts/docker/certs/
	# TODO: make sur parameters are retreived (registry, repo (imagename) tag (default to latest)
	TARGET_ARCH="$(arch)"
	TARGET_OS="linux"
	# Obtenir le token JWT
	TOKEN=$(get_token $REPO)
	# Obtenir le manifeste de la liste des manifestes (manifeste index)
	MANIFEST_INDEX=$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.index.v1+json" "https://$REGISTRY/v2/$REPO/manifests/$IMAGEVERSION")

	# Détecter le type de média du manifeste index
	MEDIA_TYPE_INDEX=$(echo $MANIFEST_INDEX | jq -r '.mediaType')

	# Sélectionner le bon manifeste pour l'architecture et l'OS souhaités
	if [[ "$MEDIA_TYPE_INDEX" == "application/vnd.docker.distribution.manifest.list.v2+json" || "$MEDIA_TYPE_INDEX" == "application/vnd.oci.image.index.v1+json" ]]; then
	    MANIFEST_DIGEST=$(echo $MANIFEST_INDEX | jq -r \
	        --arg arch "$TARGET_ARCH" --arg os "$TARGET_OS" \
	        '.manifests[] | select(.platform.architecture == $arch and .platform.os == $os) | .digest')

	    if [ -z "$MANIFEST_DIGEST" ]; then
	        shellout "No manifest found for architecture $TARGET_ARCH and OS $TARGET_OS"
	    fi

	    MANIFEST=$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.v1+json,application/vnd.oci.image.manifest.v1+json" \
	    "https://$REGISTRY/v2/$REPO/manifests/$MANIFEST_DIGEST")
	else
	    MANIFEST=$MANIFEST_INDEX
	fi

	# Détecter le type de média du manifeste
	MEDIA_TYPE=$(echo $MANIFEST | jq -r '.mediaType')
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
# get_image_size
#    => Returns the image size to be downloaded in bytes.
#
################################################################################
function get_image_size() {
    if [[ "$MEDIA_TYPE" == "application/vnd.docker.distribution.manifest.v2+json" || "$MEDIA_TYPE" == "application/vnd.oci.image.manifest.v1+json" ]]; then
        local total_size=$(echo $MANIFEST | jq '[.layers[].size] | add')
        echo $total_size
    elif [[ "$MEDIA_TYPE" == "application/vnd.docker.distribution.manifest.v1+json" ]]; then
        local total_size=$(echo $MANIFEST | jq '[.fsLayers[].blobSum | ltrimstr("sha256:")] | add')
        echo $total_size
    else
        logwarn "Can't comput image size. Unsupported manifest type"
        echo 0
    fi
}

################################################################################
# process_layer <layer> <token>
#    => Download the image layer and extract it if no staging dir
#    => example: process_layer <layer> <token>
#
################################################################################
#
function process_layer() {
    local layer=$1
    local token=$2

    # Enlever le préfixe 'sha256:'
    local layer_id=$(echo $layer | cut -d ':' -f 2)

	# IMAGESERVER is the registry server name
	# IMAGENAME is the repo (e.g.: arv64v8/almalinux
	if [ "${TMPFS_STAGING}" = "y" ]; then
		# Download the layer to disk
		loginfo "Downloading layer ${layer} to staging dir."
		logaction "curl -s -L -H [...] -o ${TMPFS_STAGING}/${layer}.tar.gz"
	    curl -s -L -H "Authorization: Bearer $token" \
		    "https://$IMAGESERVER/v2/$IMAGENAME/blobs/$layer" -o "${TMPFS_STAGING}/${layer}.tar.gz"
		[ $? -eq 0 ] || shellout "Failed to download layer '$layer'"
		echo "${layer}.tar.gz" >> "${TMPFS_STAGING}/layers.txt" # keep track of layers order
	else
		# Download the laker and extract if on the fly to /sysroot
		loginfo "Downloading layer ${layer} and extracting it to disk."
		logaction "curl -s -L -H [...] | tar -xzf - -C /sysroot"
	    curl -s -L -H "Authorization: Bearer $token" \
		    "https://$IMAGESERVER/v2/$IMAGENAME/blobs/$layer" | tar -xzf - -C /sysroot
		[ $? -eq 0 ] || shellout "Failed to download or extract layer '$layer'"
	fi
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
        loginfo "TMPFS_STAGING=${TMPFS_STAGING} -- Staging in ${IMAGE_DEST}"
    else
		[ -n "${NO_LISTING}" ] && loginfo "Quietly installing image in /sysroot"
    fi

    # Check that destination has enough space to save the image.
    DEST_SPACE=`get_free_space ${IMAGE_DEST}`
    [ $IMAGESIZE -lt $DEST_SPACE ] || logwarn "Not enought space on ${IMAGE_DEST} ($IMAGESIZE > $DEST_SPACE)"

    # Effectively download the image into ${IMAGE_DEST}
	LAYERS=$(echo $MANIFEST | jq -r '.layers[].digest')
	for layer in $LAYERS; do
		process_layer $layer $TOKEN
	done

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
	#send_monitor_msg "status=107:speed=0" # 107=extracting
	update_client_status 107 0 # 107=extracting
	if [ "${TMPFS_STAGING}" = "y" ]; then
		cd /sysroot
		for layer_tarball in $(cat "${TMPFS_STAGING}/layers.txt")
		do
			logaction "tar xpf \"${STAGING_DIR}/${layer_tarball}\""
			tar xpf "${STAGING_DIR}/${layer_tarball}" || shellout "Failed to extract layer $layer_tarball to /sysroot"
			rm -f "${STAGING_DIR}/${layer_tarball}"
		done
		rm -f "${TMPFS_STAGING}/layers.txt"
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

