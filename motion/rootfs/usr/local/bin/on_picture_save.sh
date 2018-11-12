#!/bin/tcsh
setenv DEBUG
setenv VERBOSE
unsetenv USE_MQTT

if ($?VERBOSE) echo "$0:t $$ -- START" `date` >& /dev/stderr

## REQUIRES date utilities
if ( -e /usr/bin/dateutils.dconv ) then
   set dateconv = /usr/bin/dateutils.dconv
else if ( -e /usr/bin/dateconv ) then
   set dateconv = /usr/bin/dateconv
else if ( -e /usr/local/bin/dateconv ) then
   set dateconv = /usr/local/bin/dateconv
else
  if ($?DEBUG && $?USE_MQTT) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "${MOTION_DEVICE_DB}/${MOTION_DEVICE_NAME}/debug" -m '{"ERROR":"'$0:t'","pid":"'$$'","error":"no date converter; install dateutils"}'
  goto done
endif

# 
# %Y = year, %m = month, %d = date,
# %H = hour, %M = minute, %S = second,
# %v = event, %q = frame number, %t = thread (camera) number,
# %D = changed pixels, %N = noise level,
# %i and %J = width and height of motion area,
# %K and %L = X and Y coordinates of motion center
# %C = value defined by text_event
# %f = filename with full path
# %n = number indicating filetype
# Both %f and %n are only defined for on_picture_save, on_movie_start and on_movie_end
#
# on_picture_save on_picture_save.sh %$ %v %f %n %K %L %i %J %D %N
#

# get arguments
set CN = "$1"
set EN = "$2"
set IF = "$3"
set IT = "$4"
set MX = "$5"
set MY = "$6"
set MW = "$7"
set MH = "$8"
set SZ = "$9"
set NL = "$10"

# image identifier, timestamp, seqno
set ID = "$IF:t:r"
set TS = `echo "$ID" | sed 's/\(.*\)-.*-.*/\1/'`
set SN = `echo "$ID" | sed 's/.*-..-\(.*\).*/\1/'`

set NOW = `$dateconv -i '%Y%m%d%H%M%S' -f "%s" "$TS"`

if ($?VERBOSE && $?USE_MQTT) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "${MOTION_DEVICE_DB}/${MOTION_DEVICE_NAME}/debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","data":"'$MOTION_DATA_DIR'","camera":"'$CN'","time":'$NOW'}'

## create JSON
set IJ = "$IF:r.json"

set JSON = '{"device":"'$MOTION_DEVICE_NAME'","camera":"'"$CN"'","type":"jpeg","date":'"$NOW"',"seqno":"'"$SN"'","event":"'"$EN"'","id":"'"$ID"'","center":{"x":'"$MX"',"y":'"$MY"'},"width":'"$MW"',"height":'"$MH"',"size":'$SZ',"noise":'$NL'}'

echo "$JSON" > "$IJ"

if ($?VERBOSE && $?USE_MQTT) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "${MOTION_DEVICE_DB}/${MOTION_DEVICE_NAME}/debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","json":"'"$IJ"'","image":'"$JSON"'}'

## do MQTT
if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set post_pictures = `jq -r '.post_pictures' "$MOTION_JSON_FILE"`
  if ( $post_pictures == "on" ) then
    # POST IMAGE 
    set MQTT_TOPIC = "$MOTION_DEVICE_DB/$MOTION_DEVICE_NAME/$CN/image"
    mosquitto_pub -q 2 -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "$MOTION_MQTT_PORT" -t "$MQTT_TOPIC" -f "$IF"
  endif
  # POST JSON
  set MQTT_TOPIC = "$MOTION_DEVICE_DB/$MOTION_DEVICE_NAME/$CN/event/image"
  mosquitto_pub -q 2 -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "$MOTION_MQTT_PORT" -t "$MQTT_TOPIC" -f "$IJ"
endif

##
## ALL DONE
##

done:
  if ($?VERBOSE) echo "$0:t $$ -- END" `date` >& /dev/stderr
  if ($?VERBOSE && $?USE_MQTT) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "${MOTION_DEVICE_DB}/${MOTION_DEVICE_NAME}/debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","info":"END"}'
  exit
