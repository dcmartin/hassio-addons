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
  if ($?DEBUG) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -m '{"ERROR":"'$0:t'","pid":"'$$'","error":"no date converter; install dateutils"}'
  goto done
endif

if ($#argv == 2) then
  set video = "$argv[1]"
  set output = "$argv[$#argv]" 
  if ($?VERBOSE) echo "$0:t $$ -- $video" >& /dev/stderr
else
  echo "USAGE: $0:t <3gp>" >& /dev/stderr
  exit
endif

set input = "$video:t:r"
set json = "${output:r}/$input.json"
set camera = "$output:t:r"
set format = "$output:e"

## get fps from configuration fpor this camera
set fps = ( `jq '.cameras[]|select(.name=="'"$camera"'").fps' "$MOTION_JSON_FILE"` )

if ($?MOTION_VIDEO_DIRECT2MJPEG) then
  # convert directly from 3gp to MJPEG
  ffmpeg -y -r "$fps" -i "$video" -vcodec mjpeg "$output:r.mjpeg"
  mv -f "$output:r.mjpeg" "$output"
  rm -f "$video"
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

### breakdown video into frames
set tmpdir = "/tmpfs/$0:t/$$"
set pattern = "${tmpdir}/${input}-%03d.$format"
mkdir -p "$tmpdir"
# make all frames
ffmpeg -r "$fps" -i $video "$pattern" >&! /dev/null
# move each image in order to output
set ms = `echo "1 / $fps" | bc -l`
set jpgs = ( `echo "${tmpdir}/${input}"-*.$format` )

# count frames
@ seqno = 0
set frames = ()
# image identity
set mtime = `stat -c "%Y" $input` # %Y - time of last data modification, seconds since Epoch
set datetime = `$dateconv -f '%Y%m%d%H%M%S' -i "%s" "$mtime"`
set evtid = `echo "$event" | awk '{ printf("%02d",$1) }'`
# calculate frame-to-frame changes
@ t = 0
@ i = 1
set ps = ()
set diffs = ()
# motion
set filetype = 0
@ mx = 320
@ my = 240
@ mw = 100
@ mh = 100
@ fuzz = 5
@ noise = $fuzz
## process all frames
foreach f ( $jpgs )
  set frames = ( $frames $f:t:r )
  if ($?MOTION_VIDEO_ANALYZE == 0) then
    if ($?VERBOSE) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -m '{"INFO":"'$0:t'","pid":"'$$'","info":"moving '$f' to '$output'"}'
    mv -f "$f" "${output}"
  else
    set seqid = `echo "$seqno" | awk '{ printf("%02d",$1) }'`
    set output = "/share/motion/$camera/${datetime}-${evtid}-${seqid}.$format"
    set diffs = ( $diffs $frames[$i]:r.$format)

    # calculate difference (try next, then previous, then same image)
    @ j = $i + 1
    if ($i == $#jpgs && $#jpgs > 2) then
      @ j = $i - 1
    else if ($i <= $#jpgs) then
      @ j = $i + 1
    else
      @ j = $i
    endif
    set p = ( `compare -metric fuzz -fuzz "$fuzz"'%' $frames[$i] $frames[$j] -compose src -highlight-color white -lowlight-color black $diffs[$#diffs] |& awk '{ print $1 }'` )
    if ($?VERBOSE) echo "$0:t $$ -- $diffs[$#diffs] change = $p" >& /dev/stderr
    # keep track of differences
    set ps = ( $ps $p:r )
    @ t += $ps[$#ps]
    @ i++
    mv -f "$f" "${output}"
    # on_picture_save /usr/local/bin/on_picture_save.sh %$ %v %f %n %K %L %i %J %D %N
    on_picture_save.sh "$camera" "$evtid" "$output" $filetype $mx $my $mw $mh $p $noise
  endif
  @ seqno++
  sleep "${ms}"
end
if ($#frames) set frames = ( `echo "$frames" | sed 's/ /,/g' | sed 's/\([^,]*\)/"\1"/g'` )
rm -f "$tmpdir"

# document
if ($?MOTION_VIDEO_JSON) then
  # identify original video
  identify -verbose -moments -unique "$video" | convert rose: json:- | jq '.[]|.image.name="'"${input}"'"|.frames=['"$frames"']' >! "$json"
  if ($?VERBOSE) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -f "$json"
endif

## ALL DONE
done:
