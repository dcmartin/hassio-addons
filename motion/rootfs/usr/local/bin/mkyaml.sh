#!/bin/tcsh 

setenv DEBUG
setenv VERBOSE

if ($?VERBOSE) echo "$0:t $$ -- START $*" >& /dev/stderr

if ($?CONFIG_PATH == 0) then
  echo "Environment variable unset: CONFIG_PATH"
  exit
endif

if ($?MOTION_JSON_FILE == 0) then
  echo "Environment variable unset: MOTION_JSON_FILE"
  exit
endif

if ( -s "$MOTION_JSON_FILE") then
  if ($?VERBOSE) echo "$0:t $$ -- Found configuration JSON file: $MOTION_JSON_FILE" >& /dev/stderr
  if (-s "$CONFIG_PATH") then
    if ($?VERBOSE) echo "$0:t $$ -- Found options JSON file: $CONFIG_PATH" >& /dev/stderr
  else
    if ($?DEBUG) echo "$0:t $$ -- Cannot find configuration file: $CONFIG_PATH; exiting" >& /dev/stderr
    exit
  endif
else
  if ($?DEBUG) echo "$0:t $$ -- Cannot find configuration file: $MOTION_JSON_FILE; exiting" >& /dev/stderr
  exit
endif

set DATA_DIR = "$CONFIG_PATH:h"

####
#### CORE configuration.yaml
####

set username = ( `jq -r ".username" "$CONFIG_PATH"` )
set password = ( `jq -r ".password" "$CONFIG_PATH"` )
set port = ( `jq -r ".port" "$CONFIG_PATH"` )

set www = ( `jq -r ".www" "$MOTION_JSON_FILE"` )
set name = ( `jq -r ".name" "$MOTION_JSON_FILE"` )
set host = ( `jq -r ".host" "$MOTION_JSON_FILE"` )
set devicedb = ( `jq -r ".devicedb" "$MOTION_JSON_FILE"` )
set timezone = ( `jq -r ".timezone" "$MOTION_JSON_FILE"` )
set latitude = ( `jq -r ".latitude" "$MOTION_JSON_FILE"` )
set longitude = ( `jq -r ".longitude" "$MOTION_JSON_FILE"` )
set elevation = ( `jq -r ".elevation" "$MOTION_JSON_FILE"` )
set mqtt_host = ( `jq -r ".mqtt.host" "$MOTION_JSON_FILE"` )
set mqtt_port = ( `jq -r ".mqtt.port" "$MOTION_JSON_FILE"` )
set unit_system = ( `jq -r ".unit_system" "$MOTION_JSON_FILE"` )

## initialize components to !include at the end
set components =  ( "group" )

