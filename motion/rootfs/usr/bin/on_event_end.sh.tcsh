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
  if ($?DEBUG) echo "$0:t $$ -- no dateutils(1) found; exiting" >& /dev/stderr
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

if ($?VERBOSE) echo "$0:t $$ -- processing $dir for camera $CN event $EN date $NOW" >& /dev/stderr

##
## find all images during event
##

# find all event jsons (YYYYMMDDHHMMSS-##.json)
set jsons = ( `echo "$dir"/??????????????"-${EN}".json` )

if ($?VERBOSE) echo "$0:t $$ -- found $#jsons JSON for camera $CN in $dir for event $EN" >& /dev/stderr

# find event start
if ($#jsons) then
  set lastjson = $jsons[$#jsons]
  if (! -s "$lastjson") then
    if ($?DEBUG) echo "$0:t $$ -- No last JSON found; exiting" >& /dev/stderr
    goto done
  else
    set START = `jq -r '.start' $lastjson`
    if ($?VERBOSE) echo "$0:t $$ -- Identified start date $START for JSON $lastjson" >& /dev/stderr
  endif
  set jpgs = ( `echo "${dir}"/*"-${EN}-"*.jpg` )
else
  if ($?DEBUG) echo "$0:t $$ -- Found no JSON; exiting" >& /dev/stderr
  goto done
endif

if ($?VERBOSE) echo "$0:t $$ -- Found $#jpgs candidate images for camera $CN in $dir for event $EN" >& /dev/stderr

set interval = `jq -r '.interval' "$MOTION_JSON_FILE"`
if ("$interval" == "null" || $#interval == 0) set interval = 0
if ($?VERBOSE) echo "$0:t $$ -- Interval specified as $interval" >& /dev/stderr

set frames = ()
set elapsed = 0
if ($#jpgs) then
  @ i = $#jpgs
  while ($i > 0) 
    set jpg = "$jpgs[$i]"
    set jsn = "$jpg:r.json"
    if ( ! -s "$jsn" ) then
      if ($?DEBUG) echo "$0:t $$ -- Cannot locate JSON $jsn for camera $CN image $jpg; skipping.." >& /dev/stderr
      @ i--
      continue
    endif
    set THIS = `echo "$jpg:t:r" | sed 's/\(.*\)-.*-.*/\1/'`
    set THIS = `$dateconv -i '%Y%m%d%H%M%S' -f "%s" $THIS`
    if ($?LAST == 0) set LAST = $THIS
    @ seconds = $THIS - $START
    if ($?VERBOSE) echo "$0:t $$ -- Located JSON $jsn for image $jpg; elapsed $seconds" >& /dev/stderr
    # test for breaking conditions
    if ( $seconds < 0 ) break
    if ( $interval > 0 && $seconds > $interval) break
    # add frame to this interval
    set frames = ( "$jpg:t:r" $frames )
    if ( $seconds > $elapsed ) set elapsed = $seconds
    @ i--
  end
else
  if ($?DEBUG) echo "$0:t $$ -- No candidate images ($#jpgs) found for camera $CN from date $NOW; exiting" >& /dev/stderr
  goto done
endif

if ($?VERBOSE) echo "$0:t $$ -- Found $#frames frames for camera $CN at date $NOW elapsed $elapsed" >& /dev/stderr

if ($#frames) then
  set images = `echo "$frames" | sed 's/ /,/g' | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g'`
  set images = '['"$images"']'
else
  set images = "null"
endif

if ($?VERBOSE) echo "$0:t $$ -- Found $#frames images for camera $CN event $EN $images" >& /dev/stderr

## JSON
set date = `date +%s`
set JSON = `jq '.elapsed='"$elapsed"'|.end='${LAST}'|.date='"$date"'|.images='"$images" "$lastjson"`

if ( "$JSON" == "" ) then
  if ($?DEBUG) echo "$0:t $$ -- Failed to update JSON $lastjson; exiting: $JSON" >& /dev/stderr
  goto done
else
  if ($?VERBOSE) echo "$0:t $$ -- Updated $lastjson with $JSON" >& /dev/stderr
  echo "$JSON" >! "$lastjson"
endif

## do MQTT
if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MOTION_MQTT_TOPIC = "$MOTION_GROUP/${MOTION_DEVICE}/${CN}/event/end"
  mosquitto_pub -q 2 -r -i "$MOTION_DEVICE" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "$MOTION_MQTT_HOST" -p "$MOTION_MQTT_PORT" -t "$MOTION_MQTT_TOPIC" -f "$lastjson"
  if ($?VERBOSE) echo "$0:t $$ -- Posted MQTT file $lastjson to host $MOTION_MQTT_HOST topic $MOTION_MQTT_TOPIC" >& /dev/stderr
endif

###
### PROCESS 
###

set jpgs = ()
foreach f ( $frames )
  set jpg = "$dir/$f.jpg" 

  # get image information
  set info = ( `identify "$jpg" | awk '{ printf("{\"type\":\"%s\",\"size\":\"%s\",\"bps\":\"%s\",\"color\":\"%s\"}", $2, $3, $5, $6) }' | jq '.'` )
  if ($?VERBOSE) echo "$0:t $$ -- Identified $jpg as $info" >& /dev/stderr
  if (-e "$jpg:r.json") then
    if ($?VERBOSE) echo "$0:t $$ -- Found JSON $jpg:r.json; updating with $info" >& /dev/stderr
    jq '.info='"$info"'|.end='"${NOW}" "$jpg:r.json" >! /tmp/$0:t.$$.json
    if (-s /tmp/$0:t.$$.json) then
      mv /tmp/$0:t.$$.json "$jpg:r.json"
      set jpgs = ( $jpgs "$jpg" )
    else
      rm -f /tmp/$0:t.$$.json
      if ($?DEBUG) echo "$0:t $$ -- JSON failed; skipping" >& /dev/stderr
      continue
    endif
  else
    if ($?DEBUG) echo "$0:t $$ -- Failed to find JSON $jpg:r.json; skipped" >& /dev/stderr
  endif
end

if ($#jpgs) then
  if ($?VERBOSE) echo "$0:t $$ -- Found $#jpgs images from $#frames frames" >& /dev/stderr
else
  if ($?DEBUG) echo "$0:t $$ -- Found zero ($#jpgs) images from $#frames frames; exiting" >& /dev/stderr
  goto done
endif

###
### PROCESS IMAGES
###

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
set ps = ()
set diffs = ()

## calculate average and diffs
if ($#jpgs > 1) then
  set tmpdir = "/tmpfs/$0:t/$$"
  mkdir -p $tmpdir


  ## AVERAGE 
  set average = "$tmpdir/$lastjson:t:r"'-average.jpg'
  convert $jpgs -average $average >&! /tmp/$$.out
  if ( -s "$average") then
    if ($?VERBOSE) echo "$0:t $$ -- Calculated average image $average from $#jpgs JPEGS" >& /dev/stderr
  else
    set out = `cat "/tmp/$$.out"`
    if ($?DEBUG) echo "$0:t $$ -- Failed to calculate average image from $#jpgs JPEGS" `cat $out` >& /dev/stderr
    rm -f "/tmp/$$.out"
    goto done
  endif
  if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
    set MOTION_MQTT_TOPIC = "$MOTION_GROUP/${MOTION_DEVICE}/${CN}/image-average"
    mosquitto_pub -q 2 -r -i "${MOTION_DEVICE}" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "$MOTION_MQTT_TOPIC" -f "$average"
    if ($?VERBOSE) echo "$0:t $$ -- Posted file $average to host $MOTION_MQTT_HOST topic $MOTION_MQTT_TOPIC" >& /dev/stderr
  endif

  ## DIFFS
  set i = 1
  while ( $i <= $#jpgs )
    # calculate difference
    set diffs = ( $diffs "$tmpdir/$jpgs[$i]:t:r"'-mask.jpg' )
    set p = ( `compare -metric fuzz -fuzz "$fuzz"'%' "$jpgs[$i]" "$average" -compose src -highlight-color white -lowlight-color black "$diffs[$#diffs]" |& awk '{ print $1 }'` )
    # keep track of differences
    set ps = ( $ps $p:r )
    @ totaldiff += $ps[$#ps]
    if ( $maxdiff < $p:r ) then
      set maxdiff = $p:r
      set changed = "$jpgs[$i]"
    endif
    # retrieve size
    set size = `jq -r '.size' "$jpgs[$i]:r".json`
    # keep track of size
    @ totalsize += $size
    if ( $maxsize < $size ) then
      set maxsize = $size
      set biggest = "$jpgs[$i]"
    endif
    # increment and continue
    @ i++
  end
  # calculate average difference
  if ($#ps) @ avgdiff = $totaldiff / $#ps
  if ($#ps) @ avgsize = $totalsize / $#ps
  if ($?VERBOSE) echo "$0:t $$ -- Average difference: $avgdiff; size: $avgsize from $#jpgs JPEGS" >& /dev/stderr

  ## BLEND
  set blend = "$tmpdir/$lastjson:t:r"'-blend.jpg'
  convert $jpgs -compose blend -define 'compose:args=50' -alpha on -composite $blend
  if ( ! -s "$blend") then
    if ($?DEBUG) echo "$0:t $$ -- Failed to convert $#jpgs into a blend: $blend" >& /dev/stderr
  else if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
    set MOTION_MQTT_TOPIC = "$MOTION_GROUP/${MOTION_DEVICE}/${CN}/image-blend"
    mosquitto_pub -q 2 -r -i "$MOTION_DEVICE" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "$MOTION_MQTT_HOST" -p "${MOTION_MQTT_PORT}" -t "$MOTION_MQTT_TOPIC" -f "$blend"
    if ($?VERBOSE) echo "$0:t $$ -- ${MOTION_MQTT_HOST} $MOTION_MQTT_TOPIC" >& /dev/stderr
  endif

  ## COMPOSITE 

  # composite these images
  set srcs = ( $jpgs )
  set masks = ( $diffs )
  # start with average
  set composite = "$tmpdir/$lastjson:t:r"'-composite.jpg'
  cp -f "$average" "$composite"
  # test if key frame only
  if ($?ALL_FRAMES == 0) then
    set kjpgs = ()
    set kdiffs = ()
    @ i = 1
    while ( $i <= $#jpgs )
      # keep track of jpgs w/ change > average
      if ($ps[$i] > $avgdiff) then
        if ($?VERBOSE) echo "$0:t $$ -- KEY ($i) SIZE ($ps[$i]) - $jpgs[$i] $diffs[$i]" >& /dev/stderr
        set kjpgs = ( $kjpgs $jpgs[$i] )
        set kdiffs = ( $kdiffs $diffs[$i] )
      endif
      @ i++
    end
    if ($?VERBOSE) echo "$0:t $$ -- key frames $#kjpgs of total frames $#frames" >& /dev/stderr
    set srcs = ( $kjpgs )
    set masks = ( $kdiffs )
  endif
  # loop
  if ($?DEBUG) echo "$0:t $$ -- Compositing $#srcs sources with $#masks masks" >& /dev/stderr
  @ i = 1
  while ( $i <= $#srcs )
    set c = $composite:r.$i.jpg
    if ($?VERBOSE) echo "$0:t $$ -- Compositing ${i} ${c} from $srcs[$i] and $masks[$i]" >& /dev/stderr
    convert "$composite" "$srcs[$i]" "$masks[$i]" -composite "$c"
    mv -f $c $composite
    @ i++
  end
  # success or failure
  if (! -s "$composite") then
    if ($?DEBUG) echo "$0:t $$ -- Failed to convert $#jpgs into a composite: $composite" >& /dev/stderr
  else if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
    set MOTION_MQTT_TOPIC = "$MOTION_GROUP/${MOTION_DEVICE}/${CN}/image-composite"
    mosquitto_pub -q 2 -r -i "$MOTION_DEVICE" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "$MOTION_MQTT_HOST" -p "${MOTION_MQTT_PORT}" -t "$MOTION_MQTT_TOPIC" -f "$composite"
    if ($?VERBOSE) echo "$0:t $$ -- Posted file $composite to host ${MOTION_MQTT_HOST} topic $MOTION_MQTT_TOPIC" >& /dev/stderr
  endif
endif

### GET post_pictures
set post_pictures = `jq -r '.post_pictures' "$MOTION_JSON_FILE"`
if ($?VERBOSE) echo "$0:t $$ -- Posting pictures specified as: $post_pictures" >& /dev/stderr

set IF = ()
switch ( "$post_pictures" )
  case "first":
    set IF = "$jpgs[1]"
    breaksw
  case "off":
    set IF = ()
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
  default:
  case "center":
    @ h = $#ps / 2
    if ($h > 1 && $h <= $#ps) set IF = "$jpgs[$h]"
    breaksw
endsw

###
### POST EVENT PICTURE
###

if ($#IF && -s "$IF" && $?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
  set MOTION_MQTT_TOPIC = "$MOTION_GROUP/$MOTION_DEVICE/$CN/image/end"
  mosquitto_pub -q 2 -r -i "$MOTION_DEVICE" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "$MOTION_MQTT_HOST" -p "$MOTION_MQTT_PORT" -t "$MOTION_MQTT_TOPIC" -f "$IF"
  if ($?VERBOSE) echo "$0:t $$ -- Posting file $IF to host $MOTION_MQTT_HOST topic $MOTION_MQTT_TOPIC" >& /dev/stderr
else
  if ($?DEBUG) echo "$0:t $$ -- No file specified to post; $IF" >& /dev/stderr
endif

##
## ANIMATE
##

set minimum_animate = `jq -r '.minimum_animate' "$MOTION_JSON_FILE"`
if ($?VERBOSE) echo "$0:t $$ -- Minimum animate specified as $minimum_animate; number images is $#jpgs" >& /dev/stderr

if ($minimum_animate <= $#jpgs && $#jpgs > 1) then
  ## find frames per second for this camera
  set fps = ( `jq '.cameras[]|select(.name=="'"$CN"'").fps' "$MOTION_JSON_FILE"` )
  if ($#fps == 0) then
    if ($?DEBUG) echo "$0:t $$ -- Warning!  Did not find camera $CN in $MOTION_JSON_FILE" >& /dev/stderr
    set fps = `echo "$#frames / $elapsed" | bc -l`
    set rem = `echo $fps:e | sed "s/\(.\).*/\1/"`
    if ($rem >= 5) then
      @ fps = $fps:r + 1
    else
      set fps = $fps:r
    endif
  endif
  # calculate ticks (1/100 second)
  set delay = `echo "100.0 / $fps" | bc -l`
  set delay = $delay:r
  if ($?VERBOSE) echo "$0:t $$ -- Calculated delay at $delay ticks based on camera $CN at $fps FPS" >& /dev/stderr

  ## animated GIF
  set gif = "$tmpdir/$lastjson:t:r.gif"
  convert -loop 0 -delay $delay $jpgs $gif
  if (! -s "$gif") then
    if ($?DEBUG) echo "$0:t $$ -- Failed to convert $#jpgs into a gif: $gif" >& /dev/stderr
  else if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
    set MOTION_MQTT_TOPIC = "$MOTION_GROUP/${MOTION_DEVICE}/${CN}/image-animated"
    mosquitto_pub -q 2 -r -i "$MOTION_DEVICE" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "$MOTION_MQTT_HOST" -p "${MOTION_MQTT_PORT}" -t "$MOTION_MQTT_TOPIC" -f "$gif"
    if ($?VERBOSE) echo "$0:t $$ -- Posted file $gif to host ${MOTION_MQTT_HOST} topic $MOTION_MQTT_TOPIC" >& /dev/stderr
  endif

  ## animated GIF mask
  set mask = $tmpdir/$lastjson:t:r.mask.gif
  pushd "$dir" >& /dev/null
  convert -loop 0 -delay $delay $diffs $mask
  popd >& /dev/null
  if (! -s "$mask") then
    if ($?DEBUG) echo "$0:t $$ -- Failed to convert $#jpgs into a mask: $mask" >& /dev/stderr
  else if ($?MOTION_MQTT_HOST && $?MOTION_MQTT_PORT) then
    set MOTION_MQTT_TOPIC = "$MOTION_GROUP/${MOTION_DEVICE}/${CN}/image-animated-mask"
    mosquitto_pub -q 2 -r -i "$MOTION_DEVICE" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "$MOTION_MQTT_HOST" -p "${MOTION_MQTT_PORT}" -t "$MOTION_MQTT_TOPIC" -f "$mask"
    if ($?VERBOSE) echo "$0:t $$ -- MQTT post to host ${MOTION_MQTT_HOST} topic $MOTION_MQTT_TOPIC file $mask" >& /dev/stderr
  endif

endif

##
## ALL DONE
##

done:
  if ($?jsons) then
    rm -f "$jsons"
  endif
  if ($?jpgs) then
    rm -f "$jpgs"
  endif
  if ($?tmpdir) then
    rm -fr $tmpdir
  endif
  if ($?VERBOSE) echo "$0:t $$ -- END" `date` >& /dev/stderr
