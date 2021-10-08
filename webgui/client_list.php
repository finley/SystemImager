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
      Client list (replacement for sio_monitortk main windows)
-->
<html>
<head>
<title>SystemImager clients list.</title>
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
      <td>SystemImager clients:</td>
      <td style="text-align:right">
        <span>Refresh:</span>
        <label class="switch">
          <input type="checkbox" id="refresh_checkbox" onclick="doRefresh(this)" checked>
          <span class="slider round"></span>
        </label>
        <span id="refresh_text">No</span>
      </td>
    </tr>
  </tbody>
</table>
<hr style="width: 100%"/>
    <div class="clients_grid" id="clientsData"></div> <!-- clients listing -->
    <div style="flex: 1 1 auto"></div> <!-- spacer -->
    <hr style="width: 100%"/>
    <span>SystemImager v5.0 - Clients list</span>
<script type="text/javascript">
var eSource; // Global variable.

var tableHeader= ['<div class="head">Hostname</div>',
      '<div class="head">Status</div>',
      '<div class="head">Image</div>',
      '<div class="head">Speed</div>',
      '<div class="head">IP Addr</div>',
      '<div class="head">MAC Addr</div>',
      '<div class="head">ncpus</div>',
      '<div class="head">CPU</div>',
      '<div class="head">kernel</div>',
      '<div class="head">mem</div>',
      '<div class="head">time</div>',
      '<div class="head">start time</div>',
      '<div class="head">End time</div>'].join("\n"); // IE does not support backtick for heredoc strings.
var clientsData=document.getElementById("clientsData"); // Note: the header is installed in clientsData grid by the reset function.


if (!!window.EventSource) { //check for browser support
  EnableRefresh(); // TODO: DisableRefresh() if no event since 5 minutes.
} else { // Bad web browser.
  document.getElementById("filtersRow").innerHTML="<div>Whoops! Your browser doesn't receive server-sent events.<br>Please use a web browser that supports EventSource interface <A href='https://caniuse.com/#feat=eventsource'>https://caniuse.com/#feat=eventsource</A></div>";
  clientsData.setAttribute('style','display: none;');
  // sleep(5); // BUG: sleep does not exists.
  // Fallback: redirect to static page with refresh.
  // do an eSource.close(); when client has disconnected.
}

function EnableRefresh() {
  eSource=new EventSource('push_client_defs.php');  //instantiate the Event source
  eSource.addEventListener('resetclients', ResetClientsHandler, false); // resetlog: when log has changed (reinstall)
  eSource.addEventListener('updateclient', UpdateClientsHandler , false); // client list updated.
  document.getElementById("refresh_text").innerHTML="Active";
  refresh_span=document.getElementById("refresh_text");
  refresh_span.innerHTML="Yes";
  refresh_span.setAttribute("class","pri_info");

  // Log connection established
  //eSource.addEventListener('open', function(e) {
  //  console.log("Connection was opened.")
  // }, false);

  // Log connection closed
  //eSource.addEventListener('error', function(e) {
  //  if (e.readyState == EventSource.CLOSED) { 
  //    console.log("Connection was closed.");
  //  }
  //}, false);
}

function DisableRefresh() {
  eSource.removeEventListener('updateclient', UpdateClientsHandler , false);
  eSource.removeEventListener('resetclients', ResetClientsHandler, false);
  eSource.close();
  refresh_span=document.getElementById("refresh_text");
  refresh_span.innerHTML="No";
  refresh_span.setAttribute("class","pri_stderr");
}

function doRefresh(checkbox) {
    if (checkbox.checked == true) {
        EnableRefresh(checkbox);
    } else {
        DisableRefresh(checkbox);
    }
}

// Clean log if requested (in case of reimage for example)
function ResetClientsHandler(event) {
  clientsData.innerHTML=tableHeader; // Remove all table lines.BUG: Also removes header.
}

// Called when event updateclient is received
function UpdateClientsHandler(event) {
  try { 
    var clientInfos = JSON.parse(event.data);
    clientLine = "<div><a href='client_console.php?client=" + clientInfos.name + "' class=\"lnk\">" + clientInfos.host + "</a>"
		+ "</div><div>" + StatusToText(clientInfos.status)
		+ "</div><div>" + clientInfos.os
		+ "</div><div>" + clientInfos.speed
		+ "</div><div>" + clientInfos.ip
		+ "</div><div>" + clientInfos.name
		+ "</div><div>" + clientInfos.ncpus
		+ "</div><div>" + clientInfos.cpu
		+ "</div><div>" + clientInfos.kernel
		+ "</div><div>" + clientInfos.mem
		+ "</div><div>" + clientInfos.time + "s"
		+ "</div><div>" + UnixDate(clientInfos.first_timestamp)
		+ "</div><div>" + UnixDate(clientInfos.timestamp)
		+ "</div>";
  } catch (e) {
    console.error("JSON client_log parsing error: ", e);
    clientLine = "<div style='grid-column: 1 / span 13;'>JSON parse error: "+event.data+"</div>"; // BUG: need to emulate colspan
  }
  document.getElementById("clientsData").innerHTML += clientLine;
}

// Called when event updateclient is received
//function UpdateHeaderHandler(event) {
//  try {
//    var clientInfo = JSON.parse(event.data);
//    var clientText1 = "Hostname: " + clientInfo.host + 
//                      "<br>MAC: " + clientInfo.name +
//                      "<br>IP: " + clientInfo.ip +
//                      "<br>Image: " + clientInfo.os +
//                      "<br>" + StatusToText(clientInfo.status);
//
//    var clientText2 = "CPU(s): " + clientInfo.ncpus + " x " + clientInfo.cpu +
//                      "<br>Memory: " + Math.trunc(clientInfo.mem / 1024) +
//                      " MiB<br>Kernel: " + clientInfo.kernel +
//                      "<br>Started: " + UnixDate(clientInfo.first_timestamp) +
//                      "<br>Duration: " + (clientInfo.timestamp - clientInfo.first_timestamp) +'s';
//    document.getElementById("clientData1").innerHTML = clientText1;
//    document.getElementById("clientData2").innerHTML = clientText2;
//  } catch (e) {
//    console.error("JSON client_info parsing error: ", e);
//  }
//}

</script>
</section> <!-- end flex_column -->
</body>
</html>

