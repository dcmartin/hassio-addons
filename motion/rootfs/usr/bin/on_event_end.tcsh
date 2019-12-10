#!/bin/tcsh

###
### on_event_end.tcsh
###

if ( $?MOTION_LOG_LEVEL ) then
  if ( ${MOTION_LOG_LEVEL} == "debug" ) setenv DEBUG
endif

if ($?DEBUG) echo "$0:t $$ --" `date` "START ${*}" >> /tmp/motion.log

## REQUIRES date utilities
if ( -e /usr/bin/dateutils.dconv ) then
   set dateconv = /usr/bin/dateutils.dconv
else if ( -e /usr/bin/dateconv ) then
   set dateconv = /usr/bin/dateconv
else if ( -e /usr/local/bin/dateconv ) then
   set dateconv = /usr/local/bin/dateconv
endif

##
## PREREQUISITES
##

if ( $?MOTION_TARGET_DIR == 0 ) then
  echo "$0:t $$ -- MOTION_TARGET_DIR unset; exiting" >> /tmp/motion.log
  exit 1
endif

if ($?MOTION_GROUP == 0 || $?MOTION_DEVICE == 0 ) then
  echo "$0:t $$ -- MOTION_{GROUP,DEVICE} unset; exiting" >> /tmp/motion.log
  exit 1
endif

if ($?MOTION_MQTT_HOST == 0 || $?MOTION_MQTT_PORT == 0 || $?MOTION_MQTT_USERNAME == 0 || $?MOTION_MQTT_PASSWORD == 0) then
  echo "$0:t $$ -- MOTION_MQTT_{HOST,PORT,USENAME,PASSWORD} unset; exiting" >> /tmp/motion.log
  exit 1
endif

if ( $?MOTION_FRAME_SELECT == 0 ) then
  echo "$0:t $$ -- MOTION_FRAME_SELECT unset; using all" >> /tmp/motion.log
  set MOTION_FRAME_SELECT = 'all'
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
# %M - The minute as a decimal number (range 00 to 59). >> /tmp/motion.log
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
set NOW = `$dateconv -i '%Y%m%d%H%M%S' -f "%s" "$TS"`

## base of MQTT topic
set mqtt_topic = "${MOTION_GROUP}/${MOTION_DEVICE}/${CN}"

##
## FIND images
##

set dir = "${MOTION_TARGET_DIR}/${CN}"
if ($?DEBUG) echo "$0:t $$ -- Processing $dir; camera: $CN; event: $EN; date: $NOW" >> /tmp/motion.log

