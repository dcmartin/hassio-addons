#!/bin/tcsh
echo "$0:t $$ -- START" `date` >& /dev/stderr

setenv DEBUG
setenv VERBOSE

## REQUIRES date utilities
if ( -e /usr/bin/dateutils.dconv ) then
   set dateconv = /usr/bin/dateutils.dconv
else if ( -e /usr/bin/dateconv ) then
   set dateconv = /usr/bin/dateconv
else if ( -e /usr/local/bin/dateconv ) then
   set dateconv = /usr/local/bin/dateconv
else
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"ERROR":"'$0:t'","pid":"'$$'","error":"no date converter; install dateutils"}'
  goto done
endif

## ARGUMENTS
#
# on_event_end.sh %$ %v %Y %m %d %H %M %S
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
if ($#TS && "$TS" != "") then
  set NOW = `$dateconv -i '%Y%m%d%H%M%S' -f "%s" "${TS}"`
else
  goto done
endif

set dir = "${MOTION_TARGET_DIR}/${CN}"

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","time":'$NOW'}'

##
## find all images during event
##

# find all jsons w/in last 5 minutes and return filename only
# set jsons = ( `find "${dir}" -mmin -5 -name "[0-9]*-${EN}.json" -print"` )
set jsons = ( `echo "$dir"/*.json` )

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","jsons":'$#jsons'}'

# find event start
if ($#jsons) then
  set lastjson = $jsons[$#jsons]
  if (! -s "$lastjson") then
    if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":"'$$'","dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","error":"'"$lastjson:t"' is empty"}'
    goto done
  else
    set START = `jq -r '.start' $lastjson`
    if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","start":'$START'}'
  endif
  # set jpgs = ( `find "${dir}" -name "*.jpg" -newer "$lastjson" -print"` )
  set jpgs = ( `echo "${dir}"/*.jpg` )
else
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":"'$$'","dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","error":"no JSONS '"$?jsons"'"}'
  goto done
endif

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","jpgs":"'"$#jpgs"'"}'

set frames = ()
set interval = 0
if ($#jpgs) then
  @ i = $#jpgs
  while ($i > 0) 
    set jpg = $jpgs[$i]
    set LAST = `echo "$jpg:t:r" | sed 's/\(.*\)-.*-.*/\1/'`
    set LAST = `$dateconv -i '%Y%m%d%H%M%S' -f "%s" $LAST`
    @ seconds = $LAST - $START
    if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","camera":"'$CN'","jpg":"'$jpg'","interval":'$seconds'}'
    if ( $seconds >= 0) then
      if ($?MOTION_EVENT_INTERVAL) then
        if ( $seconds > $MOTION_EVENT_INTERVAL ) break
      endif
      set frames = ( "$jpg:t:r" $frames )
      if ($seconds > $interval) set interval = $seconds
    else
      break
    endif
    @ i--
  end
else
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":"'$$'","camera":"'$CN'","time":'$NOW',"error":"no jpgs"}'
  goto done
endif

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","camera":"'$CN'","time":'$NOW',"frames":'$#frames',"interval":'$interval'}'

if ($#frames) then
  set images = `echo "$frames" | sed 's/ /,/g' | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g'`
  set images = '['"$images"']'
else
  set images = "null"
endif

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","camera":"'$CN'","event":"'${EN}'","interval":'$interval',"images":'"$images"'}'

## JSON
jq -c '.interval='"${interval}"'|.end='${NOW}'|.date='`date +%s`'|.images='"$images" "${lastjson}" > "${lastjson}.$$"
if ( ! -s "${lastjson}.$$" ) then
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":"'$$'","camera":"'$CN'","event":"'${EN}'","lastjson":"'"$lastjson"'"}'
  rm -f "${lastjson}.$$"
  goto done
else
  mv -f "${lastjson}.$$" "${lastjson}"
endif

## do MQTT
if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/event/end"
  mosquitto_pub -i "${MOTION_DEVICE_NAME}" -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "${MQTT_TOPIC}" -f "${lastjson}"
endif

###
### PROCESS FRAMES
###

set tmpdir = `mktemp`
mkdir -p $tmpdir

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","tmpdir":"'"$tmpdir"'"}'

## AVERAGE IMAGE
set average = "$tmpdir/$lastjson:t:r-average.png"
pushd "$dir"
convert $frames -average $average
popd
if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","average":"'"$average"'"}'

if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/image-average"
  mosquitto_pub -r -i "${MOTION_DEVICE_NAME}" -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "$MQTT_TOPIC" -f "$average"
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","topic":"'"$MQTT_TOPIC"'"}'
endif


## BLENDED IMAGE
set blend = "$tmpdir/$lastjson:t:r-blend.png"
pushd "$dir"
convert $frames -compose blend -define 'compose:args=50' -alpha on -composite $blend
popd
if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","blend":"'"$blend"'"}'

if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/image-blend"
  mosquitto_pub -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "${MOTION_MQTT_PORT}" -t "$MQTT_TOPIC" -f "$blend"
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":"'$$'","topic":"'"$MQTT_TOPIC"'"}'
endif

##
##  PROCESS COMPOSITE and ANIMATED GIF/MASK
##

# calculate all frame-to-frame differences
@ fuzz = 20
@ t = 0
@ i = 1
set ps = ()
set diffs = ()
while ( $i <= $#frames )
    set diffs = ( $diffs "$tmpdir/$frames[$i]:t-mask.jpg" )
    # calculate difference
    set p = ( `compare -metric fuzz -fuzz "$fuzz"'%' "$dir/$frames[$i]" "$average" -compose src -highlight-color white -lowlight-color black "$diffs[$#diffs]" |& awk '{ print $1 }'` )
    # keep track of differences
    set ps = ( $ps $p:r )
    @ t += $ps[$#ps]
    @ i++
end
# calculate average difference
set a = ( `echo "$t / $#ps" | bc` )

# subset to key frames
if ($?MOTION_IMAGE_KEY_FRAMES) then
  set kframes = ()
  set kdiffs = ()
  @ i = 1
  while ( $i <= $#diffs )
    # keep track of frames w/ change > average
    if ($ps[$i] > $a) then
      set kframes = ( $frames[$i] $kframes )
      set kdiffs = ( $diffs[$i] $kdiffs )
    endif
    @ i++
  end
  set frames = ( $kframes )
  set diffs = ( $kdiffs )
endif

## COMPOSITE KEY FRAMES AGAINST AVERAGE USING MASK
set composite = $tmpdir/$lastjson:t:r-composite.jpg
cp "$average" "$composite"
@ i = 1
while ( $i <= $#frames )
    set c = $composite:r.$i.jpg
    composite $dir/$frames[$i] $composite $diffs[$i] $c
    mv -f $c $composite
    @ i++
end
if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/image-composite"
  mosquitto_pub -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "${MOTION_MQTT_PORT}" -t "$MQTT_TOPIC" -f "$composite"
endif

# calculate milliseconds between frames (fps should come from camera)
set fps = 10
set ms = `echo "$fps / 60.0 * 100.0" | bc -l`
set ms = $ms:r

## PRODUCE ANIMATED GIF/MASK
set gif = $tmpdir/$lastjson:t:r.gif
pushd $dir ; convert -loop 0 -delay $ms $frames $gif ; popd
if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/image-animated"
  mosquitto_pub -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "${MOTION_MQTT_PORT}" -t "$MQTT_TOPIC" -f "$gif"
endif

set mask = $tmpdir/$lastjson:t:r.mask.gif
convert -loop 1 -delay $ms $diffs $mask
if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/image-animated-mask"
  mosquitto_pub -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "${MOTION_MQTT_PORT}" -t "$MQTT_TOPIC" -f "$mask"
endif

## cleanup
rm -fr $tmpdir

##
## ALL DONE
##

done:
  echo "$0:t $$ -- END" `date` >& /dev/stderr
  exit
