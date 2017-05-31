#!/bin/bash
#
# SystemImager plymouth theme test suite.
#

test -z "${SYSTEMIMAGER_LIB}" && SYSTEMIMAGER_LIB=/lib/systemimager-lib.sh
. ${SYSTEMIMAGER_LIB}

rm -rf /tmp/plymouth.log
plymouthd --debug --debug-file=/tmp/plymouth.log
plymouth show-splash
sleep 5  # Wait for splash to appear otherwize we miss some refreshes.

# Now testing.
plymouth message --text="I:SystemImager plymouth theme test suite."
sleep 0.5
plymouth message --text="W: TEST: This is a warning message."
sleep 0.5
plymouth update --status="prei:000:000" # Highlight the preinstall script icon (0 scripts)
sleep 0.5
plymouth update --status="init:000:000" # Highlight the init icon
sleep 0.5
plymouth update --status="part:000:000" # Highlight the partition disk icon
sleep 0.5
plymouth update --status="frmt:000:000" # Highlight the format partition icon
sleep 0.5
plymouth update --status="syst:000:001" # Enable system message display
sleep 0.5
plymouth message --text="A: Started imaging simulation."
for i in 0{0..9}0 100 # Highlight Imaging icon and show its progress percent
do
    plymouth message --text="I:Progress: ${i}%"
    plymouth update --status="imag:${i}:100"
    sleep 0.5
done
plymouth update --status="boot:000:000" # Highlight the install bootloader icon
sleep 0.5
for i in 00{1..4} # Highlight the post install script icon and simulate 4 executions
do
    plymouth message --text="I:Running script ${i}/4"
    plymouth update --status="post:$i:004"
    sleep 0.5
done
plymouth message --text="N:This is the last message"
sleep 5

# Finish.
plymouth hide-splash
plymouth quit

