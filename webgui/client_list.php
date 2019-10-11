
<!DOCTYPE html>
<html>
<head>
<title>SystemImager clients list.</title>
  <style type='text/css' media='screen'>@import url('css/screen.css');</style>
  <style type='text/css' media='screen'>@import url('css/sliders.css');</style>
  <!-- <style type='text/css' media='screen'>@import url('css/print.css');</style> -->
  <script src="functions.js"></script>
</head>
<body>

<!--
<x?php
if (isset($_GET["client"])) {
    $client=$_GET["client"];
} else {
    $client="error.json";
}
?>
-->
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
<hr>
<p>

<table id="clientsTable">
  <thead>
    <tr>
      <th>Hostname</th>
      <th>Status</th>
      <th>Image</th>
      <th>Speed</th>
      <th>IP Addr</th>
      <th>MAC Addr</th>
      <th>ncpus</th>
      <th>CPU</th>
      <th>kernel</th>
      <th>mem</th>
      <th>time</th>
      <th>start time</th>
      <th>End time</th>
    </tr>
  </thead>
  <tbody id="clientsData">
  </tbody>
</table>

<script type="text/javascript">
var eSource; // Global variable.

//check for browser support
if (!!window.EventSource) {
  EnableRefresh(); // TODO: DisableRefresh() if no event since 5 minutes.
} else {
  document.getElementById("filtersRow").innerHTML="<td>Whoops! Your browser doesn't receive server-sent events.<br>Please use a web browser that supports EventSource interface <A href='https://caniuse.com/#feat=eventsource'>https://caniuse.com/#feat=eventsource</A></td>";
  document.getElementById("logTable").style.display="none";
  // sleep(5); // BUG: sleep does not exists.
  // Fallback: redirect to static page with refresh.
  // do an eSource.close(); when client has disconnected.
}

// Log connection established
eSource.addEventListener('open', function(e) {
  console.log("Connection was opened.")
}, false);

// Log connection closed
eSource.addEventListener('error', function(e) {
  if (e.readyState == EventSource.CLOSED) { 
    console.log("Connection was closed.");
  }
}, false);

function EnableRefresh() {
  eSource=new EventSource('push_client_defs.php');  //instantiate the Event source
  eSource.addEventListener('resetclients', ResetClientsHandler, false); // resetlog: when log has changed (reinstall)
  eSource.addEventListener('updateclient', UpdateClientsHandler , false); // client list updated.
  document.getElementById("refresh_text").innerHTML="Active";
  refresh_span=document.getElementById("refresh_text");
  refresh_span.innerHTML="Yes";
  refresh_span.setAttribute("class","pri_info");
}

function DisableRefresh() {
  eSource.removeEventListener('updateclient', UpdateClientsHandler , false);
  eSource.removeEventListener('resetclients', ResetClientsHandler, false);
  eSource.close();
  refresh_span=document.getElementById("refresh_text");
  refresh_span.innerHTML="No";
  refresh_span.setAttribute("class","pri_stderr");
}

function doRefresh(checkBox) {
    if (checkBox.checked == true) {
        EnableRefresh();
    } else {
        DisableRefresh();
    }
}

// Clean log if requested (in case of reimage for example)
function ResetClientsHandler(event) {
  document.getElementById("clientsData").innerHTML=""; // Remove all table lines.
}

// Called when event updateclient is received
function UpdateClientsHandler(event) {
  try { 
    var clientInfos = JSON.parse(event.data);
    clientLine = "<tr><td>"   + "<a href='client_console.php?client=" + clientInfos.name + "'>" + clientInfos.host + "</a>"
		+ "</td><td>" + StatusToText(clientInfos.status)
		+ "</td><td>" + clientInfos.os
		+ "</td><td>" + clientInfos.speed
		+ "</td><td>" + clientInfos.ip
		+ "</td><td>" + clientInfos.name
		+ "</td><td>" + clientInfos.ncpus
		+ "</td><td>" + clientInfos.cpu
		+ "</td><td>" + clientInfos.kernel
		+ "</td><td>" + clientInfos.mem
		+ "</td><td>" + clientInfos.time + "s"
		+ "</td><td>" + UnixDate(clientInfos.first_timestamp)
		+ "</td><td>" + UnixDate(clientInfos.timestamp)
		+ "</td><td>";
  } catch (e) {
    console.error("JSON client_log parsing error: ", e);
    clientLine = "<tr><td colspan=13>JSON parse error: "+event.data+"</td></tr>";
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

function doFilter(checkBox, msg_type) {
    var display;
    if (checkBox.checked == true) {
        display = "block";
    } else {
        display = "none";
    }

    var myClasses = document.querySelectorAll('.filter_'+msg_type),
    i = 0,
    l = myClasses.length;

    for (i; i < l; i++) {
        myClasses[i].style.display = display;
    }
}
</script>

</body>
</html>

