#!/bin/bash
#
# SystemImager plymouth theme test suite.
#

rm -rf /tmp/plymouth.log
plymouthd --debug --debug-file=/tmp/plymouth.log
plymouth show-splash
sleep 0.5  # Wait for splash to appear otherwize we miss some refreshes (gfx display init is asynchrone).

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
    plymouth update --status="mesg:I:Running script ${i//0/}/4"
    plymouth update --status="post:$i:004"
    [ $i -ne 4 ] && plymouth update --status="dlgb:yes:Script ${i//0/} ran successfully!" && sleep 1
    [ $i -eq 4 ] && plymouth update --status="dlgb: no:Script 4 failed!!!!" && sleep 1
    sleep 0.5
done
plymouth update --status="dlgb:off"
plymouth update --status="mesg:I:Testing pasword request"
SSHPASS=$(plymouth ask-for-password --prompt "Please, enter password:") # We just test the password dialog in theme, not plymouth ability to retreave the password
plymouth update --status="mesg:I:Got ret code=$? and Passwd=[${SSHPASS}]"

# Differt way to query ssh password
# 1: using plymouth --command
#plymouth ask-for-password --prompt "Please, enter password:" --command "ssh my-server 'hostname'" --number-of-tries=3 > /tmp/result
# 2: reading plymouth password return
#PASS="$(plymouth ask-for-password --prompt 'Please, enter password:')"
# 3: using sshpass and systemd-ask-password (doesn't work (not supported) on CentOS-6)
#SSHPASS="$(systemd-ask-password 'SSH password')" sshpass -e ssh my-server 'hostname' > /tmp/result
# 4: using ask_for_password from 90crypt dracut module lib.
#. /lib/dracut-crypth-lib.sh
#ask_for_password --prompt "SSH Password" --cmd "ssh ${IMAGESERVER} 'hostname' > /tmp/result"

plymouth update --status="mesg:N:This is the last message"
sleep 3

# Finish.
plymouth hide-splash
plymouth quit

