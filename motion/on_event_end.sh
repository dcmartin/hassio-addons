#!/bin/tcsh
echo "$0:t $$ -- START" `date` >& /dev/stderr

setenv DEBUG
# setenv VERBOSE

## REQUIRES date utilities
if ( -e /usr/bin/dateutils.dconv ) then
   set dateconv = /usr/bin/dateutils.dconv
else if ( -e /usr/bin/dateconv ) then
   set dateconv = /usr/bin/dateconv
else if ( -e /usr/local/bin/dateconv ) then
   set dateconv = /usr/local/bin/dateconv
else
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"ERROR":"'$0:t'","pid":'$$',"error":"no date converter; install dateutils"}'
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

set dir = "${MOTION_DATA_DIR}/${CN}"

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","time":'$NOW'}'

##
## find all images during event
##

# find all event jsons (YYYYMMDDHHMMSS-##.json)
set jsons = ( `echo "$dir"/??????????????"-${EN}".json` )

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","jsons":'$#jsons'}'

# find event start
if ($#jsons) then
  set lastjson = $jsons[$#jsons]
  if (! -s "$lastjson") then
    if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","error":"'"$lastjson:t"' is empty"}'
    goto done
  else
    set START = `jq -r '.start' $lastjson`
    if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","start":'$START'}'
  endif
  set jpgs = ( `echo "${dir}"/*"-${EN}-"*.jpg` )
else
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","error":"no JSONS '"$?jsons"'"}'
  goto done
endif

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"dir":"'${dir}'","camera":"'$CN'","event":"'$EN'","candidates":'"$#jpgs"'}'

set interval = `jq -r '.interval' "$MOTION_JSON_FILE"`
if ("$interval" == "null" || $#interval == 0) set interval = 0
if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"interval":'"$interval"'}'

set frames = ()
set elapsed = 0
if ($#jpgs) then
  @ i = $#jpgs
  while ($i > 0) 
    set jpg = "$jpgs[$i]"
    set jsn = "$jpg:r.json"
    if ( ! -s "$jsn" ) then
      if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"camera":"'$CN'","jpg":"'$jpg'","error":"cannot find JSON ('"$jsn"')"}'
      @ i--
      continue
    endif
    set LAST = `jq -r '.time' "$jsn"`
    # set LAST = `echo "$jpg:t:r" | sed 's/\(.*\)-.*-.*/\1/'`
    # set LAST = `$dateconv -i '%Y%m%d%H%M%S' -f "%s" $LAST`
    @ seconds = $LAST - $START
    if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"json":"'"$jsn"'","elapsed":'$seconds'}'
    # test for breaking conditions
    if ( $seconds < 0 ) break
    if ( $interval > 0 && $seconds > $interval) break
    # add frame to this interval
    set frames = ( "$jpg:t:r" $frames )
    if ( $seconds > $elapsed ) set elapsed = $seconds
    @ i--
  end
else
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"camera":"'$CN'","time":'$NOW',"error":"no jpgs"}'
  goto done
endif

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"camera":"'$CN'","time":'$NOW',"frames":'$#frames',"elapsed":'$elapsed'}'

if ($#frames) then
  set images = `echo "$frames" | sed 's/ /,/g' | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g'`
  set images = '['"$images"']'
else
  set images = "null"
endif

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"camera":"'$CN'","event":"'${EN}'","elapsed":'$elapsed',"images":'"$images"'}'

## JSON
set date = `date +%s`
set JSON = `jq '.elapsed='"$elapsed"'|.end='${NOW}'|.date='"$date"'|.images='"$images" "$lastjson"`

if ( "$JSON" == "" ) then
  if ($?DEBUG) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"camera":"'$CN'","event":"'"$EN"'","FAILED":"'"$lastjson"'"}'
  goto done
else
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"event":'"$JSON"'}'
  echo "$JSON" >! "$lastjson"
endif

## do MQTT
if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/event/end"
  mosquitto_pub -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "$MOTION_MQTT_PORT" -t "$MQTT_TOPIC" -f "$lastjson"
  if ($?VERBOSE) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"topic":"'$MQTT_TOPIC'","JSON":"'"$lastjson"'"}'
endif

###
### PROCESS FRAMES
###

