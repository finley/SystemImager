<!DOCTYPE html>
<!--
    vi: set filetype=php ts=4 sw=4 et :

    This file is part of SystemImager.

    SystemImager is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    SystemImager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with SystemImager. If not, see <https://www.gnu.org/licenses/>.

    Copyright (C) 2019 Olivier LAHAYE <olivier.lahaye1@free.fr>

    Purpose:
      Edit /etc/dhcp/dhcpd.conf
-->
<html>
<head>
<title>SystemImager DHCP Editor.</title>
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
      <td>SystemImager DHCP:</td>
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
<span>SystemImager v5.0 - DHCP Configuration.</span>
</section> <!-- end flex_column -->
</body>
</html>

