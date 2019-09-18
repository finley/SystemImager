<?php

function si_SendEvent($event,$retry,$id,$data) {
        echo 'retry: $retry' . PHP_EOL;
        echo 'event: ' . $event . PHP_EOL;
        echo 'id: ' . $id . PHP_EOL;
        echo 'data: ' . $data . PHP_EOL;
        echo PHP_EOL;
        ob_flush();
        flush();
}

?>
