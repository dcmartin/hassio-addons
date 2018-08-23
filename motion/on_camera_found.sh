#!/bin/tcsh
setenv DEBUG true
unsetenv VERBOSE true

if ($?VERBOSE) echo "$0:t $$ -- START" `date` >& /dev/stderr

## REQUIRES date utilities
if ( -e /usr/bin/dateutils.dconv ) then
   set dateconv = /usr/bin/dateutils.dconv
else if ( -e /usr/bin/dateconv ) then
   set dateconv = /usr/bin/dateconv
else if ( -e /usr/local/bin/dateconv ) then
   set dateconv = /usr/local/bin/dateconv
else
  if ($?DEBUG) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -m '{"ERROR":"'$0:t'","pid":"'$$'","error":"no date converter; install dateutils"}'
  goto done
endif

#
# %$ - camera name
# %Y - The year as a decimal number including the century. 
# %m - The month as a decimal number (range 01 to 12). 
# %d - The day of the month as a decimal number (range 01 to 31).
# %H - The hour as a decimal number using a 24-hour clock (range 00 to 23)
# %M - The minute as a decimal number (range 00 to 59). >& /dev/stderr
# %S - The second as a decimal number (range 00 to 61). 
#

set CN = "$1"
set YR = "$2"
set MO = "$3"
set DY = "$4"
set HR = "$5"
set MN = "$6"
set SC = "$7"
set TS = "${YR}${MO}${DY}${HR}${MN}${SC}"

# get time
set NOW = `$dateconv -i '%Y%m%d%H%M%S' -f "%s" "$TS"`

if ($?VERBOSE) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","dir":"'$MOTION_DATA_DIR'","camera":"'$CN'","time":'$NOW'}'

## do MQTT
if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  # POST JSON
  set MQTT_TOPIC = "$MOTION_DEVICE_DB/$MOTION_DEVICE_NAME/$CN/found"
  mosquitto_pub -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "$MOTION_MQTT_PORT" -t "$MQTT_TOPIC" -m '{"device":"'$MOTION_DEVICE_NAME'","camera":"'"$CN"'","time":'"$NOW"'}'
  # POST no signal jpg
  set MQTT_TOPIC = "$MOTION_DEVICE_DB/$MOTION_DEVICE_NAME/$CN/image"
  mosquitto_pub -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "$MOTION_MQTT_PORT" -t "$MQTT_TOPIC" -f "/etc/motion/test.jpg"
  # POST no signal gif
  set MQTT_TOPIC = "$MOTION_DEVICE_DB/$MOTION_DEVICE_NAME/$CN/image-animated"
  mosquitto_pub -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "$MOTION_MQTT_PORT" -t "$MQTT_TOPIC" -f "/etc/motion/test.gif"
endif

##
## ALL DONE
##

done:
  if ($?VERBOSE) echo "$0:t $$ -- END" `date` >& /dev/stderr
  if ($?VERBOSE) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","info":"END"}'
  exit
