#!/bin/tcsh 

setenv DEBUG
setenv VERBOSE

echo "$0:t $$ -- START $*" >& /dev/stderr

if ($#argv) then
  set CONFIG_PATH = "$argv[$#argv]"
  set DATA_DIR = "$CONFIG_PATH:h"
else
  if ($?DEBUG) echo "$0:t $$ -- insufficient arguments: $0:t <full-path-to-options.json>" >& /dev/stderr
  exit 
endif

if ( ! -s "$CONFIG_PATH") then
  if ($?DEBUG) echo "$0:t $$ -- Cannot find configuration file ($CONFIG_PATH); exiting" >& /dev/stderr
  exit
else
  if ($?VERBOSE) echo "$0:t $$ -- Found configuration JSON file: $CONFIG_PATH" >& /dev/stderr
endif

####
#### CORE configuration.yaml
####

set devicedb = ( `jq -r ".devicedb" "$CONFIG_PATH"` )
set name = ( `jq -r ".name" "$CONFIG_PATH"` )
set password = ( `jq -r ".password" "$CONFIG_PATH"` )
set www = ( `jq -r ".www" "$CONFIG_PATH"` )
set port = ( `jq -r ".port" "$CONFIG_PATH"` )
set elevation = ( `jq -r ".elevation" "$CONFIG_PATH"` )
set longitude = ( `jq -r ".longitude" "$CONFIG_PATH"` )
set latitude = ( `jq -r ".latitude" "$CONFIG_PATH"` )
set unit_system = ( `jq -r ".unit_system" "$CONFIG_PATH"` )
set timezone = ( `jq -r ".timezone" "$CONFIG_PATH"` )

## initialize components to !include at the end
set components = ()

## find cameras
if (-s "$CONFIG_PATH") then
  set q = '.cameras[]|.name'
  set cameras = ( `jq -r "$q" $CONFIG_PATH | sort` )
  set unique = ( `jq -r "$q" $CONFIG_PATH | sort | uniq` )
  if ($#unique != $#cameras) then
    if ($?DEBUG) echo "$0:t $$ -- Duplicate camera names ($#cameras vs $#unique); exiting" >& /dev/stderr
    exit
  endif
else
  if ($?DEBUG) echo "$0:t $$ -- Unable to find configuration file: $CONFIG_PATH" >& /dev/stderr
  exit
endif
if ($?VERBOSE) echo "$0:t $$ -- Found $#cameras cameras on device ${name}: $cameras" >& /dev/stderr

###
### sensor
###

set c = "sensor"
set components = ( $components "$c" )
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c (auto-generated from $CONFIG_PATH for name $name)" >> "$out"

## sensor for camera picture
echo "  - platform: template" >> "$out"
echo "    sensors:" >> "$out"
# LOOP
foreach c ( $cameras )
echo "      motion_${c}_entity_picture:" >> "$out"
echo "        value_template: '{{ states.camera.motion_${c}_animated.attributes.entity_picture }}'" >> "$out"
end

echo "$0:t $$ -- processed $out" >& /dev/stderr

###
### binary_sensor
###

set c = "binary_sensor"
set components = ( $components "$c" )
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c (auto-generated from $CONFIG_PATH for name $name)" >> "$out"

## binary_sensor for input_boolean
echo "- platform: template" >> "$out"
echo "  sensors:" >> "$out"
# LOOP
foreach c ( $cameras )
echo "    motion_notify_${c}:" >> "$out"
echo "      entity_id:" >> "$out"
echo "        - input_boolean.motion_notify_${c}" >> "$out"
echo "      value_template: >" >> "$out"
echo "        {{ is_state('input_boolean.motion_notify_${c}','on') }}" >> "$out"
end
echo "" >> "$out"

echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### group.yaml
####

set c = "group"
set components = ( $components "$c" )
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c (auto-generated from $CONFIG_PATH for name $name)" >> "$out"

## group for motion animated cameras
echo "### MOTION (auto-generated from $CONFIG_PATH for name $name)" >> "$out"
echo "default_view:" >> "$out"
echo "  view: yes" >> "$out"
echo "  icon: mdi:home" >> "$out"
echo "  entities:" >> "$out"
foreach c ( $cameras )
echo "    - camera.motion_${c}" >> "$out"
echo "    - camera.motion_${c}_animated" >> "$out"
echo "    - sensor.motion_${c}_entity_picture" >> "$out"
echo "    - binary_sensor.motion_notify_${c}" >> "$out"
echo "    - input_boolean.motion_notify_${c}" >> "$out"
end
echo "" >> "$out"

echo "motion_last_view:" >> "$out"
echo "  view: yes" >> "$out"
echo "  name: Motion Animated View" >> "$out"
echo "  icon: mdi:camera-timer" >> "$out"
echo "  entities:" >> "$out"
echo "    - camera.motion_last" >> "$out"
echo "    - camera.motion_animated" >> "$out"
echo "    - camera.motion_animated_mask" >> "$out"
echo "    - camera.motion_composite" >> "$out"
echo "    - camera.motion_average" >> "$out"
echo "    - camera.motion_blend" >> "$out"
echo "" >> "$out"

echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### input_boolean.yaml
####

set c = "input_boolean"
set components = ( $components "$c" )
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c (auto-generated from $CONFIG_PATH for name $name)" >> "$out"

foreach c ( $cameras )
echo "motion_notify_${c}:" >> "$out"
echo "  name: motion_notify_${c}" >> "$out"
echo "  initial: false" >> "$out"
echo "  icon: mdi:${c}" >> "$out"
echo "" >> "$out"
end

echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### automation.yaml
####

set c = "automation"
set components = ( $components "$c" )
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c (auto-generated from $CONFIG_PATH for name $name)" >> "$out"
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
#### configuration.yaml
####

set c = "configuration"
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c (auto-generated from $CONFIG_PATH for name $name)" >> "$out"
## homeassistant
echo "homeassistant:" >> "$out"
echo "  name: $name" >> "$out"
echo "  latitude: $latitude" >> "$out"
echo "  longitude: $longitude" >> "$out"
echo "  elevation: $elevation" >> "$out"
echo "  unit_system: $unit_system" >> "$out"
echo "  time_zone: $timezone" >> "$out"
echo "" >> "$out"
## Web front-end
echo "## FRONT-END" >> "$out"
echo "http:" >> "$out"
echo "  api_password: $password" >> "$out"
echo "  trusted_networks:" >> "$out"
echo "  base_url: http://${www}:${port}" >> "$out"
echo "" >> "$out"
## additional built-in packages
echo "## PACKAGES" >> "$out"
echo "hassio:" >> "$out"
echo "frontend:" >> "$out"
echo "config:" >> "$out"
echo "logbook:" >> "$out"
echo "history:" >> "$out"
# echo "discovery:" >> "$out"
# echo "updater:" >> "$out"
# echo "conversation:" >> "$out"
# echo "map:" >> "$out"
# echo "recorder:" >> "$out"
echo "" >> "$out"
## solar
echo "## SUN" >> "$out"
echo "sun:" >> "$out"
echo "  elevation: $elevation" >> "$out"
echo "" >> "$out"
## mqtt
set mqtt_host = ( `jq -r ".mqtt.host" "$CONFIG_PATH"` )
set mqtt_port = ( `jq -r ".mqtt.port" "$CONFIG_PATH"` )
echo "" >> "$out"
echo "## MQTT" >> "$out"
echo "mqtt:" >> "$out"
echo "  broker: $mqtt_host" >> "$out"
echo "  port: $mqtt_port" >> "$out"
echo "  client_id: $name" >> "$out"
echo "" >> "$out"

###
### additional YAML components 
###

echo "## COMPONENTS" >> "$out"
foreach x ( $components )
  if ($?VERBOSE) echo "$0:t $$ -- including ${x}.yaml: []" >& /dev/stderr
  echo "${x}"': \!include '"${x}"'.yaml' >> "$out"
end

###
### camera(s) in configuration.yaml
###

## images from any device in $devicedb
echo "" >> "$out"
echo "## CAMERAS ($#cameras) [$devicedb]" >> "$out"
echo "" >> "$out"
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

## images from this device's cameras
foreach c ( $cameras )
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

echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### ui-lovelace.yaml
####

set out = "$DATA_DIR/ui-lovelace.yaml"; rm -f "$out"

echo "### MOTION (auto-generated from $CONFIG_PATH for name $name)" >> "$out"
echo "name: $name" >> "$out"
echo "" >> "$out"
echo "views:" >> "$out"
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
