#!/bin/tcsh
setenv DEBUG
setenv VERBOSE
setenv USE_MQTT

if ($?VERBOSE) echo "$0:t $$ -- START" `date` >& /dev/stderr

if ($#argv == 2) then
  set image = "$argv[1]"
  set output = "$argv[2]" 
  if ($?VERBOSE) echo "$0:t $$ -- $image to $output" >& /dev/stderr
else
  echo "USAGE: $0:t <jpg> <output>" >& /dev/stderr
  exit
endif

if ($?VERBOSE && $?USE_MQTT) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "${MOTION_DEVICE_DB}/${MOTION_DEVICE_NAME}/debug" -m '{"INFO":"'$0:t'","pid":"'$$'","info":"moving '$image' to '$output'"}'

if ($?VERBOSE) echo "$0:t moving $image to $output" >& /dev/stderr

mv -f "$image" "$output"

if ($?VERBOSE) echo "$0:t $$ -- FINISH" `date` >& /dev/stderr
