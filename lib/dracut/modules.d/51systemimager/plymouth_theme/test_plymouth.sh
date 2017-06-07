#!/bin/bash
#
# SystemImager plymouth theme test suite.
#

rm -rf /tmp/plymouth.log
plymouthd --debug --debug-file=/tmp/plymouth.log
plymouth show-splash
sleep 5  # Wait for splash to appear otherwize we miss some refreshes.

# Now testing.
plymouth update --status="mesg:I:SystemImager plymouth theme test suite."
sleep 0.5
plymouth update --status="mesg:W: TEST: This is a warning message."
sleep 0.5
plymouth update --status="init:" # Highlight the init icon
sleep 0.5
plymouth update --status="prei:" # Highlight the preinstall script icon (0 scripts)
sleep 0.5
plymouth update --status="part:" # Highlight the partition disk icon
sleep 0.5
plymouth update --status="frmt:" # Highlight the format partition icon
sleep 0.5
plymouth message --text="This is an unhandled message. (should *NOT* be displayed)"
plymouth update --status="conf:sys:Y" # Enable system message display
plymouth message --text="This is an unhandled message. (should *BE* displayed)"
sleep 0.5
plymouth update --status="mesg:A: Started imaging simulation."
for i in 0{0..9}0 100 # Highlight Imaging icon and show its progress percent
do
    plymouth update --status="mesg:I:Progress: ${i}%"
    plymouth update --status="imag:${i}:100"
    sleep 0.5
done
plymouth update --status="boot:" # Highlight the install bootloader icon
sleep 0.5
for i in 00{1..4} # Highlight the post install script icon and simulate 4 executions
do
    plymouth update --status="mesg:I:Running script ${i}/4"
    plymouth update --status="post:$i:004"
    sleep 0.5
done
plymouth update --status="mesg:N:This is the last message"
sleep 5

# Finish.
plymouth hide-splash
plymouth quit

