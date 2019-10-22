<!--
#
# "SystemImager" 
# Common php functions.
#
#  Copyright (C) 2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#  vi: set filetype=php et ts=4:
#
-->
<?php

function si_SendEvent($event,$retry,$id,$data) {
        echo 'retry: $retry' . PHP_EOL;
        echo 'event: ' . $event . PHP_EOL;
        echo 'id: ' . $id . PHP_EOL;
        echo 'data: ' . $data . PHP_EOL;
        echo PHP_EOL;
        ob_flush();
        flush();
}

function si_GetDefautConfig() {
	$si_config = new stdClass();
	$si_config->cfg_error="";
	$si_config->images_dir="/var/lib/systemimager/images";
	$si_config->overrides_dir="/var/lib/systemimager/overrides";
	$si_config->scripts_dir="/var/lib/systemimager/scripts";
	$si_config->clients_db_dir="/var/lib/systemimager/clients";
	$si_config->tarballs_dir="/var/lib/systemimager/tarballs";
	$si_config->torrents_dir="/var/lib/systemimager/torrents";
	$si_config->pxe_boot_files="/usr/share/systemimager/boot";
	$si_config->rsyncd_conf="/etc/systemimager/rsyncd.conf";
	$si_config->rsync_stub_dir="/etc/systemimager/rsync_stubs";
	$si_config->tftp_dir="/var/lib/tftpboot";
	$si_config->pxe_boot_mode="net";
	return($si_config);
}

function si_DefaultConfigToJava() {
	$si_config=si_GetDefautConfig();
	$json_one_line=json_encode($si_config);
	echo <<<EOF
<script>
  var json_default_config_string='$json_one_line';
  var default_config=JSON.parse(json_default_config_string);
  console.log(default_config);
</script>
EOF;
}

function si_ReadConfig() {
	$json_config = file_get_contents("/etc/systemimager/systemimager.json");
        if ($json_config !== false) {
		$si_config=json_decode($json_config);
		$si_config->cfg_error=""; // Create internal use filed.
		if ($si_config === null  && json_last_error() !== JSON_ERROR_NONE) {
			$si_config=si_GetDefautConfig();
			$si_config->cfg_error="Invalid configuration file. Error:".json_last_error().". Using defaults.";
		}
	}
	return($si_config);
}

function si_WriteConfig($si_config) {
	unset($si_config->cfg_error); // Remove internal use field
	$json_config=json_encode($si_config,JSON_PRETTY_PRINT);
	return(file_put_contents("/etc/systemimager/systemimager.json",$json_config));
}

/**
 * Checks if a folder exist and return canonicalized absolute pathname (long version)
 * @param string $folder the path being checked.
 * @return mixed returns the canonicalized absolute pathname on success otherwise FALSE is returned
 * Code from https://stackoverflow.com/questions/5425891/how-do-i-check-if-a-directory-exists-is-dir-file-exists-or-both
 */
function folder_exist($folder)
{
    // Get canonicalized absolute pathname
    $path = realpath($folder);

    // If it exist, check if it's a directory
    if($path !== false AND is_dir($path)) {
        // Return canonicalized absolute pathname
        return $path;
    }

    // Path/folder does not exist
    return false;
}

?>
