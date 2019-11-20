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
<html>
<head>
<title>SystemImager configuration editor.</title>
  <style type='text/css' media='screen'>@import url('css/screen.css');</style>
  <style type='text/css' media='screen'>@import url('css/sliders.css');</style>
  <!-- <style type='text/css' media='screen'>@import url('css/print.css');</style> -->
</head>
<body>
<div class="flex_column"> <!-- start of flex column -->


<div class="flex_header">
<table id="headerTable"> <!-- SystemImager header -->
  <tbody>
    <tr>
      <td><img src="css/SystemImagerBanner.png" alt="SystemImagezr"></td>
      <td id="helpZone">
        <div id="client_list" style="display: none">Deployment Console:<br>A dynamic view of SystemImager clients with their deployment status. The full installation log for each client can be viewed in real time (or offline if client installation is finished).
        </div>
        <div id="health_console" style="display: none">Health Report:<br>This is a report of SystemImager state (enable/running) services, Deployment statistics, Images descriptions, ...
        </div>
        <div id="edit_config" style="display: none">SystemImager Configuration:<br>This is where you can configure most SystemImager parameters.
        </div>
        <div id="manage_netboot" style="display: none">Manage Netboot Entries:<br>This is where you can choose/assign a specific boot menu to a client. This also the place to edit imager cmdline options for a specific client or a class of clients.
        </div>
        <div id="edit_dhcp" style="display: none">Manage DHCP:<br>A place to configure DHCP for SystemImager clients.
        </div>
        <div id="edit_clusters" style="display: none">Edit Clusters:<br>Here, you can define cluster groups (This is similar to command line tool si_clusterconfig.
        </div>
      </td>
    </tr>
  </tbody>
</table>
<p>
<hr>
</div> <!-- end flex_header -->

<!-- SystemImager content -->
<div id="main_menu" class="flex_content">
  <div class="menu_grid">
<?php
function MenuButton($name, $title) {
echo <<<EOT
    <div class="menu_button" onmouseover="document.getElementById('$name').style.display='block';" onmouseout="document.getElementById('$name').style.display='none'">
      <a href="$name.php" class="btn">
        <img src="images/$name.png">
        <p>$title</p>
      </a>
    </div>
EOT;
}
MenuButton("client_list","Deployment Console");
MenuButton("health_console","Health Report");
MenuButton("edit_config","SystemImager Configuration");
MenuButton("manage_netboot","Manage NetBoot Entries");
MenuButton("edit_dhcp","Manage DHCP");
MenuButton("edit_clusters","Edit Clusters");
?>
  </div> <!-- end menu grid -->
</div> <!-- end flex content -->

<div style="flex: 1 1 auto"></div> <!-- spacer -->
<hr style="width: 100%"/>
<span>SystemImager v5.0 - Main menu</span>

</div> <!-- end flex column -->
</form>
</body>
</html>

