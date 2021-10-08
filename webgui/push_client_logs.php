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
      Server sent events: log push to console emulation.
-->
<?php

include 'functions.php';

//streaming code
header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');

$log_line = 0;
$client = "";
$client_id = 0;
$fh = false; // File handler

if (isset($_GET["client"])) {
    $client=$_GET["client"];
} else {
    $json_error='{ "TAG" : "webgui" , "PRIORITY" : "local0.crit" , "MESSAGE" : "client= missing parameter in URL." }';
    si_SendEvent('updatelog',5000,1,$json_error);
    si_SendEvent('stop',5000,++$client_id,""); /* Tell client to close ServerEvent */
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

function SendClientDef() {
    global $client, $client_id;
    $client_infos = file_get_contents('/var/lib/systemimager/clients/'.$client.'_def.json');
    if ($client_infos !== false) {
        $client_infos = str_replace(array("\n", "\r"), '', $client_infos);
        si_SendEvent('updateclient',5000,++$client_id,$client_infos);
    } // If error; not an issue.
}

function SendMsg($Pri,$Msg) {
  global $client_id;
  $json_message='{ "TAG" : "webgui" , "PRIORITY" : "'.$Pri.'" , "MESSAGE" : "'.$Msg.'" }';
  si_SendEvent('updatelog',5000,++$client_id,$json_message);
}

function OpenLogFile() {
  global $fh, $client, $client_id;
  $fh = fopen("/var/lib/systemimager/clients/${client}_log.json", 'r');
  if ($fh == false) {
    SendMsg('local0.emerg', 'Can\'t read /var/lib/systemimager/clients/'.$client.'_log.json');
    SendMsg('local0.emerg', 'Please check PATH and permissions. Giving up!');
    si_SendEvent('stop',5000,++$client_id,""); /* Tell client to close ServerEvent */
  }
  SendMsg('local0.info','Reading /var/lib/systemimager/clients/'.$client.'_log.json');
}
// MAIN PROGRAMM STARTS HERE.

SendClientDef(); /* 1st, try to send client infos before we try to read the log */

if ( ! file_exists("/var/lib/systemimager/clients/${client}_log.json")) {
  SendMsg('local0.warning', '/var/lib/systemimager/clients/'.$client.'_log.json not yet available.');
  SendMsg('local0.info', 'Wating a few minutes for log to appear..');
  $count=0;
  do {
    if (file_exists("/var/lib/systemimager/clients/${client}_log.json")) {
      break;
    }
    usleep(0.5 * 1000000); // Sleep for 0.5s
    if($count++ > 600) { // 600 = 5min * 60s * 2 (2 counts for a single second)
      SendMsg('local0.emerg', 'Log not available after 5 minutes. Giving up!');
      si_SendEvent('stop',5000,++$client_id,""); /* Tell client to close ServerEvent */
      exit;
    }
  } while(true);
}

// At this point, file is seen, but it may not be readable.
OpenLogFile();
//$json_message='{ "TAG" : "webgui" , "PRIORITY" : "local0.info" , "MESSAGE" : "Reading /var/lib/systemimager/clients/'.$client.'_log.json" }';
//si_SendEvent('updatelog',5000,1,$json_message);

// TODO: if curdate - filedate > 1H, send stop refresh after last line is processed and exit
// TODO: catch file reset (if previous filesize > current filesize => resetlog)

while (true) {
    $json_log_line = fgets($fh);
    if ($json_log_line !== false) {
      $log_line += 1;
      si_SendEvent('updatelog',5000,$log_line,$json_log_line);
    } else {
        // sleep for 0.5 seconds (or more?)
        usleep(0.5 * 1000000);
	SendClientDef();
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
