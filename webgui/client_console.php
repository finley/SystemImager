<!DOCTYPE html>
<!--
# vi: set ts=4 sw=4 et:
#
# "SystemImager" 
# Client console emulation. (replacement for si_monitortk console)
#
#  Copyright (C) 2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#
-->

<html>
<head>
<title>SystemImager client install logs.</title>
  <style type='text/css' media='screen'>@import url('css/screen.css');</style>
  <style type='text/css' media='screen'>@import url('css/sliders.css');</style>
  <style type='text/css' media='screen'>@import url('css/flex_table.css');</style>
  <!-- <style type='text/css' media='screen'>@import url('css/print.css');</style> -->
  <script src="functions.js"></script>
</head>
<body>

<?php
if (isset($_GET["client"])) {
    $client=$_GET["client"];
} else {
    $client="error.json";
}
?>
<!-- SystemImager header -->
<section class="flex"> <!-- flex_column -->
<table id="headerTable">
  <tbody>
    <tr>
      <td><img src="css/SystemImagerBanner.png" alt="SystemImagezr"></td>
      <td id="clientData1">&nbsp;</td>
      <td id="clientData2">&nbsp;</td>
    </tr>
  </tbody>
</table>
    <hr style="width: 100%"/>
<table id="filtersTable" width="99%">
  <tbody>
    <tr id="filtersRow">
      <td>Filters:
        <span class='pri_debug'>Debug</span>
        <label class="switch">
          <input type="checkbox" onclick="doFilter(this,'debug')" checked>
          <span class="slider round"></span>
        </label>
        <span class='pri_system'>System</span>
        <label class="switch">
          <input type="checkbox" onclick="doFilter(this,'system')" checked>
          <span class="slider round"></span>
        </label>
        <span class='pri_notice'>Notice</span>
        <label class="switch">
          <input type="checkbox" onclick="doFilter(this,'notice')" checked>
          <span class="slider round"></span>
        </label>
        <span class='pri_detail'>Detail</span>
        <label class="switch">
          <input type="checkbox" onclick="doFilter(this,'detail')" checked>
          <span class="slider round"></span>
        </label>
        <span class='pri_stdout'>StdOut</span>
        <label class="switch">
          <input type="checkbox" onclick="doFilter(this,'stdout')" checked>
          <span class="slider round"></span>
        </label>
        <span class='pri_stderr'>StdErr</span>
        <label class="switch">
          <input type="checkbox" onclick="doFilter(this,'stderr')" checked>
          <span class="slider round"></span>
        </label>
      </td>
      <td style="text-align:right">
        <span id=autoscroll class='pri_info'>(Auto Scroll)</span>&nbsp;&nbsp;
        <span>Refresh:</span>
        <label class="switch">
          <input type="checkbox" id="refresh_checkbox" onclick="doRefresh(this)" checked>
          <span class="slider round"></span>
        </label>
        <span id="refresh_text" class='pri_stderr'>No</span>
      </td>
    </tr>
  </tbody>
</table>
    <hr style="width: 100%"/>
    <header>
        <div>Tag</div>
        <div>Priority</div>
        <div>Messages (All messages including kernel messages and sttout+stderr).</div>
    </header>
    <article id="serverData">
    </article>
    <!-- <footer>
        <div>Col 1</div>
        <div>Col 2</div>
        <div>Col 3</div>
    </footer> -->
    <hr style="width: 100%"/>
    <span>SystemImager v5.0 - Client console</span>

<script type="text/javascript">
var eSource; // Event source Global variable.
var serverData_elm=document.getElementById("serverData");
//var logTable_elm=document.getElementById("logTable");
var needToScrollDown = new Boolean("false");
var scroll_span = document.getElementById("autoscroll");

//check for browser support
if (!!window.EventSource) {
  EnableRefresh();
} else {
  document.getElementById("filtersRow").innerHTML="<div>Whoops! Your browser doesn't receive server-sent events.<br>Please use a web browser that supports EventSource interface <A href='https://caniuse.com/#feat=eventsource'>https://caniuse.com/#feat=eventsource</A></div>";
  document.getElementById("logTable").style.display="none";
  // Fallback: TODO: should redirect to static page with refresh.
  // do an eSource.close(); when client has disconnected.
}

