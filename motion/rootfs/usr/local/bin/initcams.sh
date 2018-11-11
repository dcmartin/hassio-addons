#!/bin/tcsh 

setenv DEBUG
setenv VERBOSE
setenv USE_MQTT

if ($?VERBOSE) echo "$0:t $$ -- START $*" >& /dev/stderr

if ($?MOTION_JSON_FILE == 0) then
  echo "Environment variable unset: MOTION_JSON_FILE"
  exit
endif

if ( -s "$MOTION_JSON_FILE") then
  if ($?VERBOSE) echo "$0:t $$ -- Found configuration JSON file: $MOTION_JSON_FILE" >& /dev/stderr
else
  if ($?DEBUG) echo "$0:t $$ -- Cannot find configuration file: $MOTION_JSON_FILE; exiting" >& /dev/stderr
  exit
endif

## REQUIRES date utilities
if ( -e /usr/bin/dateutils.dconv ) then
   set dateconv = /usr/bin/dateutils.dconv
else if ( -e /usr/bin/dateconv ) then
   set dateconv = /usr/bin/dateconv
else if ( -e /usr/local/bin/dateconv ) then
   set dateconv = /usr/local/bin/dateconv
else
  if ($?USE_MQTT && $?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "${MOTION_DEVICE_DB}/${MOTION_DEVICE_NAME}/debug" -m '{"ERROR":"'$0:t'","pid":'$$',"error":"no date converter; install dateutils"}'
  if ($?DEBUG) echo "$0:t $$ -- no dateutils(1) found; exiting" >& /dev/stderr
  goto done
endif

set cameras = `jq -r '.cameras[].name' "${MOTION_JSON_FILE}"`
set dtime = `date '+%s'`
set dateattr = ( `$dateconv -f '%Y %m %d %H %M %S' -i "%s" "$dtime"` )
foreach c ( $cameras )
  on_camera_found.sh $c $dateattr
end

done:
  if ($?VERBOSE) echo "$0:t $$ -- FINISH" >& /dev/stderr
