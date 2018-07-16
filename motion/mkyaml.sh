#!/bin/tcsh 

if ($?CONFIG_PATH == 0) set CONFIG_PATH = "$cwd/config.json"

if ($#argv > 0) then
  set m = "$1"
endif

if ($?m == 0) set m = $CONFIG_PATH

if ( ! -s "$m") then
  echo "Cannot find configuration JSON file; exiting" >& /dev/stderr
  exit
endif

set out = "motion.yaml"
set hosts = ()

if (-s "$m") then
  if ( "$m:t" != "config.json" ) then
    # assume options only
    set q = '.cameras[]|.name'
  else
    set hosts = ( `jq -r '.name' "$m"` )
    set q = '.options.cameras[]|.name'
  endif
  if ($#hosts == 0) set hosts = ( $host )
  set cameras = ( `jq -r "$q" $m | sort` )
  set unique = ( `jq -r "$q" $m | sort | uniq` )
  if ($#unique != $#cameras) then
    echo "Duplicate camera names across hosts ($#cameras vs $#unique); exiting" >& /dev/stderr
    exit
  endif
else
  echo "Unable to find configuration file: $m" >& /dev/stderr
  exit
endif

echo "Found $#cameras cameras across $#hosts hosts" >& /dev/stderr

echo "###" >! "$out"
echo "### MOTION add-on" >> "$out"
echo "###" >> "$out"

## cameras for camera.motion_{last|host}_image*
echo "" >> "$out"
echo "## cameras from last MQTT posted images (any host, any camera)" >> "$out"
echo "" >> "$out"
echo "# last images from any host" >> "$out"
echo "camera motion_last:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_last" >> "$out"
echo "    topic: 'motion/+/+/image'" >> "$out"
echo "" >> "$out"
echo "camera motion_animated:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_animated" >> "$out"
echo "    topic: 'motion/+/+/image-animated'" >> "$out"
echo "" >> "$out"
echo "camera motion_average:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_average" >> "$out"
echo "    topic: 'motion/+/+/image-average'" >> "$out"
echo "" >> "$out"
echo "camera motion_blend:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_blend" >> "$out"
echo "    topic: 'motion/+/+/image-blend'" >> "$out"
echo "" >> "$out"
echo "camera motion_animated_mask:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_animated_mask" >> "$out"
echo "    topic: 'motion/+/+/image-animated-mask'" >> "$out"
echo "" >> "$out"
echo "camera motion_composite:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_composite" >> "$out"
echo "    topic: 'motion/+/+/image-composite'" >> "$out"
echo "" >> "$out"

## cameras
foreach c ( $cameras )
  echo "# camera ${c}" >> "$out"
  echo "camera motion_${c}:" >> "$out"
  echo "  - platform: mqtt" >> "$out"
  echo "    name: motion_${c}" >> "$out"
  echo "    topic: 'motion/+/${c}/image'" >> "$out"
  echo "" >> "$out"
  echo "camera motion_${c}_animated:" >> "$out"
  echo "  - platform: mqtt" >> "$out"
  echo "    name: motion_${c}_animated" >> "$out"
  echo "    topic: 'motion/+/${c}/image-animated'" >> "$out"
  echo "" >> "$out"
end

#
# MOTION VIEW
#

## group for all motion 
echo "group motion_view:" >> "$out"
echo "  view: true" >> "$out"
echo "  name: Motion View" >> "$out"
echo "  icon: mdi:animation" >> "$out"
echo "  entities:" >> "$out"
echo "    - camera.motion_last" >> "$out"
echo "    - camera.motion_animated" >> "$out"
foreach c ( $cameras )
  # echo "    - camera.motion_${c}" >> "$out"
  echo "    - camera.motion_${c}_animated" >> "$out"
end
echo "" >> "$out"