# find events (YYYYMMDDHHMMSS-##.json)
set jsons = ( `echo "$dir"/??????????????"-${EN}".json` )
if ($?DEBUG) echo "$0:t $$ -- Event JSONs found ($#jsons); camera: $CN; event: $EN; date: $NOW" >> /tmp/motion.log
if ( $#jsons == 0 ) then
  echo "$0:t $$ -- Event JSON not found; exiting" >> /tmp/motion.log
  exit 1
endif

# find last event
set event_json_file = $jsons[$#jsons]
if (! -s "$event_json_file") then
    echo "$0:t $$ -- JSON file $event_json_file not found; exiting" >> /tmp/motion.log
    exit 1
endif

# find event start
set START = `jq -r '.start' $event_json_file`

# find JPEGs for event
set jpgs = ( `echo "${dir}"/*"-${EN}-"*.jpg` )
if ($?DEBUG) echo "$0:t $$ -- Found $#jpgs JSON; camera: $CN; event: $EN; date: $NOW" >> /tmp/motion.log
if ($#jpgs == 0) then
  echo "$0:t $$ -- ZERO JPEG; exiting" >> /tmp/motion.log
  exit 1
endif

###
### TEST images
###


set i = $#jpgs
set frames = ()
set elapsed = 0

if ($?DEBUG) echo "$0:t $$ -- Testing images; start: $i; from: $#jpgs candidate JPEG" >> /tmp/motion.log

while ($i > 0) 
    set jpg = "$jpgs[$i]"
    set jsn = "$jpg:r.json"

    if ($?DEBUG) echo "$0:t $$ -- $i; jpg=$jpg; jsn=$jsn" >> /tmp/motion.log

    if ( ! -s "$jsn" ) then
      if ($?DEBUG) echo "$0:t $$ -- $i; no JSON: $jsn; continuing.." >> /tmp/motion.log
      @ i--
      continue
    endif

    set THIS = `echo "$jpg:t:r" | sed 's/\(.*\)-.*-.*/\1/'`
    set THIS = `$dateconv -i '%Y%m%d%H%M%S' -f "%s" $THIS`

    @ seconds = $THIS - $START
    # test for breaking conditions
    if ( $seconds < 0 ) then
      if ($?DEBUG) echo "$0:t $$ -- $i; too old: $THIS - $START = $seconds; breaking.." >> /tmp/motion.log
      break
    endif

    # add frame to this interval
    if ($?LAST == 0) set LAST = $THIS
    set frames = ( "$jpg:t:r" $frames )
    if ($?DEBUG) echo "$0:t $$ -- $i; adding to images: $jpg:t:r" >> /tmp/motion.log
    if ( $seconds > $elapsed ) set elapsed = $seconds

    # decrement to older
    @ i--
end

if ($?DEBUG) echo "$0:t $$ -- FOUND $#frames images; camera: $CN; event: $EN" >> /tmp/motion.log

# test
if ( $#frames == 0 ) then
  echo "$0:t $$ -- ZERO images; camera: $CN; event: $EN; exiting" >> /tmp/motion.log
  exit 1
endif

##
## update event_json_file
##

set date = `date +%s`
set images = `echo "$frames" | sed 's/ /,/g' | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g'`
set images = '['"$images"']'

jq -c '.elapsed='"$elapsed"'|.end='${LAST}'|.date='"$date"'|.images='"$images" "$event_json_file" > "$event_json_file.$$"

# test
if ( ! -s "$event_json_file.$$" ) then
  echo "$0:t $$ -- Event JSON update failed; JSON: $event_json_file" >> /tmp/motion.log
  exit 1
endif
if ($?DEBUG) echo "$0:t $$ -- Event JSON updated: $event_json_file" `jq -c '.' $event_json_file` >> /tmp/motion.log
mv -f "$event_json_file.$$" "$event_json_file"

###
### PROCESS images
###

set jpgs = ()
foreach f ( $frames )
  set jpg = "$dir/$f.jpg" 

  # get image information
  if (-e "$jpg:r.json") then
    if ($?DEBUG) echo "$0:t $$ -- Found JSON $jpg:r.json" >> /tmp/motion.log
    set info = ( `identify "$jpg" | awk '{ printf("{\"type\":\"%s\",\"size\":\"%s\",\"bps\":\"%s\",\"color\":\"%s\"}", $2, $3, $5, $6) }' | jq '.'` )
    if ($?DEBUG) echo "$0:t $$ -- Identified $jpg as $info" >> /tmp/motion.log
    jq '.info='"$info"'|.end='"${NOW}" "$jpg:r.json" >! /tmp/$0:t.$$.json
    if (-s /tmp/$0:t.$$.json) then
      mv /tmp/$0:t.$$.json "$jpg:r.json"
      set jpgs = ( $jpgs "$jpg" )
    else
      rm -f /tmp/$0:t.$$.json
      if ($?DEBUG) echo "$0:t $$ -- JSON failed; skipping" >> /tmp/motion.log
      continue
    endif
  else
    if ($?DEBUG) echo "$0:t $$ -- Failed to find JSON $jpg:r.json; skipped" >> /tmp/motion.log
  endif
end

if ($?DEBUG) echo "$0:t $$ -- Found $#jpgs images from $#frames candidates" >> /tmp/motion.log

if ($#jpgs == 0) then
  echo "$0:t $$ -- ZERO images; camera: $CN; event: $EN; exiting" >> /tmp/motion.log
  exit 1
endif

###
### DIFFERENTIATE images
###

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
set tmpdir = "/tmpfs/$0:t/$$"

mkdir -p $tmpdir

##
## AVERAGE image
##

if ($?DEBUG) echo "$0:t $$ -- Calculating average from $#jpgs JPEGS" >> /tmp/motion.log

set average = "$tmpdir/$event_json_file:t:r"'-average.jpg'
convert $jpgs -average $average >&! /tmp/$$.out
if ( ! -s "$average") then
  set out = `cat "/tmp/$$.out"`
  echo "$0:t $$ -- Failed to calculate average image from $#jpgs JPEGS" `cat $out` >> /tmp/motion.log
  rm -f "/tmp/$$.out" $average
  exit 1
endif

if ($?DEBUG) echo "$0:t $$ -- Calculated average image: $average" >> /tmp/motion.log

##
## DIFFS
##

if ($?DEBUG) echo "$0:t $$ -- Calculating difference from $#jpgs JPEGS" >> /tmp/motion.log

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

if ($?DEBUG) echo "$0:t $$ -- Calculated difference: $avgdiff; avgsize: $avgsize; biggest: $biggest; maxsize: $maxsize; maxdiff: $maxdiff" >> /tmp/motion.log

##
## SELECT image to represent event
##

set post_pictures = `jq -r '.post_pictures' "${MOTION_JSON_FILE}"`
if ($?DEBUG) echo "$0:t $$ -- Selecting $post_pictures image" >> /tmp/motion.log

set IF = ()
switch ( "$post_pictures" )
  case "first":
    set IF = "$jpgs[1]"
    breaksw
  case "best":
    set IF = "$biggest"
    breaksw
  case "most":
    set IF = "$changed"
    breaksw
  case "last":
    set IF = "$jpgs[$#jpgs]"
    breaksw
  default:
  case "on":
  case "center":
    @ h = $#ps / 2
    if ($h > 0 && $h <= $#ps) set IF = "$jpgs[$h]"
    breaksw
endsw

if ( $#IF == 0 ) then
  if ($?DEBUG) echo "$0:t $$ -- no image selected; defaulting to last: $#jpgs" >> /tmp/motion.log
  set IF = "$jpgs[$#jpgs]"
endif

if ($?DEBUG) echo "$0:t $$ -- Selected $post_pictures image: $IF" >> /tmp/motion.log

##
## PUBLISH EVENT IMAGE
##

set topic = "${mqtt_topic}/image/end"
set file = "$IF" 
mosquitto_pub -r -q 2 -i "${MOTION_DEVICE}" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "$topic" -f "$file" 
if ($?DEBUG) echo "$0:t $$ -- PUBLISH: topic: $topic; file: $file" >> /tmp/motion.log

##
## add image to event
##
set base64_encoded_file = ${IF}:r.b64
echo -n '{"image":"' > "${base64_encoded_file}"
if ( -s "${IF}" ) then
  base64 -w 0 -i "${IF}" >> "${base64_encoded_file}"
endif
echo '"}' >> "${base64_encoded_file}"
jq -c -s add "${event_json_file}" "${base64_encoded_file}" > ${event_json_file}.$$ && mv -f ${event_json_file}.$$ ${event_json_file}
rm -f ${base64_encoded_file}

##
## PUBLISH EVENT
##

set topic = "${mqtt_topic}/event/end"
set file = "$event_json_file" 
mosquitto_pub -r -q 2 -i "${MOTION_DEVICE}" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "$topic" -f "$file" 
if ($?DEBUG) echo "$0:t $$ -- PUBLISH: topic: $topic; file: $file" >> /tmp/motion.log

##
## BLEND
##

if ($?DEBUG) echo "$0:t $$ -- Calculating blend from $#jpgs JPEGS" >> /tmp/motion.log

set blend = "$tmpdir/$event_json_file:t:r"'-blend.jpg'
convert $jpgs -compose blend -define 'compose:args=50' -alpha on -composite $blend
if ( ! -s "$blend") then
  if ($?DEBUG) echo "$0:t $$ -- Failed to convert $#jpgs into a blend: $blend" >> /tmp/motion.log
endif

if ($?DEBUG) echo "$0:t $$ -- Calculated blend: $avgdiff; avgsize: $avgsize; maxsize: $maxsize" >> /tmp/motion.log

##
## KEY images
##

if (${MOTION_FRAME_SELECT} == 'key') then
  # find key frames
  if ($?DEBUG) echo "$0:t $$ -- Calculating key images from $#jpgs JPEGS" >> /tmp/motion.log
  # start with nothing
  set kjpgs = ()
  set kdiffs = ()
  @ i = 1
  while ( $i <= $#jpgs )
    # keep track of jpgs w/ change > average
    if ($ps[$i] > $avgdiff) then
      if ($?DEBUG) echo "$0:t $$ -- KEY ($i) SIZE ($ps[$i]) - $jpgs[$i] $diffs[$i]" >> /tmp/motion.log
      set kjpgs = ( $kjpgs $jpgs[$i] )
      set kdiffs = ( $kdiffs $diffs[$i] )
    endif
    @ i++
  end
  # key frames
  if ($?DEBUG) echo "$0:t $$ -- Using key images $#kjpgs from $#jpgs" >> /tmp/motion.log
  set srcs = ( $kjpgs )
  set masks = ( $kdiffs )
else
  # all frames
  if ($?DEBUG) echo "$0:t $$ -- Using ALL images" >> /tmp/motion.log
  set srcs = ( $jpgs )
  set masks = ( $diffs )
endif

##
## COMPOSITE 
##

if ($?DEBUG) echo "$0:t $$ -- Calculating composite from $#srcs JPEGS" >> /tmp/motion.log

# start with average
set composite = "$tmpdir/$event_json_file:t:r"'-composite.jpg'
cp -f "$average" "$composite"

# loop over all
@ i = 1
while ( $i <= $#srcs )
  set c = $composite:r.$i.jpg
  if ($?DEBUG) echo "$0:t $$ -- Compositing ${i} ${c} from $srcs[$i] and $masks[$i]" >> /tmp/motion.log
  convert "$composite" "$srcs[$i]" "$masks[$i]" -composite "$c"
  mv -f $c $composite
  @ i++
end

# success or failure
if (! -s "$composite") then
  echo "$0:t $$ -- Failed to convert $#jpgs into a composite: $composite; exiting" >> /tmp/motion.log
  exit 1
endif

if ($?DEBUG) echo "$0:t $$ -- Calculated composite: $composite" >> /tmp/motion.log

##
## ANIMATE (all images)
##

if ($?DEBUG) echo "$0:t $$ -- Calculating animation and mask from $#jpgs JPEGS" >> /tmp/motion.log

## find frames per second for this camera
set fps = ( `jq '.cameras[]|select(.name=="'"$CN"'").fps' "${MOTION_JSON_FILE}"` )
if ($#fps == 0) then
  if ($?DEBUG) echo "$0:t $$ -- Warning!  Did not find camera $CN in ${MOTION_JSON_FILE}" >> /tmp/motion.log
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

if ($?DEBUG) echo "$0:t $$ -- Animation delay: $delay ticks; camera: $CN; fps: $fps" >> /tmp/motion.log

## animated GIF
set gif = "$tmpdir/$event_json_file:t:r.gif"
convert -loop 0 -delay $delay $jpgs $gif

## animated GIF mask
set mask = $tmpdir/$event_json_file:t:r.mask.gif
pushd "$dir" >& /dev/null
convert -loop 0 -delay $delay $diffs $mask
popd >& /dev/null

if ($?DEBUG) echo "$0:t $$ -- Calculated gif: $gif; mask: $mask" >> /tmp/motion.log

##
## MQTT
##

if ($?DEBUG) echo "$0:t $$ -- Publishing to MQTT; host: ${MOTION_MQTT_HOST}; group: ${MOTION_GROUP}; device: ${MOTION_DEVICE}; camera: ${CN}" >> /tmp/motion.log

#
set topic = "$mqtt_topic/image-average"
set file = "$average" 
mosquitto_pub -r -q 2 -i "${MOTION_DEVICE}" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "$topic" -f "$file" 
if ($?DEBUG) echo "$0:t $$ -- PUBLISH: topic: $topic; file: $file" >> /tmp/motion.log
#
set topic = "$mqtt_topic/image-blend"
set file = "$blend" 
mosquitto_pub -r -q 2 -i "${MOTION_DEVICE}" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "$topic" -f "$file" 
if ($?DEBUG) echo "$0:t $$ -- PUBLISH: topic: $topic; file: $file" >> /tmp/motion.log
#
set topic = "$mqtt_topic/image-composite"
set file = "$composite" 
mosquitto_pub -r -q 2 -i "${MOTION_DEVICE}" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "$topic" -f "$file" 
if ($?DEBUG) echo "$0:t $$ -- PUBLISH: topic: $topic; file: $file" >> /tmp/motion.log
#
set topic = "$mqtt_topic/image-animated"
set file = "$gif" 
mosquitto_pub -r -q 2 -i "${MOTION_DEVICE}" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "$topic" -f "$file" 
if ($?DEBUG) echo "$0:t $$ -- PUBLISH: topic: $topic; file: $file" >> /tmp/motion.log
#
set topic = "$mqtt_topic/image-animated-mask"
set file = $mask
mosquitto_pub -r -q 2 -i "${MOTION_DEVICE}" -u ${MOTION_MQTT_USERNAME} -P ${MOTION_MQTT_PASSWORD} -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "$topic" -f "$file" 
if ($?DEBUG) echo "$0:t $$ -- PUBLISH: topic: $topic; file: $file" >> /tmp/motion.log

##
## ALL DONE
##

if ($?DEBUG) echo "$0:t $$ -- Cleaning .." >> /tmp/motion.log

if ($?jsons) rm -f "$jsons"
if ($?jpgs) rm -f "$jpgs"
if ($?tmpdir) rm -fr $tmpdir

if ($?DEBUG) echo "$0:t $$ --" `date` "FINISH ${*}" >> /tmp/motion.log