set jpgs = ()
foreach f ( $frames )
  set jpg = "$dir/$f.jpg" 

  # get image information
  set info = ( `identify "$jpg" | awk '{ printf("{\"type\":\"%s\",\"size\":\"%s\",\"bps\":\"%s\",\"color\":\"%s\"}", $2, $3, $5, $6) }' | jq '.'` )
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"jpg":"'"$jpg"'","info":'"${info}"'}'
  if (-e "$jpg:r.json") then
    set json = ( `jq '.info='"$info"'|.end='"${NOW}" "$jpg:r.json"` )
    if ($#json) then
      echo "$json" >! "$jpg:r.json"
      set jpgs = ( $jpgs "$jpg" )
    else
      if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"jpg":"'"$jpg"'","error":"JSON failed"}'
    endif
  else
    if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"jpg":"'"$jpg"'","error":"JSON not found"}'
  endif
end
if ($#jpgs) then
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"njpgs":'$#jpgs'}'
else
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"error":"insufficient jpegs"}'
  goto done
endif

##
## do not make animations from less than this # of frames
##

set minimum_animate = `jq -r '.minimum_animate' "$MOTION_JSON_FILE"`
if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"minimum_animate":"'"$minimum_animate"'"}'

if ($#jpgs < $minimum_animate || $#jpgs < 2) then
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"count":'$#jpgs',"minimum":'$minimum_animate'}'
  goto done
endif

###
### PROCESS multiple jpgs
###

# use temporary direction in target_dir; should be setup as RAM disk
set tmpdir = "/tmpfs/$0:t/$$"
mkdir -p $tmpdir

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"tmpdir":"'"$tmpdir"'"}'

## AVERAGE IMAGE
set average = "$tmpdir/$lastjson:t:r-average.jpg"
convert $jpgs -average $average >&! /tmp/$$.out
if ( -s "$average") then
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"average":"'"$average"'"}'
else
  set out = `cat "/tmp/$$.out"`
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"error":"'"$out"'"}'
  rm -f "/tmp/$$.out"
  goto done
endif

if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/image-average"
  mosquitto_pub -r -i "${MOTION_DEVICE_NAME}" -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "$MQTT_TOPIC" -f "$average"
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"topic":"'"$MQTT_TOPIC"'"}'
endif

##
##  PROCESS COMPOSITE and ANIMATED GIF/MASK
##

# calculate all frame-to-frame differences
set fuzz = 20
set avgdiff = 0
set maxdiff = 0
set changed = ()
set avgsize = 0
set maxsize = 0
set biggest = ()
set totaldiff = 0
set totalsize = 0
set i = 1
set ps = ()
set diffs = ()

if ($#jpgs > 1) then
  while ( $i <= $#jpgs )
    # calculate difference
    set diffs = ( $diffs "$tmpdir/$jpgs[$i]:t-mask.jpg" )
    set p = ( `compare -metric fuzz -fuzz "$fuzz"'%' "$jpgs[$i]" "$average" -compose src -highlight-color white -lowlight-color black "$diffs[$#diffs]" |& awk '{ print $1 }'` )
    if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"jpg":"'"$jpgs[$i]"'","pixels":'$p'}'
    # keep track of differences
    set ps = ( $ps $p:r )
    @ totaldiff += $ps[$#ps]
    if ( $maxdiff < $p:r ) then
      set maxdiff = $p:r
      set changed = "$jpgs[$i]"
    endif
    # retrieve size
    set size = `jq -r '.size' "$jpgs[$i]:r".json`
    if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"jpg":"'"$jpgs[$i]"'","size":"'$size'"}'
    # keep track of size
    @ totalsize += $size
    if ( $maxsize < $size ) then
      set maxsize = $size
      set biggest = "$jpgs[$i]"
    endif
    # increment and continue
    @ i++
  end
else
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"error":"insufficient jpgs"}'
endif

# calculate average difference
if ($#ps) @ avgdiff = $totaldiff / $#ps
if ($#ps) @ avgsize = $totalsize / $#ps
if ($?VERBOSE) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"diff":'$avgdiff',"size":'$avgsize'}'

### GET post_pictures
set post_pictures = `jq -r '.post_pictures' "$MOTION_JSON_FILE"`
if ($?VERBOSE) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"post_pictures":"'"$post_pictures"'"}'

