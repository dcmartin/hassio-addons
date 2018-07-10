#!/bin/tcsh
echo "$0:t $$ -- START" `date` >& /dev/stderr

# setenv DEBUG
# setenv VERBOSE

## REQUIRES date utilities
if ( -e /usr/bin/dateutils.dconv ) then
   set dateconv = /usr/bin/dateutils.dconv
else if ( -e /usr/bin/dateconv ) then
   set dateconv = /usr/bin/dateconv
else if ( -e /usr/local/bin/dateconv ) then
   set dateconv = /usr/local/bin/dateconv
else
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"'$0:t'":"'$$'","error":"no date converter; install dateutils"}'
  goto done
endif

## ARGUMENTS
#
# on_event_end.sh %v %Y %m %d %H %M %S
#
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

# in seconds
set NOW = `$dateconv -i '%Y%m%d%H%M%S' -f "%s" "${YR}${MO}${DY}${HR}${MN}${SC}"`

##
## PROCESS MOTION_EVENT_GAP
##

set frames = ()
foreach jpg ( `find "${MOTION_TARGET_DIR}" -name "${YR}${MO}${DY}${HR}${MN}*-${EN}-*.jpg" -printf "%f\n"` )
    set LAST = `echo "$jpg:r" | sed 's/\(.*\)-.*-.*/\1/'`
    set LAST = `$dateconv -i '%Y%m%d%H%M%S' -f "%s" $LAST`
    @ INTERVAL = $NOW - $LAST

    if ( $INTERVAL > ${MOTION_EVENT_INTERVAL} ) then
      break
    else if ( $INTERVAL >= 0) then
      set frames = ( "$jpg:r" $frames )
    else
      break
    endif
end

if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"'$0:t'":"'$$'","camera":"'$CN'","frames":'$#frames'}'

if ($#frames) then
  set images = `echo "$frames" | sed 's/ /,/g' | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g'`
  set images = '['"$images"']'
else
  set images = "null"
endif

if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"'$0:t'":"'$$'","camera":"'$CN'","images":"'"$images"'"}'

## JSON
set ID = "${YR}${MO}${DY}${HR}${MN}${SC}-${EN}"
set EJ = "${MOTION_TARGET_DIR}/${ID}.json"
echo '{"camera":"'"${CN}"'","time":'"${NOW}"',"date":'`date +%s`',"event":"'"${EN}"'","images":'"$images"'}' > "${EJ}"

if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"'$0:t'":"'$$'","camera":"'"${CN}"'","time":'"${NOW}"',"date":'`date +%s`',"event":"'"${EN}"'","images":'"$images"'}'

## do MQTT
if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/event"
  mosquitto_pub -i "${MOTION_DEVICE_NAME}" -h "${MOTION_MQTT_HOST}" -t "${MQTT_TOPIC}" -f "${EJ}"
endif

done:

echo "$0:t $$ -- END" `date` >& /dev/stderr
