<!--
#
# "SystemImager" 
# Common php functions.
#
#  Copyright (C) 2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#  vi: set filetype=php et ts=4:
#
-->
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
