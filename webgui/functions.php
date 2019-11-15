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
	global $config_scheme; // Use a global variable to avoid loading it multiple times.
	$si_config = new stdClass();
	$si_config->cfg_error="";

	foreach($config_scheme as $fieldset => $json) {
		// Create fieldset in config
		$si_config->{$fieldset} = new stdClass();
		foreach($json as $param => $table_row) {
			$si_config->{$fieldset}->{$param} = getDefaultValue($table_row); // Load defaults
		}
	}
	return($si_config);
}

function getDefaultValue($param_scheme) {
	switch($param_scheme[0]) {
		case "path":
			return $param_scheme[1];
		break;
		case "file":
			return $param_scheme[1];
		break;
		case "port":
			return $param_scheme[1];
		break;
		case "select":
			return $param_scheme[1][0]; // element #0 is the default value
		break;
		case "text":
			return $param_scheme[1];
		break;
		default:
			return "???";
	}
}

function renderParamImput($param_scheme, $name, $value) {
	switch($param_scheme[0]) {
		case "path":
			return "<input type=\"text\" name=\"".$name."\" size=\"50\" value=\"".$value."\">";
		break;
		case "file":
			return "<input type=\"text\" name=\"".$name."\" size=\"50\" value=\"".$value."\">";
		break;
		case "port":
			return "<input type=\"text\" name=\"".$name."\" size=\"50\" value=\"".$value."\">";
		break;
		case "select":
			$object = "<select name=\"".$name."\">\n";
			$default_val = array_shift($param_scheme[1]); // Unused here. We just remove default value.
			while($option = array_shift($param_scheme[1])) {
				$selected = "";
				if ( $option == $value ) {
					$selected = " selected";
				}
				$object .= "<option value=\"".$option."\"".$selected.">".$option."</option>\n";
			}
			$object .= "</select>\n";
			return "$object";
		break;
		case "text":
			return "<input type=\"text\" name=\"".$name."\" size=\"50\" value=\"".$value."\">";
		break;
		default: // Render a span (not editable). Usefull for not yet supported stuffs for example.
			return "<span name=\"".$name."\">".$value."</span>";
	}
}

function si_DefaultConfigToJava() {
	$si_config=si_GetDefautConfig();
        unset($si_config->cfg_error);
	$json_one_line=json_encode($si_config);
	echo <<<EOF
<script>
  var json_default_config_string='$json_one_line';
  var default_config=JSON.parse(json_default_config_string);
</script>
EOF;
}

function si_ReadConfigScheme() {
	$json_config = file_get_contents("config_scheme.json");
        if ($json_config !== false) {
		$si_config_scheme=json_decode($json_config);
		if ($si_config_scheme === null  && json_last_error() !== JSON_ERROR_NONE) {
			$si_config_scheme->cfg_error = array("STOP","Invalid configuration scheme file. Error:".json_last_error().".");
		}
	}
	return($si_config_scheme);
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
	$json_config=json_encode($si_config,JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
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
