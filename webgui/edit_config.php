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
-->
<?php
include 'functions.php';

// By default: view mode (no save/cancel buttons (hidden). instead a edit button)
// View mode: all fields are read only
// Edit mode: fields are read write and Save (post) (cancel) button appear (edit button is hidden)
if ($_SERVER["REQUEST_METHOD"] == "POST") { // we're called as post
  // Read and validate fields.
  $config->error="";
  $config->images_dir=$_POST["images_dir"];
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
  // si_WriteConfig($config);

} else { // we're called as "view"
$config=si_ReadConfig();

}

?>

<html>
<head>
<title>SystemImager clients list.</title>
  <style type='text/css' media='screen'>@import url('css/screen.css');</style>
  <style type='text/css' media='screen'>@import url('css/sliders.css');</style>
  <!-- <style type='text/css' media='screen'>@import url('css/print.css');</style> -->
  <script src="functions.js"></script>
</head>
<body>

<!-- SystemImager header -->
<table id="headerTable">
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
<div id="config_div">
  <?php
if($config->error !== "") {
  echo "<span class='pri_error'>".$config->pri_error."</span>\n";
}
?>
<br><br>

  <form method="post" action="<?php echo htmlspecialchars($_SERVER["PHP_SELF"]);?>">
<div id="parameters" style="overflow-y: scroll; height:60vh;">
<fieldset><legend>Imager data paths</legend>
<table><tbody>
<tr><td>images_dir</td><td><input type="text" name="images_dir" size="50" value="<?php echo $config->images_dir;?>"></td><td>Place where images are stored.</td></tr>
<tr><td>overrides_dir</td><td><input type="text" name="overrides_dir" size="50" value="<?php echo $config->overrides_dir;?>"></td><td>Place where override files are stored. They are copied to client filesystem overwriting existing files.</td></tr>
<tr><td>scripts_dir</td><td><input type="text" name="scripts_dir" size="50" value="<?php echo $config->scripts_dir;?>"></td><td></td></tr>
<tr><td>tarballs_dir</td><td><input type="text" name="tarballs_dir" size="50" value="<?php echo $config->tarballs_dir;?>"></td><td></td></tr>
<tr><td>torrents_dir</td><td><input type="text" name="torrents_dir" size="50" value="<?php echo $config->torrents_dir;?>"></td><td></td></tr>
<tr><td>clients_db_dir</td><td><input type="text" name="clients_db_dir" size="50" value="<?php echo $config->clients_db_dir;?>"></td><td></td></tr>
</tbody></table>
</fieldset>
<br/>

<fieldset><legend>Imager binaries</legend>
<table><tbody>
<tr><td>pxe_boot_files</td><td><input type="text" name="pxe_boot_files" size="50" value="<?php echo $config->pxe_boot_files;?>"></td><td></td></tr>
</tbody></table>
</fieldset>
<br/>

<fieldset><legend>PXE configuration</legend>
<table><tbody>
<tr><td>tftp_dir</td><td><input type="text" name="tftp_dir" size="50" value="<?php echo $config->tftp_dir;?>"></td><td></td></tr>
<tr><td>pxe_boot_mode</td><td><select name="pxe_boot_mode">
<option value="net" <?php if($config->pxe_boot_mode === "net") echo "selected"; ?>>Network boot</options>
<option value="local" <?php if($config->pxe_boot_mode === "local") echo "selected"; ?>>Local boot</options>
</select></td><td></td></tr>
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
</div>
<br/>

<fieldset>
<table style="width: 95%"><tbody>
<tr><td><input type="submit" name="submit" value="Save"/></td><td>Edit</td><td><input type="reset" value="Reset"/></td></tr>
</tbody></table>
  </form>
</div>

<script type="text/javascript">
</script>

</body>
</html>
