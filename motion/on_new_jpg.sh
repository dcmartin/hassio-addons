#!/bin/tcsh
echo "$0:t $$ -- START" `date` >& /dev/stderr

setenv DEBUG
# setenv VERBOSE

if ($#argv == 2) then
  set image = "$argv[1]"
  set output = "$argv[2]" 
  if ($?VERBOSE) echo "$0:t $$ -- $image to $output" >& /dev/stderr
else
  echo "USAGE: $0:t <jpg> <output>" >& /dev/stderr
  exit
endif

if ($?VERBOSE) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -m '{"INFO":"'$0:t'","pid":"'$$'","info":"moving '$image' to '$output'"}'

echo "$0:t moving $image to $output" >& /dev/stderr
mv -f "$image" "$output"