// Enable server sent event
function EnableRefresh() {
  eSource=new EventSource('push_client_logs.php?client=<?php echo $client; ?>');  //instantiate the Event source
  eSource.addEventListener('resetlog', ResetLogHandler, false); // resetlog: when log has changed (reinstall)
  eSource.addEventListener('updatelog', UpdateLogHandler, false); // New lines in log
  eSource.addEventListener('updateclient', UpdateClientHandler , false); // client updated status or progress.
  eSource.addEventListener('stop', DisableRefresh, false); // Stop refresh.
  refresh_span=document.getElementById("refresh_text");
  refresh_span.innerHTML="Yes";
  refresh_span.setAttribute("class","pri_info");
  ComputeAutoScrollRequirements(); // Enable autoscroll if needed.
  // Log connection established
  // eSource.addEventListener('open', function(e) {
  //  console.log("Connection was opened.")
  //}, false);

  // Log connection closed
  //eSource.addEventListener('error', function(e) {
  //  if (e.readyState == EventSource.CLOSED) { 
  //    console.log("Connection was killed. ");
  //  }
  //}, false);

}

// Disable Server sent event
function DisableRefresh() {
  eSource.removeEventListener('updateclient', UpdateClientHandler , false);
  eSource.removeEventListener('updatelog', UpdateLogHandler, false);
  eSource.removeEventListener('resetlog', ResetLogHandler, false);
  eSource.removeEventListener('stop', DisableRefresh, false); // Stop refresh.
  // Should I remove the open and error listenners?
  eSource.close();
  refresh_span=document.getElementById("refresh_text");
  refresh_span.innerHTML="No";
  refresh_span.setAttribute("class","pri_stderr");
  needToScrollDown = false; // Disable AutoScroll.
  scroll_span.setAttribute("class","pri_system");
  document.getElementById("refresh_checkbox").checked = false; // Needed when called by Event 'stop'.
}

// Enable or disable page live refresh according to checkbox state.
function doRefresh(checkbox) {
    if (checkbox.checked == true) {
        EnableRefresh();
    } else {
        DisableRefresh();
    }
}

// Clean log if requested (in case of reimage for example)
function ResetLogHandler(event) {
  serverData_elm.innerHTML=""; // Remove all table lines.
}

function ComputeAutoScrollRequirements() {
  bodyBounding = serverData_elm.getBoundingClientRect(); // Get the table visible lines area
  logLinesCount = serverData_elm.childElementCount ;  // Get the number of rows in logTable
  if(logLinesCount == 0) {
    needToScrollDown = Boolean("false");
  } else {
    lastRow=serverData_elm.lastChild;
    lineBounding = lastRow.getBoundingClientRect(); // get the last line area.
    min=Number(bodyBounding.top);    // tbody minimum visible Y
    max=Number(bodyBounding.bottom); // tbody maximum visible Y
    val=Number(lineBounding.top);    // Lat line top Y
    if ( (val >= min) && (val <= max) ) {
      needToScrollDown = true;  // If last line top pixel between table visible area top and bottom: scroll
      scroll_span.setAttribute("class","pri_info");
    } else {
      needToScrollDown = false; // Last line not visible: don't try to scroll.
      scroll_span.setAttribute("class","pri_system");
    }
  }
}

// Called when event updatelog is received
function UpdateLogHandler(event) {
  var logText;
  try { 
    var logInfo = JSON.parse(event.data);
    logLine = LogToHTML(logInfo.TAG,logInfo.PRIORITY,logInfo.MESSAGE);
  } catch (e) {
    console.error("JSON client_log parsing error: ", e);
    // console.error("JSON: ", event.data);
    logLine = LogToHTML('webgui','local0.err',event.data); // BUG: invalid chars may appear and is subject to injection.
  }
// Stack overflow question:
// https://stackoverflow.com/questions/58014912/how-can-scroll-down-a-tbody-table-when-innerhtml-is-updated-with-new-lines

//  lastRow=logTable_elm.rows[ logTable_elm.rows.length - 1];
   ComputeAutoScrollRequirements();


  serverData_elm.innerHTML += logLine;

  if ( needToScrollDown ) {
    serverData_elm.scrollTop = serverData_elm.scrollHeight - bodyBounding.height;
  }
}