## find cameras
if (-s "$MOTION_JSON_FILE") then
  set q = '.cameras[]|.name'
  set cameras = ( `jq -r "$q" $MOTION_JSON_FILE | sort` )
  set unique = ( `jq -r "$q" $MOTION_JSON_FILE | sort | uniq` )
  if ($#unique != $#cameras) then
    if ($?DEBUG) echo "$0:t $$ -- Duplicate camera names ($#cameras vs $#unique); exiting" >& /dev/stderr
    exit
  endif
else
  if ($?DEBUG) echo "$0:t $$ -- Unable to find configuration file: $MOTION_JSON_FILE" >& /dev/stderr
  exit
endif
if ($?VERBOSE) echo "$0:t $$ -- Found $#cameras cameras on device ${name}: $cameras" >& /dev/stderr

###
### sensor
###

set c = "sensor"
set components = ( $components "$c" )
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c ["`date`"] (auto-generated from $MOTION_JSON_FILE for name $name; devicedb $devicedb)" >> "$out"

## sensor for camera picture
echo "  - platform: template" >> "$out"
echo "    sensors:" >> "$out"
# LOOP
foreach c ( $cameras )
echo "      motion_${c}_entity_picture:" >> "$out"
echo "        value_template: '{{ states.camera.motion_${c}_animated.attributes.entity_picture }}'" >> "$out"
end

if ($?VERBOSE) echo "$0:t $$ -- processed $out" >& /dev/stderr

###
### binary_sensor
###

set c = "binary_sensor"
set components = ( $components "$c" )
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c ["`date`"] (auto-generated from $MOTION_JSON_FILE for name $name; devicedb $devicedb)" >> "$out"

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

if ($?VERBOSE) echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### input_boolean.yaml
####

set c = "input_boolean"
set components = ( $components "$c" )
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c ["`date`"] (auto-generated from $MOTION_JSON_FILE for name $name; devicedb $devicedb)" >> "$out"

echo "${devicedb}_camera_network_status_notify:" >> "$out"
echo "  name: ${devicedb}_camera_network_status_notify" >> "$out"
echo "  initial: true" >> "$out"
echo "  icon: mdi:switch" >> "$out"
echo "" >> "$out"
echo "${devicedb}_event_end_notify:" >> "$out"
echo "  name: ${devicedb}_event_end_notify" >> "$out"
echo "  initial: true" >> "$out"
echo "  icon: mdi:switch" >> "$out"
echo "" >> "$out"
echo "${devicedb}_camera_status_notify:" >> "$out"
echo "  name: ${devicedb}_camera_status_notify" >> "$out"
echo "  initial: true" >> "$out"
echo "  icon: mdi:switch" >> "$out"
echo "" >> "$out"

foreach c ( $cameras )
echo "${devicedb}_${c}_notify:" >> "$out"
echo "  name: ${devicedb}_${c}_notify" >> "$out"
echo "  initial: false" >> "$out"
echo "" >> "$out"
end

if ($?VERBOSE) echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### automation.yaml
####

set c = "automation"
set components = ( $components "$c" )
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c ["`date`"] (auto-generated from $MOTION_JSON_FILE for name $name; devicedb $devicedb)" >> "$out"
echo "- id: ${devicedb}_notify_recognize" >> "$out"
echo "  alias: ${devicedb}_notify_recognize" >> "$out"
echo "  initial_state: on" >> "$out"
echo "  trigger:" >> "$out"
echo "    - platform: mqtt" >> "$out"
echo '      topic: "'"$devicedb/$name"'/+/event/recognize"' >> "$out"
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
echo '          {{ states(("binary_sensor.motion_notify_",trigger.payload_json.location)|join|lower) == "on" }}' >> "$out"
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
echo '            url: http://'"${www}"':8123{{- states(("sensor.motion_",trigger.payload_json.location,"_entity_picture")|join|lower) -}}' >> "$out"
echo "            content-type: gif" >> "$out"
echo "            hide-thumbnail: false" >> "$out"
echo "" >> "$out"

echo "- id: ${devicedb}_device_status_notify" >> "$out"
echo "  alias: ${devicedb}_device_status_notify" >> "$out"
echo "  initial_state: on" >> "$out"
echo "  trigger:" >> "$out"
echo "    - platform: state" >> "$out"
echo "      entity_id:" >> "$out"
echo "        - group.${devicedb}_${name}_status" >> "$out"
echo "  condition:" >> "$out"
echo "    condition: and" >> "$out"
echo "    conditions:" >> "$out"
echo "      - condition: template" >> "$out"
echo "        value_template: >" >> "$out"
echo "          {{ (trigger.from_state.state|lower) != 'unknown' }}" >> "$out"
echo "      - condition: template" >> "$out"
echo "        value_template: >" >> "$out"
echo "          {{ is_state('binary_sensor.${devicedb}_device_status_notify','on') }}" >> "$out"
echo "  action:" >> "$out"
echo "    - service: persistent_notification.create" >> "$out"
echo "      data_template:" >> "$out"
echo "        title: >" >> "$out"
echo "          {{ state_attr(trigger.entity_id,"friendly_name") }}" >> "$out"
echo "        notification_id: >" >> "$out"
echo "          {{ trigger.entity_id }}" >> "$out"
echo "        message: >" >> "$out"
echo '          {% for state in state_attr(trigger.entity_id,"entity_id") %}' >> "$out"
echo "            {%- if (states(state)|lower) != 'home' -%}" >> "$out"
echo "              {{ state }} is {{ states(state) }}" >> "$out"
echo "            {% endif -%}" >> "$out"
echo "          {% endfor %}" >> "$out"
echo "    - service: mqtt.publish" >> "$out"
echo "      data_template:" >> "$out"
echo "        topic: '${devicedb}/${name}/status/change'" >> "$out"
echo "        retain: false" >> "$out"
echo "        payload: >" >> "$out"
echo '          {%- for state in state_attr(trigger.entity_id,"entity_id") -%}' >> "$out"
echo '            {%- if loop.first -%}{"status":"{{trigger.entity_id}}","date":{{ (now().timestamp()|int) }},"items":[' >> "$out"
echo "            {%- else -%}," >> "$out"
echo "            {%- endif -%}" >> "$out"
echo '            {"name":"{{state}}","status":"{{states(state)}}"}' >> "$out"
echo "          {%- endfor -%}]}" >> "$out"
echo "" >> "$out"

if ($?VERBOSE) echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### configuration.yaml
####

set c = "configuration"
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c ["`date`"] (auto-generated from $MOTION_JSON_FILE for name $name; devicedb $devicedb)" >> "$out"
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
# echo "  trusted_networks:" >> "$out"
# echo "  base_url: http://${www}:8123" >> "$out"
echo "" >> "$out"
## additional built-in packages
echo "## PACKAGES" >> "$out"
echo "hassio:" >> "$out"
echo "frontend:" >> "$out"
echo "config:" >> "$out"
# echo "history:" >> "$out"
# echo "logbook:" >> "$out"
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
echo "" >> "$out"
echo "## MQTT" >> "$out"
echo "mqtt:" >> "$out"
echo "  broker: $mqtt_host" >> "$out"
echo "  port: $mqtt_port" >> "$out"
echo "  client_id: $name" >> "$out"
# echo "  keepalive: 60" >> "$out"
echo "" >> "$out"

#echo "mqtt:" >> "$out"
#echo "  discovery: true" >> "$out"
#echo "  discovery_prefix: $devicedb" >> "$out"
#echo "" >> "$out"

###
### additional YAML components 
###

echo "" >> "$out"
echo "## include'd components" >> "$out"
foreach x ( $components )
  if ($?VERBOSE) echo "$0:t $$ -- including ${x}.yaml" >& /dev/stderr
  echo "${x}"': \!include '"${x}"'.yaml' >> "$out"
end

###
### camera(s) in configuration.yaml
###

## images from any device in $devicedb
echo "" >> "$out"
echo "## CAMERAS ($#cameras) [$devicedb]" >> "$out"
echo "" >> "$out"
echo "camera motion_image:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_image" >> "$out"
echo '    topic: "'$devicedb'/+/+/image"' >> "$out"
echo "" >> "$out"
echo "camera motion_animated:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_animated" >> "$out"
echo '    topic: "'$devicedb'/+/+/image-animated"' >> "$out"
echo "" >> "$out"
echo "camera motion_image_animated:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_image_animated" >> "$out"
echo "    topic: 'image-animated/+'" >> "$out"
echo "" >> "$out"

##
## MAKE ALL CAMERAS
##

foreach c ( $cameras )
  if ($?VERBOSE) echo "$0:t $$ -- Motion device ${name} at location $c" >& /dev/stderr
  set port = ( `jq -r '.cameras[]?|select(.name=="'${c}'").port' "$MOTION_JSON_FILE"` )
  echo "camera motion_${c}_animated:" >> "$out"
  echo "  - platform: mqtt" >> "$out"
  echo "    name: motion_${c}_animated" >> "$out"
  echo '    topic: "'$devicedb/${name}/${c}'/image-animated"' >> "$out"
  echo "" >> "$out"
  echo "camera motion_${c}_image:" >> "$out"
  echo "  - platform: mqtt" >> "$out"
  echo "    name: motion_${c}_image" >> "$out"
  echo '    topic: "'$devicedb/${name}/${c}'/image"' >> "$out"
  echo "" >> "$out"
  set mjpeg_url = "http://${www}:${port}"
  if ($?VERBOSE) echo "$0:t $$ -- Live camera URL for device ${name} camera ${c}: $mjpeg_url" >& /dev/stderr
  echo "camera motion_${c}_live:" >> "$out"
  echo "  - platform: mjpeg" >> "$out"
  echo "    name: motion_${c}_live" >> "$out"
  echo "    mjpeg_url: $mjpeg_url" >> "$out"
  echo "    username: $username" >> "$out"
  echo "    password: $password" >> "$out"
  echo "" >> "$out"
end

if ($?VERBOSE) echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### group.yaml
####

group:

set c = "group"
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c ["`date`"] (auto-generated from $MOTION_JSON_FILE for name $name; devicedb $devicedb)" >> "$out"

## group for motion animated cameras
echo "default_view:" >> "$out"
echo "  view: yes" >> "$out"
echo "  name: Home" >> "$out"
echo "  icon: mdi:home" >> "$out"
echo "  entities:" >> "$out"
echo "    - group.${devicedb}_camera_latest_images" >> "$out"
echo "    - group.${devicedb}_camera_network_status" >> "$out"
echo "    - group.${devicedb}_input_booleans" >> "$out"
echo "" >> "$out"

echo "${devicedb}_camera_latest_images:" >> "$out"
echo "  name: Home" >> "$out"
echo "  icon: mdi:home" >> "$out"
echo "  entities:" >> "$out"
echo "    - camera.${devicedb}_image" >> "$out"
echo "    - camera.${devicedb}_animated" >> "$out"
echo "    - camera.${devicedb}_image_animated" >> "$out"
echo "" >> "$out"

echo "${devicedb}_input_booleans:" >> "$out"
echo "  name: Home" >> "$out"
echo "  icon: mdi:home" >> "$out"
echo "  entities:" >> "$out"
echo "    - input_boolean.${devicedb}_camera_network_status_notify" >> "$out"
echo "    - input_boolean.${devicedb}_camera_status_notify" >> "$out"
echo "    - input_boolean.${devicedb}_event_end_notify" >> "$out"
echo "" >> "$out"

foreach c ( $cameras )
echo "${devicedb}_${c}_view:" >> "$out"
echo "  view: yes" >> "$out"
echo "  name: Home" >> "$out"
echo "  icon: mdi:home" >> "$out"
echo "  entities:" >> "$out"
echo "    - camera.${devicedb}_${c}_image" >> "$out"
echo "    - camera.${devicedb}_${c}_live" >> "$out"
echo "    - camera.${devicedb}_${c}_animated" >> "$out"
echo "    - input_boolean.${devicedb}_${c}_status_notify" >> "$out"
end
echo "" >> "$out"

## CAMERA_NETWORK_STATUS group

echo "${devicedb}_camera_network_status:" >> "$out"
echo "  name: ${devicedb} Camera Network Status" >> "$out"
echo "  view: false" >> "$out"
echo "  entities:" >> "$out"
foreach c ( $cameras )
  set mac = ( `jq -r '.cameras[]|select(.name=="'${c}'").mac' "$CONFIG_PATH"` )
  if ($#mac && "$mac" != "null") then
    echo "    - device_tracker.${devicedb}_${name}_${c}" >> "$out"
  endif
end
echo "" >> "$out"

if ($?VERBOSE) echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### known_devices.yaml
####

set c = "known_devices"
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
set components = ( $components "$c" )

echo "### MOTION $c ["`date`"] (auto-generated from $MOTION_JSON_FILE for name $name; devicedb $devicedb)" >> "$out"

# 192.168.1.163 00:22:6B:F0:92:60 (Cisco-Linksys)
foreach c ( $cameras )
  set mac = ( `jq -r '.cameras[]|select(.name=="'${c}'").mac' "$CONFIG_PATH"` )
  if ($#mac && "$mac" != "null") then
    echo "${devicedb}_${name}_${c}:" >> "$out"
    echo "  mac: ${mac}" >> "$out"
    echo "  name: ${devicedb}_${name}_${c}" >> "$out"
    echo "  icon: mdi:webcam" >> "$out"
    echo "  track: true" >> "$out"
    echo "  hide_if_away: false" >> "$out"
    echo "" >> "$out"
  endif
end


if ($?VERBOSE) echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### ui-lovelace.yaml
####

set c = "ui-lovelace"
set components = ( $components "$c" )
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"

echo "### MOTION $c ["`date`"] (auto-generated from $MOTION_JSON_FILE for name $name; devicedb $devicedb)" >> "$out"
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
echo "    title: IMAGES" >> "$out"
echo "    cards:" >> "$out"
foreach c ( $cameras )
echo "    - type: picture-entity" >> "$out"
echo "      entity: camera.motion_${c}_image" >> "$out"
end
echo "  - icon: mdi:video" >> "$out"
echo "    title: LIVE" >> "$out"
echo "    cards:" >> "$out"
foreach c ( $cameras )
echo "    - type: picture-entity" >> "$out"
echo "      entity: camera.motion_${c}_live" >> "$out"
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

if ($?VERBOSE) echo "$0:t $$ -- processed $out" >& /dev/stderr

##

if ($?VERBOSE) echo "$0:t $$ -- finished processing" >& /dev/stderr
