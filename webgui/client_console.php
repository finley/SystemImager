
<!DOCTYPE html>
<html>
<head>
<title>SystemImager client install logs.</title>
  <style type='text/css' media='screen'>@import url('css/screen.css');</style>
  <!-- <style type='text/css' media='screen'>@import url('css/print.css');</style> -->
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
<p>

<table id="logTable">
  <thead>
    <tr><th>Tag</th><th>Priority</th><th>Message</th></tr>
  </thead>
  <tbody id="serverData">
  </tbody>
</table>

<script type="text/javascript">
var eSource; // Global variable.

//check for browser support
if (!!window.EventSource) {
  eSource= new EventSource('push_client_logs.php?client=<?php echo $client; ?>');  //instantiate the Event source
} else {
  document.getElementById("serverData").innerHTML="Whoops! Your browser doesn't receive server-sent events.<br>You'll be redirected to static log report page.";
  sleep(5);
  // Fallback: redirect to static page with refresh.
}

// Clean log if requested (in case of reimage for example)
function ResetLogHandler(event) {
  document.getElementById("serverData").innerHTML=""; // Remove all table lines.
}

// Called when event updatelog is received
function UpdateLogHandler(event) {
  var logText;
  try { 
    var logInfo = JSON.parse(event.data);
    logText = "<tr><td>" + logInfo.TAG + "</td><td>" +  PriorityToText(logInfo.PRIORITY) + "</td><td>" + logInfo.MESSAGE + "</td></tr>";
  } catch (e) {
    console.error("JSON client_log parsing error: ", e);
    // console.error("JSON: ", event.data);
    logText = "<tr><td>webgui</td><td>"+PriorityToText('local0.err')+"</td><td>" + event.data + "</td></tr>"; // BUG: invalid chars may appear and is subject to injection.
  }
  // console.log("log: " . logInfo.type . ": " . logInfo.message);
  // var logText = "log: " + logInfo.TAG + " - " + logInfo.PRIORITY + ": " + logInfo.MESSAGE + "<br>";
  document.getElementById("serverData").innerHTML += logText;
}

function PriorityToText(value) { // Original values from systemimager-lib.sh:logmessage()
    switch(value) {
        case 'local2.info': // stdout
            return "<span class='pri_stdout'>StdOut</span>";
            break;
        case 'local2.err': // stderr
            return "<span class='pri_stderr'>StdErr</span>";
            break;
        case 'local2.notice': // kernel info
            return "<span class='pri_system'>Kernel</span>";
            break;
        case 'local1.debug': // log STEP
            return "<span class='pri_debug'>===STEP</span>";
            break;
        case 'local1.info': // detail
            return "<span class='pri_notice'>Detail</span>";
            break;
        case 'local1.notice': // notice
            return "<span class='pri_notice'>Notice</span>";
            break;
        case 'local0.info': // info
            return "<span class='pri_info'>Info</span>";
            break;
        case 'local0.warning': // warning
            return "<span class='pri_warning'>Warning</span>";
            break;
        case 'local0.err': // ERROR
            return "<span class='pri_error'>ERROR</span>";
            break;
        case 'local0.notice': // action
            return "<span class='pri_action'>Action</span>";
            break;
        case 'local0.debug': // debug
            return "<span class='pri_debug'>Debug</span>";
            break;
        case 'local0.emerg': // FATAL
            return "<span class='pri_fatal'>FATAL</span>";
            break;
        default: // All other messages are system messages (not systemimager)
            return "<span class='pri_system'>System</span>";
            break;
    } 
}

function StatusToText(value) {
    if (value < 0) {
      return "Status: <span class='status0'>FAILED</span>";
    } else if (value < 100) {
      return "Progress: " + value + "%";
    } else {
      var index = value - 100;
      var my_statuses = ['Imaged','Finalizing...','REBOOTED','Beeping','Rebooting...','Shutdown','Shell','Extracting...','Pre-Install','Post-Install'];
      if ( index <= my_statuses.length+1 ) {
        return "Status: <span class='status" + value + "'>" + my_statuses[index] + "</span>";
      } else {
        return "Status: Unknown (<span class='status0'>" + (value) + ")</span>";
      }
    }
}

function UnixDate(unix_timestamp) {
    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var start_date = new Date(unix_timestamp * 1000);
    var hours = start_date.getHours();
    var minutes = "0" + start_date.getMinutes();
    var seconds = "0" + start_date.getSeconds();
    var my_time = hours + ':' + minutes.substr(-2) + ':' + seconds.substr(-2);
    var day = start_date.getDay();
    var month = months[start_date.getMonth()];
    var year = start_date.getFullYear();
    var my_date = day + ' ' + month + ' ' + year;
    return(my_time + " - " + my_date);
}

// Called when event updateclient is received
function UpdateClientHandler(event) {
  try {
    var clientInfo = JSON.parse(event.data);
    var clientText1 = "Hostname: " + clientInfo.host + 
                      "<br>MAC: " + clientInfo.name +
                      "<br>IP: " + clientInfo.ip +
                      "<br>Image: " + clientInfo.os +
                      "<br>" + StatusToText(clientInfo.status);
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

// Log connection established
eSource.addEventListener('open', function(e) {
  console.log("Connection was opened.")
}, false);

// Log connection closed
eSource.addEventListener('error', function(e) {
  if (e.readyState == EventSource.CLOSED) { 
    console.log("Connection was closed. ");
  }
}, false);


// eSource.addEventListener('message', UpdateLogHandler, false);
eSource.addEventListener('resetlog', ResetLogHandler, false); // resetlog: when log has changed (reinstall)
eSource.addEventListener('updatelog', UpdateLogHandler, false); // New lines in log
eSource.addEventListener('updateclient', UpdateClientHandler , false); // client updated stgatus or progress.

</script>

</body>
</html>

