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

// By default: view mode (no save/cancel buttons (hidden). instead a edit button)
// View mode: all fields are read only
// Edit mode: fields are read write and Save (post) (cancel) button appear (edit button is hidden)
if ($_SERVER["REQUEST_METHOD"] == "POST") { // we're called as post
  // Read and validate fields.
  $config = new stdClass();
  $config->cfg_error="";
  $config->images_dir=$_POST["images_dir"]; // TODO: Check directory existance.
  $config->overrides_dir=$_POST["overrides_dir"];
  $config->scripts_dir=$_POST["scripts_dir"];
  $config->clients_db_dir=$_POST["clients_db_dir"];
  $config->tarballs_dir=$_POST["tarballs_dir"];
  $config->torrents_dir=$_POST["torrents_dir"];
  $config->pxe_boot_files=$_POST["pxe_boot_files"];
  $config->rsyncd_conf=$_POST["rsyncd_conf"];
  $config->rsync_stub_dir=$_POST["rsync_stub_dir"];
  $config->tftp_dir=$_POST["tftp_dir"];
  $config->pxe_boot_mode=$_POST["pxe_boot_mode"];
  if(!si_WriteConfig($config)) {
    $error=error_get_last();
    $config->cfg_error="ERROR (".$error['type']."):".$error['message'];
  }

} else { // we're called as "view"
  $config=si_ReadConfig();
}

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
      <td><img src="css/SystemImagerBanner.png" alt="SystemImagezr"></td>
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
<fieldset><legend>Imager data paths</legend>
<table><tbody>
<tr><td>images_dir</td><td><input type="text" name="images_dir" size="50" value="<?php echo $config->images_dir;?>"></td><td>Place where images are stored.</td></tr>
<tr><td>overrides_dir</td><td><input type="text" name="overrides_dir" size="50" value="<?php echo $config->overrides_dir;?>"></td><td>Place where override files are stored. They are copied to client filesystem overwriting existing files.</td></tr>
<tr><td>scripts_dir</td><td><input type="text" name="scripts_dir" size="50" value="<?php echo $config->scripts_dir;?>"></td><td>Place holding imaging scripts and various client configurations:<br>
<ul>
<li>pre-install/ all optional pre-install scripts</li>
<li>main-install/ The optional main install script</li>
<li>post-install/ all optional post-install scripts</li>
<li>configs/ clients configuration files</li>
<li>disks-layouts/ clients disks layout files</li>
<li>network-configs/ clients optional network configuration files</li>
<li>cluster.txt The cluster/client groups definition file (see si_clusterconfig)</li>
</ul>
</td></tr>
<tr><td>tarballs_dir</td><td><input type="text" name="tarballs_dir" size="50" value="<?php echo $config->tarballs_dir;?>"></td><td>All images saved as tarball (mainly torrent content)</td></tr>
<tr><td>torrents_dir</td><td><input type="text" name="torrents_dir" size="50" value="<?php echo $config->torrents_dir;?>"></td><td>Place for .torrent files</td></tr>
<tr><td>clients_db_dir</td><td><input type="text" name="clients_db_dir" size="50" value="<?php echo $config->clients_db_dir;?>"></td><td>Where to save imaged clients informations and installation logs.</td></tr>
</tbody></table>
</fieldset>
<br/>

<fieldset><legend>Imager binaries</legend>
<table><tbody>
<tr><td>pxe_boot_files</td><td><input type="text" name="pxe_boot_files" size="50" value="<?php echo $config->pxe_boot_files;?>"></td><td>Where to find initrd.img and kernel files (the imager itself)</td></tr>
</tbody></table>
</fieldset>
<br/>

<fieldset><legend>PXE configuration</legend>
<table><tbody>
<tr><td>tftp_dir</td><td><input type="text" name="tftp_dir" size="50" value="<?php echo $config->tftp_dir;?>"></td><td>The tftp root directory</td></tr>
<tr><td>pxe_boot_mode</td><td><select name="pxe_boot_mode">
<option value="net" <?php if($config->pxe_boot_mode === "net") echo "selected"; ?>>Network boot</option>
<option value="local" <?php if($config->pxe_boot_mode === "local") echo "selected"; ?>>Local boot</option>
</select></td><td>PXE boot mode is a setting that affects systemimager-server-netbootmond. If set to LOCAL, then after successful completion of an install, a client's net boot configuration is modified to ensure future boots will happen from the client's local disk. NET_BOOT_DEFAULT can be set to local or net.  Be sure to restart systemimager-server-netbootmond after changing this setting (/etc/init.d/systemimager-server-netbootmond restart).</td></tr>
</tbody></table>
</fieldset>
<br/>

<fieldset><legend>RSYNC protocol configuration</legend>
<table><tbody>
<tr><td>rsyncd_conf</td><td><input type="text" name="rsyncd_conf" size="50" value="<?php echo $config->rsyncd_conf;?>"></td><td></td></tr>
<tr><td>rsync_stub_dir</td><td><input type="text" name="rsync_stub_dir" size="50" value="<?php echo $config->rsync_stub_dir;?>"></td><td></td></tr>
</tbody></table>
</fieldset>
<br/>

<fieldset><legend>SSH protocol configuration</legend>
<table><tbody>
<tr><td></td><td></td><td></td></tr>
</tbody></table>
</fieldset>
<br/>

<fieldset><legend>flamethrower protocol configuration</legend>
<table><tbody>
<tr><td></td><td></td><td></td></tr>
</tbody></table>
</fieldset>
<br/>

<fieldset><legend>NFS protocol configuration</legend>
<table><tbody>
<tr><td></td><td></td><td></td></tr>
</tbody></table>
</fieldset>
<br/>

<fieldset><legend>Docker protocol configuration</legend>
<table><tbody>
<tr><td></td><td></td><td></td></tr>
</tbody></table>
</fieldset>
<br/>

<fieldset><legend>Bootstrap list protocol configuration</legend>
<table><tbody>
<tr><td></td><td></td><td></td></tr>
</tbody></table>
</fieldset>
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
function setDefaultSettings() {
  for (const key of Object.keys(default_config)) {
    console.log("Setting '" + key + "' to default value: " + default_config[key]);
    input_field=document.getElementsByName(key);
    if(input_field[0]) {
      input_field[0].value=default_config[key];
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

