<!DOCTYPE html>
<!--
#
# "SystemImager" 
# Edit /etc/dhcp/dhcpd.conf
#
#  Copyright (C) 2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#  vi: set filetype=html et ts=4:
#
-->
<html>
<head>
<title>SystemImager Netboot Configuration.</title>
  <style type='text/css' media='screen'>@import url('css/screen.css');</style>
  <style type='text/css' media='screen'>@import url('css/sliders.css');</style>
  <style type='text/css' media='screen'>@import url('css/flex_table.css');</style>
  <!-- <style type='text/css' media='screen'>@import url('css/print.css');</style> -->
  <script src="functions.js"></script>
</head>
<body>

<!-- SystemImager header -->
<section class="flex"> <!-- start of flex column -->
<table id="headerTable">
  <tbody>
    <tr>
      <td><a href="index.php"><img src="css/SystemImagerBanner.png" alt="SystemImager"></a></td>
      <td id="clientData1">&nbsp;</td>
      <td id="clientData2">&nbsp;</td>
    </tr>
  </tbody>
</table>
<hr style="width: 100%"/>
<table id="filtersTable" width="99%">
  <tbody>
    <tr id="filtersRow">
      <td>SystemImager Netboot Configuration:</td>
      <td style="text-align:right">
        <span>&nbsp;</span>
      </td>
    </tr>
  </tbody>
</table>
<hr style="width: 100%"/>
    <div class="clients_grid" id="dhcpConfig"></div> <!-- clients listing -->
<?php
include 'functions.php';

# GUI: Display SystemImager Header
# 1/ Load preferences to know where clients defs files are stored
# 2/ load all clients definition files in a table
# 3/ Get a list of interfaces that have an IP
#    GUI: If interface is selected (POST) select it.
# 4/ If POST: read values
#    Process fields and generate missing clients def file
#    GUI: Add errors to field below Header (ip not bilonguing to known network, ...)
# 5/ GUI: Display useable interfaces (pre-select thoses matching a client).
# 6/ GUI: for each subnet/interface: list clients
# 7/ GUI: List clients with no IP (to be assigned)
# 8/ Load hdcp.conf static parts (header, ...)


?>
<div style="flex: 1 1 auto"></div> <!-- spacer -->
<hr style="width: 100%"/>
<span>SystemImager v5.0 - Netboot Configuration.</span>
</section> <!-- end flex_column -->
</body>
</html>

