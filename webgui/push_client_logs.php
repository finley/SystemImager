<!--
#
# "SystemImager" 
# Server sent events: log push to console emulation.
#
#  Copyright (C) 2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#  vi: set filetype=javascript et ts=4:
#
-->
<?php

include 'functions.php';

//streaming code
header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');

if (isset($_GET["client"])) {
    $client=$_GET["client"];
} else {
    $json_error='{ "TAG" : "webgui" , "PRIORITY" : "local0.crit" , "MESSAGE" : "client= missing parameter in URL." }';
    si_SendEvent('updatelog',5000,1,$json_error);
    // Fallback behaviour goes here
}

// if there was a lastEventId sent in the header, send
// the history of messages we've already stored up
//if (request.headers['last-event-id']) {
//  var id = parseInt(request.headers['last-event-id']);
//  for (var i = 0; i < history.length; i++) {
//    if (history[i].id >= id) {
//      sendSSE(response, history[i].id, history[i].event, history[i].message);
//    }
//  }
//} else {
  // if the client didn't send a lastEventId, it's the
  // first time they've come to our service, so send an
  // initial empty message with no id - this will reset
  // their id counter too.
//  response.write('id\n\n');
//}

$fh = fopen("/var/lib/systemimager/clients/${client}_log.json", 'r');
if ($fh == false) {
  $json_error='{ "TAG" : "webgui" , "PRIORITY" : "local0.error" , "MESSAGE" : "Can\'t read /var/lib/systemimager/clients/'.$client.'_log.json" }';
  si_SendEvent('updatelog',5000,1,$json_error);
  exit ;
}
$json_message='{ "TAG" : "webgui" , "PRIORITY" : "local0.info" , "MESSAGE" : "Reading /var/lib/systemimager/clients/'.$client.'_log.json" }';
si_SendEvent('updatelog',5000,1,$json_message);
$log_line = 0;
$client_id = 0;
while (true) {
    $json_log_line = fgets($fh);
    if ($json_log_line !== false) {
      $log_line += 1;
      si_SendEvent('updatelog',5000,$log_line,$json_log_line);
    } else {
        // sleep for 0.5 seconds (or more?)
        usleep(0.5 * 1000000);
	$client_infos = file_get_contents('/var/lib/systemimager/clients/'.$client.'_def.json');
	if ($client_infos !== false) {
          $client_infos = str_replace(array("\n", "\r"), '', $client_infos);
          si_SendEvent('updateclient',5000,++$client_id,$client_infos);
        }
	$position=ftell($fh);
        if ($position !== false) {
          fseek($fh, ftell($fh));
        } else { // File reset?
          si_SendEvent('resetlog',5000,1,"");
          $log_line = 0;
          fseek($fh,0);
        }
    }
}

// $json_log_line='{ "type" : "info" , "message" : "This is a test message" }';
// $json_client_line='{ "name" : "11:22:33:44:55:66" }';

// si_SendEvent('updatelog',$id,$json_log_line);
// si_SendEvent('updateclient',$id+1,$json_client_line);

?>
