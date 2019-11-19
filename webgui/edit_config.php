<!DOCTYPE html>
<!--
#
# "SystemImager" 
# Configure /etc/systemimager/systemimager.json
#
#  Copyright (C) 2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#  vi: set filetype=html et ts=4:
#
# Icon set: Flatwoken Icons by alecive
#           http://www.iconarchive.com/show/flatwoken-icons-by-alecive.html
-->
<?php
include 'functions.php';

// 1st, read the cofiguration scheme. this loads all parameters names, default values and descriptions.
$config_scheme = si_ReadConfigScheme();

// By default: view mode (no save/cancel buttons (hidden). instead a edit button)
// View mode: all fields are read only (TODO: need to set readonly by default)
// Edit mode: fields are read write and Save (post) (cancel) button appear (edit button is hidden)
if ($_SERVER["REQUEST_METHOD"] == "POST") { // we're called as post
  // Read and validate fields.
  $config = new stdClass();

// We scan the configuration scheme and collect any POSTED field that match.
// All fields have a value (at least default value) as it is assigned when input field is created.
// Thus we don't have to check for default value.

  $config->cfg_error="";

  // Start collecting.
  foreach($config_scheme as $fieldset => $json) {
	$fieldset_tolower = strtolower($fieldset);
	// Create fieldset in config
	$config->{$fieldset_tolower} = new stdClass();;
	foreach($json as $param => $table_row) {
		$input_name=$fieldset."_".$param;
		$param_tolower = strtolower($param);
		if (array_key_exists($input_name, $_POST)) { // If parameter is found in POST
			$config->{$fieldset_tolower}->{$param_tolower} = $_POST[$input_name];
		} else { // Load default value (shouldn't occure)
			$config->{$fieldset_tolower}->{$param_tolower} = $table_row[0]; // Load defaults
		}
	}
  }
  if(!si_WriteConfig($config)) {
    $error=error_get_last();
    $config->cfg_error="ERROR (".$error['type']."):".$error['message'];
  }

} else { // we're called as "view"
  $config=si_ReadConfig();
}

// At this point, $config contains all fields with parameters and associated value.
?>

<html>
<head>
<title>SystemImager configuration editor.</title>
  <style type='text/css' media='screen'>@import url('css/screen.css');</style>
  <style type='text/css' media='screen'>@import url('css/sliders.css');</style>
  <!-- <style type='text/css' media='screen'>@import url('css/print.css');</style> -->
  <script src="functions.js"></script>
  <?php si_DefaultConfigToJava(); ?>
</head>
<body>
<form method="post" action="<?php echo htmlspecialchars($_SERVER["PHP_SELF"]);?>" id="si_prefs">
<div class="flex_column"> <!-- start of flex column -->


<div class="flex_header">
<table id="headerTable"> <!-- SystemImager header -->
  <tbody>
    <tr>
      <td><img src="css/SystemImagerBanner.png" alt="SystemImager"></td>
      <td id="clientData1">&nbsp;</td>
      <td id="clientData2">&nbsp;</td>
    </tr>
  </tbody>
</table>
<p>
<hr>
  <?php
if( isset($config->cfg_error) && $config->cfg_error !== "") {
  echo "<span class='pri_error' style='display: block; text-align: center; width: 100%'>".$config->cfg_error."</span>\n";
}
?>
</div> <!-- end flex_header -->

<!-- SystemImager content -->
<div id="parameters" class="flex_content">

<?php

foreach($config_scheme as $fieldset => $json) {
	echo "<fieldset><legend>&nbsp;".$fieldset."&nbsp;</legend>\n<table><tbody>\n";
	$fieldset_tolower = strtolower($fieldset);
	foreach($json as $param => $table_row) {
		$param_tolower = strtolower($param);
		if (! array_key_exists($param_tolower, $config->{$fieldset_tolower})) { // Use default value if not defined
			$config->{$fieldset_tolower}->{$param_tolower} = getDefaultValue($table_row); //Mainly used when new config_scheme.json isuse (upgrade)
		}
		echo "<tr><td>".$param."</td><td>".renderParamImput($table_row,$fieldset."_".$param,$config->{$fieldset_tolower}->{$param_tolower})."</td><td>".$table_row[2]."</td></tr>\n";
	}
	echo "</tbody></table></fieldset><br/>\n";
}

?>
</div> <!-- end flex content -->

<div class="flex_footer">
<hr/>

<script type="text/javascript">
function setEditMode(flag) {
  if (flag) {
    document.getElementById("save").style.visibility="visible";
    document.getElementById("defaults").style.visibility="visible";
    document.getElementById("edit").style.visibility="hidden";
    document.getElementById("reset").style.visibility="visible";
    document.getElementById("cancel").style.visibility="visible";
  } else {
    document.getElementById("save").style.visibility="hidden";
    document.getElementById("defaults").style.visibility="hidden";
    document.getElementById("edit").style.visibility="visible";
    document.getElementById("reset").style.visibility="hidden";
    document.getElementById("cancel").style.visibility="hidden";
  }
}
// Reset all form fields with default settings.
function setDefaultSettings() {
  for (const field of Object.keys(default_config)) {
    for (const key of Object.keys(default_config[field])) {
      input_field=document.getElementsByName(field+"_"+key);
      if(input_field[0]) {
        input_field[0].value=default_config[field][key];
      }
    }
  }
}

</script>

<table id="footerTable-edit" style="width: 95%"><tbody>
<tr>
  <td style="text-align: center">
    <button id="save" name="Save" type="submit" form="si_prefs" style="visibility: hidden">
      <img src="images/Alecive-Flatwoken-Apps-Dialog-Apply.svg" height="64" alt="Save"/>
    </button>
  </td>
  <td style="text-align: center">
    <button id="defaults" name="Defaults" type="button" style="visibility: hidden">
      <img src="images/Alecive-Flatwoken-Apps-Dialog-Logout.svg" height="64" alt="Defaults" onclick="setDefaultSettings()"/>
    </button>
  </td>
  <td style="text-align: center">
    <button id="edit" name="Edit" type="button">
      <img src="images/Alecive-Flatwoken-Apps-Settings.svg" height="64" alt="Edit" onclick="setEditMode(true)"/>
    </button>
  </td>
  <td style="text-align: center">
    <button id="reset" name="Reset" type="reset" form="si_prefs" style="visibility: hidden">
      <img src="images/Alecive-Flatwoken-Apps-Dialog-Refresh.svg" height="64" alt="Reset"/>
    </button>
  </td>
  <td style="text-align: center">
    <button id="cancel" name="Cancel" type="button" style="visibility: hidden">
      <img src="images/Alecive-Flatwoken-Apps-Dialog-Close.svg" height="64" alt="Cancel" onclick="setEditMode(false)"/>
    </button>
  </td>
  </tr>
</tbody></table>
</div> <!-- end flex_footer -->

</div> <!-- end flex column -->
</form>
</body>
</html>