set IF = ()
switch ( "$post_pictures" )
  case "off":
    breaksw
  case "center":
    @ h = $#ps / 2
    if ($h > 1 && $h <= $#ps) set IF = "$jpgs[$h]"
    breaksw
  case "best":
    if ($#biggest) set IF = "$biggest"
    breaksw
  case "most":
    if ($#changed) set IF = "$changed"
    breaksw
  case "last":
    set IF = "$jpgs[$#jpgs]"
    breaksw
  case "first":
  default:
    set IF = "$jpgs[1]"
    breaksw
endsw

if ($#IF && -s "$IF" && $?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/$MOTION_DEVICE_NAME/$CN/image"
  mosquitto_pub -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "$MOTION_MQTT_PORT" -t "$MQTT_TOPIC" -f "$IF"
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"topic":"'"$MQTT_TOPIC"'","image":"'${IF}'"}'
else
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"post":"'"$MOTION_POST_PICTURES"',"topic":"'"$MQTT_TOPIC"'","image":"'${IF}'"}'
endif

#
# subset to key frames
#

if ($?MOTION_KEY_FRAMES) then
  if ($avgdiff > 0 && $#diffs && $#jpgs ) then
    set kjpgs = ()
    set kdiffs = ()
    @ i = 1
    while ( $i <= $#diffs )
      # keep track of jpgs w/ change > average
      if ($ps[$i] > $avgdiff) then
        set kjpgs = ( $jpgs[$i] $kjpgs )
        set kdiffs = ( $diffs[$i] $kdiffs )
      endif
      @ i++
    end
    set jpgs = ( $kjpgs )
    set diffs = ( $kdiffs )
  endif
endif

## COMPOSITE KEY FRAMES AGAINST AVERAGE USING MASK
set composite = "$tmpdir/$lastjson:t:r-composite.jpg"
cp "$average" "$composite"
@ i = 1
while ( $i <= $#jpgs )
    set c = $composite:r.$i.jpg
    composite "$jpgs[$i]" $composite "$diffs[$i]" $c
    mv -f $c $composite
    @ i++
end
if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"composite":"'"$composite"'"}'

if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/image-composite"
  mosquitto_pub -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "${MOTION_MQTT_PORT}" -t "$MQTT_TOPIC" -f "$composite"
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"topic":"'"$MQTT_TOPIC"'"}'
endif

## determine frames per second for this camera
set fps = ( `jq '.cameras[]|select(.name=="'"$CN"'").fps' "$MOTION_JSON_FILE"` )
if ($#fps == 0) then
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"WARN":"camera '"$CN"' not found in '"${MOTION_JSON_FILE}"'"}'
  set fps = `echo "$#frames / $elapsed" | bc -l`
  set rem = `echo $fps:e | sed "s/\(.\).*/\1/"`
  if ($rem >= 5) then
    @ fps = $fps:r + 1
  else
    set fps = $fps:r
  endif
endif
if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"FPS":"'$fps'"}'

# calculate milliseconds between calculated from remaining frames 
set ms = `echo "$fps / 60.0 * 100.0" | bc -l`
set ms = $ms:r

## animated GIF
set gif = "$tmpdir/$lastjson:t:r.gif"
convert -loop 0 -delay $ms $jpgs $gif
if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"gif":"'"$gif"'"}'

if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/image-animated"
  mosquitto_pub -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "${MOTION_MQTT_PORT}" -t "$MQTT_TOPIC" -f "$gif"
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"topic":"'"$MQTT_TOPIC"'"}'
endif

## animated GIF mask
set mask = $tmpdir/$lastjson:t:r.mask.gif
pushd "$dir"
convert -loop 0 -delay $ms $diffs $mask
popd
if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"mask":"'"$mask"'"}'

if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/image-animated-mask"
  mosquitto_pub -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "${MOTION_MQTT_PORT}" -t "$MQTT_TOPIC" -f "$mask"
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"topic":"'"$MQTT_TOPIC"'"}'
endif

if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"tmpdir":"'"$tmpdir"'"}'

## BLENDED IMAGE
set blend = "$tmpdir/$lastjson:t:r-blend.jpg"
convert $jpgs -compose blend -define 'compose:args=50' -alpha on -composite $blend
if ( -s "$blend") then
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"blend":"'"$blend"'"}'
else
  if ($?DEBUG) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'$0:t'","pid":'$$',"blend":"FAILED"}'
  goto done
endif

if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MQTT_TOPIC = "motion/${MOTION_DEVICE_NAME}/${CN}/image-blend"
  mosquitto_pub -r -i "$MOTION_DEVICE_NAME" -h "$MOTION_MQTT_HOST" -p "${MOTION_MQTT_PORT}" -t "$MQTT_TOPIC" -f "$blend"
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"topic":"'"$MQTT_TOPIC"'"}'
endif

##
## ALL DONE
##

done:
  if ($?tmpdir) then
    rm -fr $tmpdir
  endif
  echo "$0:t $$ -- END" `date` >& /dev/stderr
  if ($?VERBOSE) mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'$0:t'","pid":'$$',"info":"END"}'
  exit
