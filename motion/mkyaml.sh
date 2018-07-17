#!/bin/tcsh 

if ($?CONFIG_PATH == 0) set CONFIG_PATH = "$cwd/config.json"

if ($#argv > 0) then
  set m = "$1"
  if ($m:h == $m) set m = $cwd/$m
endif

if ($?m == 0) set m = $CONFIG_PATH

if ( ! -s "$m") then
  echo "Cannot find configuration JSON file; exiting" >& /dev/stderr
  exit
endif

## process configuration
if (-s "$m") then
  if ( "$m:t" != "config.json" ) then
    # assume options only
    set q = '.cameras[]|.name'
  else
    # assume full configuration
    set q = '.options.cameras[]|.name'
  endif
  set cameras = ( `jq -r "$q" $m | sort` )
  set unique = ( `jq -r "$q" $m | sort | uniq` )
  if ($#unique != $#cameras) then
    echo "Duplicate camera names ($#cameras vs $#unique); exiting" >& /dev/stderr
    exit
  endif
else
  echo "Unable to find configuration file: $m" >& /dev/stderr
  exit
endif
echo "Found $#cameras cameras" >& /dev/stderr

####
#### CORE configuration.yaml
####

set out = "$m:h/configuration.yaml"; rm -f "$out"

echo "###" >> "$out"
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

####
#### GROUPS groups.yaml
####

set out = "$m:h/groups.yaml"; rm -f "$out"

## group for motion animated cameras
echo "" >> "$out"
echo "motion_animated_view:" >> "$out"
echo "  view: true" >> "$out"
echo "  name: Motion Animated View" >> "$out"
echo "  icon: mdi:animation" >> "$out"
echo "  entities:" >> "$out"
echo "    - camera.motion_animated" >> "$out"
foreach c ( $cameras )
  # echo "    - camera.motion_${c}" >> "$out"
  echo "    - camera.motion_${c}_animated" >> "$out"
end
echo "" >> "$out"

####
#### AUTOMATIONS automations.yaml
####

set out = "$m:h/automations.yaml"; rm -f "$out"

####
#### SCRIPTS scripts.yaml
####

set out = "$m:t/scripts.yaml"; rm -f "$out"
