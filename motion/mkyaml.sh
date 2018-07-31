#!/bin/tcsh 

echo "$0:t $$ -- START $*" >& /dev/stderr

if ($?CONFIG_PATH == 0) then
  set CONFIG_PATH = "$cwd/config.json"
endif

if ($#argv > 0) then
  set m = "$1"
else
  set m = $CONFIG_PATH
endif

set CONFIG_DIR = $m:h

if ( ! -s "$m") then
  echo "$0:t $$ -- Cannot find configuration JSON file; exiting" >& /dev/stderr
  exit
else
  echo "$0:t $$ -- Found configuration JSON file: $m" >& /dev/stderr
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
    echo "$0:t $$ -- Duplicate camera names ($#cameras vs $#unique); exiting" >& /dev/stderr
    exit
  endif
else
  echo "$0:t $$ -- Unable to find configuration file: $m" >& /dev/stderr
  exit
endif
echo "$0:t $$ -- Found $#cameras cameras" >& /dev/stderr

####
#### CORE configuration.yaml
####

set out = "$CONFIG_DIR/configuration.yaml"; rm -f "$out"

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

## binary_sensor for input_boolean
echo "" >> "$out"
echo "binary_sensor motion_binary_sensor_template:" >> "$out"
echo "  - platform: template" >> "$out"
echo "    sensors:" >> "$out"
foreach c ( $cameras )
  echo "      motion_notify_${c}:" >> "$out"
  echo "        entity_id:" >> "$out"
  echo "          - input_boolean.motion_notify_${c}" >> "$out"
  echo "        value_template: >" >> "$out"
  echo "          {{ is_state('input_boolean.motion_notify_${c}','on') }}" >> "$out"
end
echo "" >> "$out"

## sensor for camera picture
echo "" >> "$out"
echo "sensor motion_entity_picture_template:" >> "$out"
echo "  - platform: template" >> "$out"
echo "    sensors:" >> "$out"
foreach c ( $cameras )
  echo "      motion_${c}_entity_picture:" >> "$out"
  echo "        value_template: '{{ states.camera.motion_${c}_animated.attributes.entity_picture }}'" >> "$out"
end
echo "" >> "$out"

echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### GROUPS group.yaml
####

set out = "$CONFIG_DIR/group.yaml"; rm -f "$out"

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

echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### input_boolean.yaml
####

set out = "$CONFIG_DIR/input_boolean.yaml"; rm -f "$out"

foreach c ( $cameras )
echo "" >> "$out"
echo "motion_notify_${c}:" >> "$out"
echo "  name: motion_notify_${c}" >> "$out"
echo "  initial: false" >> "$out"
echo "  icon: mdi:${c}" >> "$out"
end

echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### AUTOMATIONS automation.yaml
####

set out = "$CONFIG_DIR/automation.yaml"; rm -f "$out"

echo "" >> "$out"
echo "- id: motion_notify_recognize" >> "$out"
echo "  alias: motion_notify_recognize" >> "$out"
echo "  initial_state: on" >> "$out"
echo "  trigger:" >> "$out"
echo "    - platform: mqtt" >> "$out"
echo "      topic: 'motion/+/+/event/recognize'" >> "$out"
echo "  condition:" >> "$out"
echo "    condition: and" >> "$out"
echo "    conditions:" >> "$out"
echo "      - condition: time" >> "$out"
echo "        after: '06:00'" >> "$out"
echo "      - condition: time" >> "$out"
echo "        before: '22:00'" >> "$out"
echo "      - condition: template" >> "$out"
echo "        value_template: >" >> "$out"
echo "          {{ ((now().timestamp()|int) - trigger.payload_json.date) < 60 }}" >> "$out"
echo "      - condition: template" >> "$out"
echo "        value_template: >" >> "$out"
echo "          {{ states(("binary_sensor.motion_notify_",trigger.payload_json.location)|join|lower) == 'on' }}" >> "$out"
echo "  action:" >> "$out"
echo "    - service: notify.notify" >> "$out"
echo "      data_template:" >> "$out"
echo "        title: >-" >> "$out"
echo "          {{ trigger.payload_json.class }} recognized" >> "$out"
echo "        message: >-" >> "$out"
echo "          SAW {{ trigger.payload_json.class }} at {{ trigger.payload_json.location }}" >> "$out"
echo '          AT {{ trigger.payload_json.date|int|timestamp_custom("%a %b %d @ %I:%M %p") | default(null) }}' >> "$out"
echo "          [ {{ trigger.payload_json.model }} {{ trigger.payload_json.score|float }} {{ trigger.payload_json.size }} {{ trigger.payload_json.id }} ]" >> "$out"
echo "        data:" >> "$out"
echo "          attachment:" >> "$out"
echo '            url: http://homeassistant.dcmartin.com:8123{{- states(("sensor.motion_",trigger.payload_json.location,"_entity_picture")|join|lower) -}}' >> "$out"
echo "            content-type: gif" >> "$out"
echo "            hide-thumbnail: false" >> "$out"
echo "" >> "$out"

echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### SCRIPTS script.yaml
####

set out = "$CONFIG_DIR/script.yaml"; rm -f "$out"

####
#### ui-lovelace.yaml
####

set out = "$CONFIG_DIR/ui-lovelace.yaml"; rm -f "$out"

echo "  - icon: mdi:animation" >> "$out"
echo "    title: ANIMATIONS" >> "$out"
echo "    cards:" >> "$out"
foreach c ( $cameras )
echo "    - type: picture-entity" >> "$out"
echo "      entity: camera.motion_${c}_animated" >> "$out"
end
echo "  - icon: mdi:webcam" >> "$out"
echo "    title: CAMERAS" >> "$out"
echo "    cards:" >> "$out"
foreach c ( $cameras )
echo "    - type: picture-entity" >> "$out"
echo "      entity: camera.motion_${c}" >> "$out"
end
echo "  - icon: mdi:toggle-switch" >> "$out"
echo "    title: SWITCHES" >> "$out"
echo "    cards:" >> "$out"
echo "    - type: entities" >> "$out"
echo "      title: Controls" >> "$out"
echo "      entities:" >> "$out"
foreach c ( $cameras )
echo "        - input_boolean.motion_notify_${c}" >> "$out"
end
echo "" >> "$out"

foreach c ( $cameras )
echo "motion_notify_${c}:" >> "$out"
echo "  name: motion_notify_${c}" >> "$out"
echo "  initial: false" >> "$out"
end

echo "$0:t $$ -- processed $out" >& /dev/stderr

##

echo "$0:t $$ -- finished processing" >& /dev/stderr
