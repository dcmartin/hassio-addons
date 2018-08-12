#!/bin/tcsh 

setenv DEBUG
setenv VERBOSE

echo "$0:t $$ -- START $*" >& /dev/stderr

set DATA_DIR = "$CONFIG_PATH:h"

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
set elevation = ( `jq -r ".elevation" "$CONFIG_PATH"` )
set latitude = ( `jq -r ".latitude" "$CONFIG_PATH"` )
set longitude = ( `jq -r ".longitude" "$CONFIG_PATH"` )
set password = ( `jq -r ".password" "$CONFIG_PATH"` )
set port = ( `jq -r ".port" "$CONFIG_PATH"` )
set timezone = ( `jq -r ".timezone" "$CONFIG_PATH"` )
set unit_system = ( `jq -r ".unit_system" "$CONFIG_PATH"` )
set username = ( `jq -r ".username" "$CONFIG_PATH"` )
set www = ( `jq -r ".www" "$CONFIG_PATH"` )

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
echo "### MOTION $c (auto-generated from $CONFIG_PATH for name $name; devicedb $devicedb)" >> "$out"

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
echo "### MOTION $c (auto-generated from $CONFIG_PATH for name $name; devicedb $devicedb)" >> "$out"

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
#### input_boolean.yaml
####

set c = "input_boolean"
set components = ( $components "$c" )
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c (auto-generated from $CONFIG_PATH for name $name; devicedb $devicedb)" >> "$out"

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
echo "### MOTION $c (auto-generated from $CONFIG_PATH for name $name; devicedb $devicedb)" >> "$out"
echo "- id: motion_notify_recognize" >> "$out"
echo "  alias: motion_notify_recognize" >> "$out"
echo "  initial_state: on" >> "$out"
echo "  trigger:" >> "$out"
echo "    - platform: mqtt" >> "$out"
echo "      topic: '"$MOTION_DEVICE_DB"/+/+/event/recognize'" >> "$out"
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
echo "### MOTION $c (auto-generated from $CONFIG_PATH for name $name; devicedb $devicedb)" >> "$out"
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
# echo "hassio:" >> "$out"
echo "frontend:" >> "$out"
echo "config:" >> "$out"
# echo "logbook:" >> "$out"
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
echo "  keepalive: 60" >> "$out"
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
echo "camera motion_last:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_last" >> "$out"
echo "    topic: '"$MOTION_DEVICE_DB"/+/+/image'" >> "$out"
echo "" >> "$out"
echo "camera motion_animated:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_animated" >> "$out"
echo "    topic: '"$MOTION_DEVICE_DB"/+/+/image-animated'" >> "$out"
echo "" >> "$out"
echo "camera motion_average:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_average" >> "$out"
echo "    topic: '"$MOTION_DEVICE_DB"/+/+/image-average'" >> "$out"
echo "" >> "$out"
echo "camera motion_blend:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_blend" >> "$out"
echo "    topic: '"$MOTION_DEVICE_DB"/+/+/image-blend'" >> "$out"
echo "" >> "$out"
echo "camera motion_animated_mask:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_animated_mask" >> "$out"
echo "    topic: '"$MOTION_DEVICE_DB"/+/+/image-animated-mask'" >> "$out"
echo "" >> "$out"
echo "camera motion_composite:" >> "$out"
echo "  - platform: mqtt" >> "$out"
echo "    name: motion_composite" >> "$out"
echo "    topic: '"$MOTION_DEVICE_DB"/+/+/image-composite'" >> "$out"
echo "" >> "$out"

##
## MAKE ALL CAMERAS
##

set allcameras = ()
set json = "/tmp/$0:t.$$.json"
curl -s -q -f -L "$MOTION_CLOUDANT_URL/${MOTION_DEVICE_DB}/_all_docs?include_docs=true" -o $json
if (-s "$json") then
  set devices = ( `jq -r '.rows[].doc.name' "$json"` )
  if ($?VERBOSE) echo "$0:t $$ -- Found $#devices devices for ${MOTION_DEVICE_DB}" >& /dev/stderr
  foreach d ( $devices )
    set nocams = ( `jq -r '.rows[]?|select(.doc.name=="'${d}'").doc.cameras?==null' "$json"` )
    if ($nocams == "false") then
      set devcams = ( `jq -r '.rows[]?|select(.doc.name=="'${d}'").doc.cameras[]?.name' "$json"` )
      if ($?VERBOSE) echo "$0:t $$ -- Found $#devcams cameras for device $d" >& /dev/stderr
      foreach c ( $devcams )
        if ($?VERBOSE) echo "$0:t $$ -- Motion device ${d} at location $c" >& /dev/stderr
	echo "camera motion_${c}_animated:" >> "$out"
	echo "  - platform: mqtt" >> "$out"
	echo "    name: motion_${c}_animated" >> "$out"
	echo "    topic: '"$MOTION_DEVICE_DB/${d}/${c}"/image-animated'" >> "$out"
	echo "" >> "$out"
        set allcameras = ( $allcameras $c )
      end
    else
      # handle legacy ageathome cameras
      set c = ( `jq -r '.rows[]?|select(.doc.name=="'${d}'").doc.location' "$json"` )
      if ($?VERBOSE) echo "$0:t $$ -- Legacy device ${d} at location $c" >& /dev/stderr
      echo "camera motion_${c}_animated:" >> "$out"
      echo "  - platform: mqtt" >> "$out"
      echo "    name: motion_${c}_animated" >> "$out"
      echo "    topic: 'image-animated/"${c}"'" >> "$out"
      echo "" >> "$out"
      set allcameras = ( $allcameras $c )
    endif
  end
