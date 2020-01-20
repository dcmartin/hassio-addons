#!/bin/tcsh

#
setenv DEBUG

# legacy

setenv MOTION_JSON_FILE /etc/motion/motion.json

if ($?DEBUG) echo "$0:t $$ -- START $*" `date` >>& /tmp/motion.log

## REQUIRES date utilities
if ( -e /usr/bin/dateutils.dconv ) then
   set dateconv = /usr/bin/dateutils.dconv
else if ( -e /usr/bin/dateconv ) then
   set dateconv = /usr/bin/dateconv
else if ( -e /usr/local/bin/dateconv ) then
   set dateconv = /usr/local/bin/dateconv
else
  goto done
endif

if ($#argv == 2) then
  set video = "$argv[1]"
  set output = "$argv[2]" 
else
  echo "USAGE: $0:t <3gp>" >>& /tmp/motion.log
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
set fps = ( `jq -r '.cameras[]|select(.name=="'"$camera"'").framerate' "$MOTION_JSON_FILE"` )
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

  # on_motion_detected.sh %$ %v %Y %m %d %H %M %S
  if ($?DEBUG) echo "$0:t $$ -- Calling on_motion_detected.sh $camera $event_id $dateattr" >>& /tmp/motion.log
  on_motion_detected.sh $camera $event_id $dateattr
  # on_event_start.sh %$ %v %Y %m %d %H %M %S
  if ($?DEBUG) echo "$0:t $$ -- Calling on_event_start.sh $camera $event_id $dateattr" >>& /tmp/motion.log
  on_event_start.sh $camera $event_id $dateattr

### breakdown video into frames
set tmpdir = "/tmpfs/$0:t/$$"
set pattern = "${input}-%03d.$format"
mkdir -p "$tmpdir"
# make all frames
pushd "$tmpdir" >>& /dev/null
if ($?DEBUG) echo "$0:t $$ -- Converting video $video into JPEG in directory $tmpdir using pattern $pattern at FPS $fps" >>& /tmp/motion.log
ffmpeg -r "$fps" -i $video "$pattern" >>&! /tmp/$0:t.$$.txt
# move each image in order to output
set jpgs = ( `echo *."$format"` )
popd >>& /dev/null
if ($#jpgs == 0) then
  if ($?DEBUG) echo "$0:t $$ -- Failed to convert video $video into pattern $pattern; exiting" >>& /tmp/motion.log
  cat "/tmp/$0:t.$$.txt"
  rm -fr "$tmpdir"
  exit
else
  if ($?DEBUG) echo "$0:t $$ -- Found $#jpgs JPEG in video $video at FPS $fps ($jpgs)" >>& /tmp/motion.log
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

  # manually execute sequence
  set seqid = `echo "$seqno" | awk '{ printf("%02d",$1) }'`
  set output = "$target_dir/${datetime}-${event_id}-${seqid}.$format"
  if ($?json == 0) set json = "$target_dir/${datetime}-${event_id}.json"
  set frames = ( $frames $output:t )
  if ($?DEBUG) echo "$0:t $$ -- Moving extracted JPEG $f to $output" >>& /tmp/motion.log
  mv -f "$f" "${output}"
  # on_picture_save %$ %v %f %n %K %L %i %J %D %N
  if ($?DEBUG) echo "$0:t $$ -- Calling on_picture_save.sh $camera $event_id $output $filetype $mx $my $mw $mh 10000 0" >>& /tmp/motion.log
  on_picture_save.sh $camera $event_id $output $filetype $mx $my $mw $mh 10000 0
end
if ($#frames) set frames = ( `echo "$frames" | sed 's/ /,/g' | sed 's/\([^,]*\)/"\1"/g'` )
rm -fr "$tmpdir"

  # on_event_end.sh %$ %v %Y %m %d %H %M %S
  if ($?DEBUG) echo "$0:t $$ -- Calling on_event_end.sh $camera $event_id $dateattr" >>& /tmp/motion.log
  on_event_end.sh $camera $event_id $dateattr

# document
if ($?json) then
  # identify original video
  identify -verbose -moments -unique "$video" | convert rose: json:- | jq -c '.[]|.image.name="'"${input}"'"|.frames=['"$frames"']' >! "$json"
endif

## ALL DONE
done:
  if ($?DEBUG) echo "$0:t $$ -- FINISHED" >>& /tmp/motion.log
  rm -f "${video}"
