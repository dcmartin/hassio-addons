#!/bin/tcsh

setenv DEBUG
setenv VERBOSE
setenv USE_MQTT

if ($?VERBOSE) echo "$0:t $$ -- START" `date` >& /dev/stderr

## REQUIRES date utilities
if ( -e /usr/bin/dateutils.dconv ) then
   set dateconv = /usr/bin/dateutils.dconv
else if ( -e /usr/bin/dateconv ) then
   set dateconv = /usr/bin/dateconv
else if ( -e /usr/local/bin/dateconv ) then
   set dateconv = /usr/local/bin/dateconv
else
  if ($?DEBUG && $?USE_MQTT) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "${MOTION_DEVICE_DB}/${MOTION_DEVICE_NAME}/debug" -m '{"ERROR":"'$0:t'","pid":"'$$'","error":"no date converter; install dateutils"}'
  goto done
endif

## ARGUMENTS
#
# on_event_start.sh %$ %v %Y %m %d %H %M %S
#
# %$ - camera name
# %v - Event number. An event is a series of motion detections happening with less than 'gap' seconds between them. 
# %Y - The year as a decimal number including the century. 
# %m - The month as a decimal number (range 01 to 12). 
# %d - The day of the month as a decimal number (range 01 to 31).
# %H - The hour as a decimal number using a 24-hour clock (range 00 to 23)
# %M - The minute as a decimal number (range 00 to 59). >& /dev/stderr
# %S - The second as a decimal number (range 00 to 61). 
#

set CN = "$1"
set EN = "$2"
set YR = "$3"
set MO = "$4"
set DY = "$5"
set HR = "$6"
set MN = "$7"
set SC = "$8"
set TS = "${YR}${MO}${DY}${HR}${MN}${SC}"

# in seconds
set NOW = `$dateconv -i '%Y%m%d%H%M%S' -f "%s" "${TS}"`

set dir = "${MOTION_DATA_DIR}/${CN}"

set EJ = "${dir}/${TS}-${EN}.json"

if ($?VERBOSE && $?USE_MQTT) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "${MOTION_DEVICE_DB}/${MOTION_DEVICE_NAME}/debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","start":'$NOW',"timestamp":"'"$TS"'","json":"'"$EJ"'"}'

echo '{"device":"'${MOTION_DEVICE_NAME}'","camera":"'${CN}'","event":"'${EN}'","start":'$NOW'}' >! "${EJ}"

if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "$MOTION_DEVICE_DB/${MOTION_DEVICE_NAME}/${CN}/event/start"
  mosquitto_pub -q 2 -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "$MOTION_MQTT_PORT" -t "$MQTT_TOPIC" -f "$EJ"
endif

done:

if ($?VERBOSE) echo "$0:t $$ -- END" `date` >& /dev/stderr