else
  if ($?DEBUG) echo "$0:t $$ -- No devices for ${MOTION_DEVICE_DB}" >& /dev/stderr
endif
rm -f "$json"

echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### group.yaml
####

set c = "group"
set components = ( $components "$c" )
set out = "$DATA_DIR/${c}.yaml"; rm -f "$out"
echo "### MOTION $c (auto-generated from $CONFIG_PATH for name $name; devicedb $devicedb)" >> "$out"

## group for motion animated cameras
echo "default_view:" >> "$out"
echo "  view: yes" >> "$out"
echo "  name: Home" >> "$out"
echo "  control: hidden" >> "$out"
echo "  icon: mdi:home" >> "$out"
echo "  entities:" >> "$out"
echo "    - camera.motion_animated" >> "$out"
foreach c ( $cameras )
echo "    - input_boolean.motion_notify_${c}" >> "$out"
echo "    - camera.motion_${c}_image" >> "$out"
echo "    - camera.motion_${c}_animated" >> "$out"
end
echo "" >> "$out"

echo "motion_onoff:" >> "$out"
echo "  view: yes" >> "$out"
echo "  name: motion_onoff" >> "$out"
echo "  control: hidden" >> "$out"
echo "  entities:" >> "$out"
foreach c ( $allcameras )
echo "    - input_boolean.motion_notify_${c}" >> "$out"
end
echo "" >> "$out"

echo "motion_animated_view:" >> "$out"
echo "  view: yes" >> "$out"
echo "  name: motion_animated_view" >> "$out"
echo "  control: hidden" >> "$out"
echo "  icon: mdi:animated" >> "$out"
echo "  entities:" >> "$out"
foreach c ( $allcameras )
echo "    - camera.motion_${c}_animated" >> "$out"
end
echo "" >> "$out"

echo "motion_live_view:" >> "$out"
echo "  view: yes" >> "$out"
echo "  name: motion_live_view" >> "$out"
echo "  control: hidden" >> "$out"
echo "  icon: mdi:camera-timer" >> "$out"
echo "  entities:" >> "$out"
foreach c ( $allcameras )
echo "    - camera.motion_${c}_live" >> "$out"
end
echo "" >> "$out"

echo "$0:t $$ -- processed $out" >& /dev/stderr

####
#### ui-lovelace.yaml
####

set out = "$DATA_DIR/ui-lovelace.yaml"; rm -f "$out"

echo "### MOTION (auto-generated from $CONFIG_PATH for name $name; devicedb $devicedb)" >> "$out"
echo "name: $name" >> "$out"
echo "" >> "$out"
echo "views:" >> "$out"
echo "  - icon: mdi:animation" >> "$out"
echo "    title: ANIMATIONS" >> "$out"
echo "    cards:" >> "$out"
foreach c ( $allcameras )
echo "    - type: picture-entity" >> "$out"
echo "      entity: camera.motion_${c}_animated" >> "$out"
end
echo "  - icon: mdi:webcam" >> "$out"
echo "    title: IMAGES" >> "$out"
echo "    cards:" >> "$out"
foreach c ( $allcameras )
echo "    - type: picture-entity" >> "$out"
echo "      entity: camera.motion_${c}_image" >> "$out"
end
echo "  - icon: mdi:video" >> "$out"
echo "    title: LIVE" >> "$out"
echo "    cards:" >> "$out"
foreach c ( $allcameras )
echo "    - type: picture-entity" >> "$out"
echo "      entity: camera.motion_${c}_live" >> "$out"
end
echo "  - icon: mdi:toggle-switch" >> "$out"
echo "    title: SWITCHES" >> "$out"
echo "    cards:" >> "$out"
echo "    - type: entities" >> "$out"
echo "      title: Controls" >> "$out"
echo "      entities:" >> "$out"
foreach c ( $allcameras )
echo "        - input_boolean.motion_notify_${c}" >> "$out"
end
echo "" >> "$out"
foreach c ( $allcameras )
echo "motion_notify_${c}:" >> "$out"
echo "  name: motion_notify_${c}" >> "$out"
echo "  initial: false" >> "$out"
end

echo "$0:t $$ -- processed $out" >& /dev/stderr

##

echo "$0:t $$ -- finished processing" >& /dev/stderr
