#!/bin/tcsh
setenv DEBUG
setenv VERBOSE
setenv USE_MQTT

# legacy
unsetenv MOTION_FILE_NORMAL

if ($?VERBOSE) echo "$0:t $$ -- START $*" `date` >& /dev/stderr

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

if ($#argv == 2) then
  set video = "$argv[1]"
  set output = "$argv[2]" 
else
  echo "USAGE: $0:t <3gp>" >& /dev/stderr
  exit
endif

set input = "$video:t:r"
set camera = "$output:t:r"
set format = "$output:e"

# %Y - time of last data modification, seconds since Epoch
set mtime = `stat -c "%Y" $video`
set dateattr = ( `$dateconv -f '%Y %m %d %H %M %S' -i "%s" "$mtime"` )
set datetime = "${dateattr[1]}${dateattr[2]}${dateattr[3]}${dateattr[4]}${dateattr[5]}${dateattr[6]}"

## get configuration for this camera
set fps = ( `jq -r '.cameras[]|select(.name=="'"$camera"'").fps' "$MOTION_JSON_FILE"` )
set width = ( `jq -r '.cameras[]|select(.name=="'"$camera"'").width' "$MOTION_JSON_FILE"` )
set height = ( `jq -r '.cameras[]|select(.name=="'"$camera"'").height' "$MOTION_JSON_FILE"` )
set target_dir = ( `jq -r '.cameras[]|select(.name=="'"$camera"'").target_dir' "$MOTION_JSON_FILE"` )

if ($?MOTION_VIDEO_DIRECT2MJPEG) then
  # convert directly from 3gp to MJPEG
  ffmpeg -y -r "$fps" -i "$video" -vcodec mjpeg "$output:r.mjpeg"
  mv -f "$output:r.mjpeg" "$output"
  goto done
endif

# get last event number
set last = "/tmpfs/$0:t.$camera"
if (-e "$last") then
  set event = `cat "$last"`
  @ event++
else
  # or start at zero
  set event = 0
endif
# keep track
echo "$event" >! "$last"
# image identity
set event_id = `echo "$event" | awk '{ printf("%02d",$1) }'`

if ($?MOTION_FILE_NORMAL == 0) then
  # on_motion_detect.sh %$ %v %Y %m %d %H %M %S
  if ($?VERBOSE) echo "$0:t $$ -- Calling on_motion_detect.sh $camera $event_id $dateattr" >& /dev/stderr
  on_motion_detect.sh $camera $event_id $dateattr
  # on_event_start.sh %$ %v %Y %m %d %H %M %S
  if ($?VERBOSE) echo "$0:t $$ -- Calling on_event_start.sh $camera $event_id $dateattr" >& /dev/stderr
  on_event_start.sh $camera $event_id $dateattr
endif

### breakdown video into frames
set tmpdir = "/tmpfs/$0:t/$$"
set pattern = "${input}-%03d.$format"
mkdir -p "$tmpdir"
# make all frames
pushd "$tmpdir" >& /dev/null
if ($?VERBOSE) echo "$0:t $$ -- Converting video $video into JPEG in directory $tmpdir using pattern $pattern at FPS $fps" >& /dev/stderr
ffmpeg -r "$fps" -i $video "$pattern" >&! /tmp/$0:t.$$.txt
# move each image in order to output
set jpgs = ( `echo *."$format"` )
popd >& /dev/null
if ($#jpgs == 0) then
  if ($?DEBUG) echo "$0:t $$ -- Failed to convert video $video into pattern $pattern; exiting" >& /dev/stderr
  cat "/tmp/$0:t.$$.txt"
  rm -fr "$tmpdir"
  exit
else
  if ($?VERBOSE) echo "$0:t $$ -- Found $#jpgs JPEG in video $video at FPS $fps ($jpgs)" >& /dev/stderr
  rm -f "/tmp/$0:t.$$.txt"
endif

# count frames
@ seqno = 0
set frames = ()

# camera specifications should be calculated; defaults for now
set filetype = 0
@ mx = 320
@ my = 240
@ mw = 100
@ mh = 100

## process all frames
@ i = 0
foreach j ( $jpgs )
  set f = "$tmpdir/$j"
  @ i++
  if ($i % $fps == 0) then
    set seqno = 0
    @ mtime++
    set dateattr = ( `$dateconv -f '%Y %m %d %H %M %S' -i "%s" "$mtime"` )
    set datetime = "${dateattr[1]}${dateattr[2]}${dateattr[3]}${dateattr[4]}${dateattr[5]}${dateattr[6]}"
  else
    @ seqno++
  endif

  if ($?MOTION_FILE_NORMAL) then
    if ($?VERBOSE && $?USE_MQTT) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "${MOTION_DEVICE_DB}/${MOTION_DEVICE_NAME}/debug" -m '{"INFO":"'$0:t'","pid":"'$$'","info":"moving '$f' to '$output'"}'
    echo "$0:t $$ -- Moving $f to $output" >& /dev/stderr
    set frames = ( $frames $f:t:r )
    mv -f "$f" "${output}"
    continue
  else
    # would probably screw things up
    # cp -f "$f" "${output}"
  endif
  # manually execute sequence
  set seqid = `echo "$seqno" | awk '{ printf("%02d",$1) }'`
  set output = "$target_dir/${datetime}-${event_id}-${seqid}.$format"
  if ($?json == 0) set json = "$target_dir/${datetime}-${event_id}.json"
  set frames = ( $frames $output:t )
  if ($?VERBOSE) echo "$0:t $$ -- Moving extracted JPEG $f to $output" >& /dev/stderr
  mv -f "$f" "${output}"
  # on_picture_save %$ %v %f %n %K %L %i %J %D %N
  if ($?VERBOSE) echo "$0:t $$ -- Calling on_picture_save.sh $camera $event_id $output $filetype $mx $my $mw $mh 10000 0" >& /dev/stderr
  on_picture_save.sh $camera $event_id $output $filetype $mx $my $mw $mh 10000 0
end
if ($#frames) set frames = ( `echo "$frames" | sed 's/ /,/g' | sed 's/\([^,]*\)/"\1"/g'` )
rm -fr "$tmpdir"

if ($?MOTION_FILE_NORMAL == 0) then
  # on_event_end.sh %$ %v %Y %m %d %H %M %S
  if ($?VERBOSE) echo "$0:t $$ -- Calling on_event_end.sh $camera $event_id $dateattr" >& /dev/stderr
  on_event_end.sh $camera $event_id $dateattr
endif

# document
if ($?json) then
  # identify original video
  identify -verbose -moments -unique "$video" | convert rose: json:- | jq -c '.[]|.image.name="'"${input}"'"|.frames=['"$frames"']' >! "$json"
  if ($?VERBOSE && $?USE_MQTT) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "${MOTION_DEVICE_DB}/${MOTION_DEVICE_NAME}/debug" -f "$json"
endif

## ALL DONE
done:
  if ($?VERBOSE) echo "$0:t $$ -- FINISHED" >& /dev/stderr
  rm -f "${video}"
