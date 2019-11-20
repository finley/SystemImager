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
# View services statuses
# View stats (clients count, clusters count, images count, ....)

-->
<html>
<head>
<title>SystemImager System Health.</title>
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
      <td>SystemImager Health Reporting:</td>
      <td style="text-align:right">
        <span>&nbsp;</span>
      </td>
    </tr>
  </tbody>
</table>
<hr style="width: 100%"/>
<div id="parameters" class="flex_content">

<fieldset><legend>&nbsp;Services&nbsp;</legend>
List of SystemImager services
</fieldset>
<br/>

<fieldset><legend>&nbsp;Deployment status&nbsp;</legend>
Deployment graph
</fieldset>
<br/>

<fieldset><legend>&nbsp;Images&nbsp;</legend>
List of SystemImager Images
</fieldset>
<br/>
</div>
<div style="flex: 1 1 auto"></div> <!-- spacer -->
<hr style="width: 100%"/>
<span>SystemImager v5.0 - Health Reporting.</span>
</section> <!-- end flex_column -->
</body>
</html>

