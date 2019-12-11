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
      ServerSent Event: Push new clients to client list page.
-->
<?php

include 'functions.php';

//streaming code
header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');

if (isset($_GET["refresh"])) {
    $refresh=$_GET["client"];
} else {
    $refresh=1;
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


$log_line = 0;
$client_id = 0;
while (true) {
    $def_files=glob("/var/lib/systemimager/clients/??.??.??.??.??.??_def.json");
    // $def_files: empty table if no file / FALSE if error occured. (perm, ..)
    si_SendEvent('resetclients',5000,++$client_id,'');
    foreach ($def_files as $client) {
	$client_infos = file_get_contents($client);
	if ($client_infos !== false) {
          $client_infos = str_replace(array("\n", "\r"), '', $client_infos);
          si_SendEvent('updateclient',5000,++$client_id,$client_infos);
        }
    }
    // sleep for 30 seconds (or more?)
    usleep(30 * 1000000);
}

// $json_log_line='{ "type" : "info" , "message" : "This is a test message" }';
// $json_client_line='{ "name" : "11:22:33:44:55:66" }';

// si_SendEvent('updatelog',$id,$json_log_line);
// si_SendEvent('updateclient',$id+1,$json_client_line);

?>