function LogToHTML(tag,value,message) { // Original values from systemimager-lib.sh:logmessage()
    switch(value) {
        case 'local2.info': // stdout
            return "<div class='row filter_stdout'><div>"+tag+"</div><div><span class='pri_stdout'>StdOut</span></div><div>"+message+"</div></div>";
            break;
        case 'local2.err': // stderr
            return "<div class='row filter_stderr'><div>"+tag+"</div><div><span class='pri_stderr'>StdErr</span></div><div>"+message+"</div></div>";
            break;
        case 'local2.notice': // kernel info
            return "<div class='row filter_system'><div>"+tag+"</div><div><span class='pri_system'>Kernel</span></div><div>"+message+"</div></div>";
            break;
        case 'local1.debug': // log STEP
            return "<div class='row filter_debug'><div>"+tag+"</div><div><span class='pri_debug'>===STEP</span></div><div>"+message+"</div></div>";
            break;
        case 'local1.info': // detail
            return "<div class='row filter_detail'><div>"+tag+"</div><div><span class='pri_detail'>Detail</span></div><div>"+message+"</div></div>";
            break;
        case 'local1.notice': // notice
            return "<div class='row filter_notice'><div>"+tag+"</div><div><span class='pri_notice'>Notice</span></div><div>"+message+"</div></div>";
            break;
        case 'local0.info': // info
            return "<div class='row'><div>"+tag+"</div><div><span class='pri_info'>Info</span></div><div>"+message+"</div></div>";
            break;
        case 'local0.warning': // warning
            return "<div class='row'><div>"+tag+"</div><div><span class='pri_warning'>Warning</span></div><div>"+message+"</div></div>";
            break;
        case 'local0.err': // ERROR
            return "<div class='row'><div>"+tag+"</div><div><span class='pri_error'>ERROR</span></div><div>"+message+"</div></div>";
            break;
        case 'local0.notice': // action
            return "<div class='row'><div>"+tag+"</div><div><span class='pri_action'>Action</span></div><div>"+message+"</div></div>";
            break;
        case 'local0.debug': // debug
            return "<div class='row filter_debug'><div>"+tag+"</div><div><span class='pri_debug'>Debug</span></div><div>"+message+"</div></div>";
            break;
        case 'local0.emerg': // FATAL
            return "<div class='row'><div>"+tag+"</div><div><span class='pri_fatal'>FATAL</span></div><div>"+message+"</div></div>";
            break;
        default: // All other messages are system messages (not systemimager)
            return "<div class='row filter_system'><div>"+tag+"</div><div><span class='pri_system'>System</span></div><div>"+message+"</div></div>";
            break;
    } 
}

// Called when event updateclient is received
function UpdateClientHandler(event) {
  try {
    var clientInfo = JSON.parse(event.data);
    var clientText1 = "Hostname: " + clientInfo.host + 
                      "<br>MAC: " + clientInfo.name +
                      "<br>IP: " + clientInfo.ip +
                      "<br>Image: " + clientInfo.os +
                      "<br>Status: " + StatusToText(clientInfo.status);
//                      "<br>" + get_status(clientInfo.status);

    var clientText2 = "CPU(s): " + clientInfo.ncpus + " x " + clientInfo.cpu +
                      "<br>Memory: " + Math.trunc(clientInfo.mem / 1024) +
                      " MiB<br>Kernel: " + clientInfo.kernel +
                      "<br>Started: " + UnixDate(clientInfo.first_timestamp) +
                      "<br>Duration: " + (clientInfo.timestamp - clientInfo.first_timestamp) +'s';
    document.getElementById("clientData1").innerHTML = clientText1;
    document.getElementById("clientData2").innerHTML = clientText2;
  } catch (e) {
    console.error("JSON client_info parsing error: ", e);
    // console.error("JSON: ", event.data);
  }
}

function doFilter(checkbox, msg_type) {
    var display;
    if (checkbox.checked == true) {
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
</section> <!-- flex_column -->
</body>
</html>

