#!/bin/tcsh
echo "$0:t $$ -- START" `date` >& /dev/stderr

setenv DEBUG
setenv VERBOSE

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

## get fps from configuration fpor this camera
set fps = ( `jq '.cameras[]|select(.name=="'"$camera"'").fps' "$MOTION_JSON_FILE"` )

if ($?MOTION_VIDEO_BREAKDOWN == 0) then
  # convert directly from 3gp to MJPEG
  ffmpeg -y -r "$fps" -i "$video" -vcodec mjpeg "$output:r.mjpeg"
  mv -f "$output:r.mjpeg" "$output"
  rm -f "$video"
  goto done
endif

### breakdown video into frames
set tmpdir = "/tmpfs/$0:t/$$"
set pattern = "${tmpdir}/${input}-%03d.jpg"
mkdir -p "$tmpdir"
# make all frames
ffmpeg -r "$fps" -i $video "$pattern" >&! /dev/null
# move each image in order to output
set ms = `echo "1 / $fps" | bc -l`
set jpgs = ( `echo "${tmpdir}/${input}"-*.jpg` )
foreach f ( $jpgs )
  if ($?VERBOSE) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -m '{"INFO":"'$0:t'","pid":"'$$'","info":"moving '$f' to '$output'"}'
  mv -f "$f" "${output}"
  sleep "${ms}"
end
rm -f "$tmpdir"

# document
if ($?MOTION_VIDEO_JSON) then
  set frames = ()
  if ($#jpgs) then
    foreach f ( $jpgs )
      set frames = ( $frames $f:t:r )
    end
    set frames = ( `echo "$frames" | sed 's/ /,/g' | sed 's/\([^,]*\)/"\1"/g'` )
  endif
  # identify original video
  identify -verbose -moments -unique "$video" | convert rose: json:- | jq '.[]|.image.name="'"${input}"'"|.frames=['"$frames"']' >! "$json"
  if ($?VERBOSE) mosquitto_pub -h "$MOTION_MQTT_HOST" -t "debug" -f "$json"
endif

## ALL DONE
done:
