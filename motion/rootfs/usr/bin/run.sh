#!/bin/bash

# motion tools
source /usr/bin/motion-tools.sh

motion.log.notice $(date) "$0 $*"

if [ ! -s "${CONFIG_PATH}" ]; then
  motion.log.error "Cannot find options ${CONFIG_PATH}; exiting"
  exit
fi

if [ -z "${MOTION_STREAM_PORT:-}" ]; then MOTION_STREAM_PORT=8090; fi
if [ -z "${MOTION_CONTROL_PORT:-}" ]; then MOTION_CONTROL_PORT=8080; fi
if [ -z "${MOTION_DEFAULT_PALETTE:-}" ]; then MOTION_DEFAULT_PALETTE=8; fi

###
### START JSON
###
JSON='{"config_path":"'"${CONFIG_PATH}"'","ipaddr":"'$(hostname -i)'","hostname":"'"$(hostname)"'","arch":"'$(arch)'","date":'$(/bin/date +%s)


##
## host name
##
VALUE=$(jq -r ".device" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="${HOSTNAME}"; fi
motion.log.trace "Setting device ${VALUE} [MOTION_DEVICE]"
JSON="${JSON}"',"device":"'"${VALUE}"'"'
export MOTION_DEVICE="${VALUE}"

## web
VALUE=$(jq -r ".www" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="${MOTION_DEVICE}.local"; fi
motion.log.trace "Setting www ${VALUE}"
JSON="${JSON}"',"www":"'"${VALUE}"'"'

##
## device group
##
VALUE=$(jq -r ".group" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="motion"; fi
motion.log.trace "Setting group ${VALUE} [MOTION_GROUP]"
JSON="${JSON}"',"group":"'"${VALUE}"'"'
export MOTION_GROUP="${VALUE}"

##
## time zone
##
VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="GMT"; fi
motion.log.trace "Setting TIMEZONE ${VALUE}"
cp /usr/share/zoneinfo/${VALUE} /etc/localtime
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

##
## MQTT
##

# local MQTT server (hassio addon)
VALUE=$(jq -r ".mqtt.host" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="mqtt"; fi
motion.log.trace "Using MQTT at ${VALUE}"
MQTT='{"host":"'"${VALUE}"'"'
export MQTT_HOST="${VALUE}"
# username
VALUE=$(jq -r ".mqtt.username" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
motion.log.trace "Using MQTT username: ${VALUE}"
MQTT="${MQTT}"',"username":"'"${VALUE}"'"'
export MQTT_USERNAME="${VALUE}"
# password
VALUE=$(jq -r ".mqtt.password" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
motion.log.trace "Using MQTT password: ${VALUE}"
MQTT="${MQTT}"',"password":"'"${VALUE}"'"'
export MQTT_PASSWORD="${VALUE}"
# port
VALUE=$(jq -r ".mqtt.port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
motion.log.trace "Using MQTT port: ${VALUE}"
MQTT="${MQTT}"',"port":'"${VALUE}"'}'
export MQTT_PORT="${VALUE}"
# finish
JSON="${JSON}"',"mqtt":'"${MQTT}"

## WATSON
if [ -n "${WATSON:-}" ]; then
  JSON="${JSON}"',"watson":'"${WATSON}"
else
  motion.log.trace "Watson Visual Recognition not specified"
  JSON="${JSON}"',"watson":null'
fi

## DIGITS
if [ -n "${DIGITS:-}" ]; then
  JSON="${JSON}"',"digits":'"${DIGITS}"
else
  motion.log.trace "DIGITS not specified"
  JSON="${JSON}"',"digits":null'
fi

###
### MOTION
###

motion.log.trace "+++ MOTION"

MOTION='{'

# set log_type (FIRST ENTRY)
VALUE=$(jq -r ".log_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="all"; fi
sed -i "s|.*log_type.*|log_type ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"'"log_type":"'"${VALUE}"'"'
motion.log.trace "Set log_type to ${VALUE}"

# set log_level
VALUE=$(jq -r ".log_motion" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=6; fi
sed -i "s/.*log_level.*/log_level ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_level":'"${VALUE}"
motion.log.trace "Set motion log_level to ${VALUE}"

# set log_file
VALUE=$(jq -r ".log_file" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/tmp/motion.log"; fi
sed -i "s/.*log_file.*/log_file ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_file":"'"${VALUE}"'"'
motion.log.trace "Set motion log_file to ${VALUE}"

# set auto_brightness
VALUE=$(jq -r ".auto_brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*auto_brightness.*/auto_brightness ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"auto_brightness":"'"${VALUE}"'"'
motion.log.trace "Set auto_brightness to ${VALUE}"

# set locate_motion_mode
VALUE=$(jq -r ".locate_motion_mode" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
sed -i "s/.*locate_motion_mode.*/locate_motion_mode ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_mode":"'"${VALUE}"'"'
motion.log.trace "Set locate_motion_mode to ${VALUE}"

# set locate_motion_style (box, redbox, cross, redcross)
VALUE=$(jq -r ".locate_motion_style" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="box"; fi
sed -i "s/.*locate_motion_style.*/locate_motion_style ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_style":"'"${VALUE}"'"'
motion.log.trace "Set locate_motion_style to ${VALUE}"

# set picture_output (on, off, first, best, center)
VALUE=$(jq -r ".picture_output" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*picture_output.*/picture_output ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_output":"'"${VALUE}"'"'
motion.log.trace "Set picture_output to ${VALUE}"

# set picture_type (jpeg, ppm)
VALUE=$(jq -r ".picture_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="jpeg"; fi
sed -i "s/.*picture_type .*/picture_type ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_type":"'"${VALUE}"'"'
motion.log.trace "Set picture_type to ${VALUE}"

# set threshold_tune (jpeg, ppm)
VALUE=$(jq -r ".threshold_tune" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*threshold_tune .*/threshold_tune ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold_tune":"'"${VALUE}"'"'
motion.log.trace "Set threshold_tune to ${VALUE}"

# set netcam_keepalive (off,force,on)
VALUE=$(jq -r ".netcam_keepalive" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*netcam_keepalive .*/netcam_keepalive ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"netcam_keepalive":"'"${VALUE}"'"'
motion.log.trace "Set netcam_keepalive to ${VALUE}"

## numeric values

# set v4l2_pallette
VALUE=$(jq -r ".v4l2_pallette" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then
  sed -i "s/.*v4l2_pallette\s[0-9]\+/v4l2_pallette ${VALUE}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"v4l2_pallette":'"${VALUE}"
  motion.log.trace "Set v4l2_pallette to ${VALUE}"
fi

# set pre_capture
VALUE=$(jq -r ".pre_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/.*pre_capture\s[0-9]\+/pre_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"pre_capture":'"${VALUE}"
motion.log.trace "Set pre_capture to ${VALUE}"

# set post_capture
VALUE=$(jq -r ".post_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/.*post_capture\s[0-9]\+/post_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"post_capture":'"${VALUE}"
motion.log.trace "Set post_capture to ${VALUE}"

# set event_gap
VALUE=$(jq -r ".event_gap" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=10; fi
sed -i "s/.*event_gap\s[0-9]\+/event_gap ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"event_gap":'"${VALUE}"
motion.log.trace "Set event_gap to ${VALUE}"

# set minimum_motion_frames
VALUE=$(jq -r ".minimum_motion_frames" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=10; fi
sed -i "s/.*minimum_motion_frames\s[0-9]\+/minimum_motion_frames ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_motion_frames":'"${VALUE}"
motion.log.trace "Set minimum_motion_frames to ${VALUE}"

# set quality
VALUE=$(jq -r ".picture_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=100; fi
sed -i "s/.*picture_quality\s[0-9]\+/picture_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_quality":'"${VALUE}"
motion.log.trace "Set picture_quality to ${VALUE}"

# set width
VALUE=$(jq -r ".width" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=640; fi
sed -i "s/.*width\s[0-9]\+/width ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"width":'"${VALUE}"
motion.log.trace "Set width to ${VALUE}"

# set height
VALUE=$(jq -r ".height" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=480; fi
sed -i "s/.*height\s[0-9]\+/height ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"height":'"${VALUE}"
motion.log.trace "Set height to ${VALUE}"

# set framerate
VALUE=$(jq -r ".framerate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=5; fi
sed -i "s/.*framerate\s[0-9]\+/framerate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"framerate":'"${VALUE}"
motion.log.trace "Set framerate to ${VALUE}"

# set minimum_frame_time
VALUE=$(jq -r ".minimum_frame_time" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/.*minimum_frame_time\s[0-9]\+/minimum_frame_time ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_frame_time":'"${VALUE}"
motion.log.trace "Set minimum_frame_time to ${VALUE}"

## vid_control_params

# set brightness
VALUE=$(jq -r ".brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/brightness=[0-9]\+/brightness=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"brightness":'"${VALUE}"
motion.log.trace "Set brightness to ${VALUE}"

# set contrast
VALUE=$(jq -r ".contrast" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/contrast=[0-9]\+/contrast ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"contrast":'"${VALUE}"
motion.log.trace "Set contrast to ${VALUE}"

# set saturation
VALUE=$(jq -r ".saturation" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/saturation=[0-9]\+/saturation=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"saturation":'"${VALUE}"
motion.log.trace "Set saturation to ${VALUE}"

# set hue
VALUE=$(jq -r ".hue" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/hue=[0-9]\+/hue=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"hue":'"${VALUE}"
motion.log.trace "Set hue to ${VALUE}"

## other

# set rotate
VALUE=$(jq -r ".rotate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
motion.log.trace "Set rotate to ${VALUE}"
sed -i "s/.*rotate\s[0-9]\+/rotate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"rotate":'"${VALUE}"

# set webcontrol_port
VALUE=$(jq -r ".webcontrol_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
motion.log.trace "Set webcontrol_port to ${VALUE}"
sed -i "s/.*webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"webcontrol_port":'"${VALUE}"

# set stream_port
VALUE=$(jq -r ".stream_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; fi
motion.log.trace "Set stream_port to ${VALUE}"
sed -i "s/.*stream_port\s[0-9]\+/stream_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_port":'"${VALUE}"

# set stream_quality
VALUE=$(jq -r ".stream_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=100; fi
motion.log.trace "Set stream_quality to ${VALUE}"
sed -i "s/.*stream_quality\s[0-9]\+/stream_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_quality":'"${VALUE}"

# set threshold
VALUE=$(jq -r ".threshold" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1500; fi
motion.log.trace "Set threshold to ${VALUE}"
sed -i "s/.*threshold.*/threshold ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold":'"${VALUE}"

# set lightswitch
VALUE=$(jq -r ".lightswitch" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
motion.log.trace "Set lightswitch to ${VALUE}"
sed -i "s/.*lightswitch.*/lightswitch ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"lightswitch":'"${VALUE}"

## process collectively

# set username and password
USERNAME=$(jq -r ".username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".password" "${CONFIG_PATH}")
if [ "${USERNAME}" != "null" ] && [ "${PASSWORD}" != "null" ] && [ ! -z "${USERNAME}" ] && [ ! -z "${PASSWORD}" ]; then
  motion.log.debug "Set authentication to Basic for both stream and webcontrol"
  sed -i "s/.*stream_auth_method.*/stream_auth_method 1/" "${MOTION_CONF}"
  sed -i "s/.*stream_authentication.*/stream_authentication ${USERNAME}:${PASSWORD}/" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_authentication.*/webcontrol_authentication ${USERNAME}:${PASSWORD}/" "${MOTION_CONF}"
  motion.log.debug "Enable access for any host"
  sed -i "s/.*stream_localhost .*/stream_localhost off/" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_localhost .*/webcontrol_localhost off/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"stream_auth_method":"Basic"'
else
  motion.log.debug "WARNING: no username and password; stream and webcontrol limited to localhost only"
  sed -i "s/.*stream_localhost .*/stream_localhost on/" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_localhost .*/webcontrol_localhost on/" "${MOTION_CONF}"
fi

# MOTION_DATA_DIR defined for all cameras base path
VALUE=$(jq -r ".target_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_APACHE_HTDOCS}/cameras"; fi
motion.log.debug "Set target_dir to ${VALUE}"
sed -i "s|.*target_dir.*|target_dir ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"target_dir":"'"${VALUE}"'"'
export MOTION_DATA_DIR="${VALUE}"

## end motion structure; cameras section depends on well-formed JSON for $MOTION
MOTION="${MOTION}"'}'

## append to configuration JSON
JSON="${JSON}"',"motion":'"${MOTION}"

###
### process cameras 
###

ncamera=$(jq '.cameras|length' "${CONFIG_PATH}")
motion.log.notice "*** Found ${ncamera} cameras"

MOTION_COUNT=1

for (( i = 0; i < ncamera; i++)) ; do
  motion.log.trace "+++ CAMERA ${i}"

  ## handle more than one motion process (10 camera/process)
  if (( i / 10 )); then
    if (( i % 10 == 0 )); then
      CONF="${MOTION_CONF%%.*}.${MOTION_COUNT}.${MOTION_CONF##*.}"
      cp "${MOTION_CONF}" "${CONF}"
      sed -i 's|^camera|; camera|' "${CONF}"
      MOTION_CONF=${CONF}
      # get webcontrol_port (base)
      VALUE=$(jq -r ".webcontrol_port" "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
      VALUE=$((VALUE + MOTION_COUNT))
      motion.log.trace "Set webcontrol_port to ${VALUE}"
      sed -i "s/.*webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
      MOTION_COUNT=$((MOTION_COUNT + 1))
      CNUM=0
    else
      CNUM=$((CNUM + 1))
    fi
  else
    CNUM=$i
  fi

  ## TOP-LEVEL
  if [ -z "${CAMERAS:-}" ]; then CAMERAS='['; else CAMERAS="${CAMERAS}"','; fi

  motion.log.trace "CAMERA #: $i CONF: ${MOTION_CONF} NUM: $CNUM"
  CAMERAS="${CAMERAS}"'{"id":'${i}

  # name
  VALUE=$(jq -r '.cameras['${i}'].name' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="camera-name${i}"; fi
  motion.log.trace "Set name to ${VALUE}"
  CAMERAS="${CAMERAS}"',"name":"'"${VALUE}"'"'
  CNAME=${VALUE}
  if [ ${MOTION_CONF%/*} != ${MOTION_CONF} ]; then 
    CAMERA_CONF="${MOTION_CONF%/*}/${CNAME}.conf"
  else
    CAMERA_CONF="${CNAME}.conf"
  fi
  echo "camera_id ${CNUM}" > "${CAMERA_CONF}"
  echo "camera_name ${VALUE}" >> "${CAMERA_CONF}"

  # target_dir 
  VALUE=$(jq -r '.cameras['${i}'].target_dir' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_DATA_DIR}/${CNAME}"; fi
  motion.log.trace "Set target_dir to ${VALUE}"
  echo "target_dir ${VALUE}" >> "${CAMERA_CONF}"
  if [ ! -d "${VALUE}" ]; then mkdir -p "${VALUE}"; fi
  CAMERAS="${CAMERAS}"',"target_dir":"'"${VALUE}"'"'

  # stream_port (calculated)
  VALUE=$(jq -r '.cameras['${i}'].port' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; VALUE=$((VALUE + i)); fi
  motion.log.trace "Set stream_port to ${VALUE}"
  echo "stream_port ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"port":"'"${VALUE}"'"'

  # process camera type; wcv80n, ps3eye, panasonic
  VALUE=$(jq -r '.cameras['${i}'].type' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    VALUE=$(jq -r '.camera_type' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="wcv80n"; fi
  fi
  motion.log.trace "Set type to ${VALUE}"
  CAMERAS="${CAMERAS}"',"type":"'"${VALUE}"'"'

  # camera specification; url or device
  VALUE=$(jq -r '.cameras['${i}'].url' "${CONFIG_PATH}")
  if [ ! -z "${VALUE:-}" ] && [ "${VALUE:-}" != 'null' ]; then
    # url
    if [[ "${VALUE}" == ftpd* ]]; then
      VALUE="${VALUE%*/}.jpg"
      VALUE=$(echo "${VALUE}" | sed 's|^ftpd|file|')
    fi
    motion.log.trace "Set netcam_url to ${VALUE}"
    CAMERAS="${CAMERAS}"',"url":"'"${VALUE}"'"'
    echo "netcam_url ${VALUE}" >> "${CAMERA_CONF}"

    # keepalive 
    VALUE=$(jq -r '.cameras['${i}'].keepalive' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_keepalive'); fi
    motion.log.trace "Set netcam_keepalive to ${VALUE}"
    echo "netcam_keepalive ${VALUE}" >> "${CAMERA_CONF}"
    CAMERAS="${CAMERAS}"',"keepalive":"'"${VALUE}"'"'

    # userpass 
    VALUE=$(jq -r '.cameras['${i}'].userpass' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=; fi
    motion.log.trace "Set netcam_userpass to ${VALUE}"
    echo "netcam_userpass ${VALUE}" >> "${CAMERA_CONF}"
    # DO NOT RECORD; CAMERAS="${CAMERAS}"',"userpass":"'"${VALUE}"'"'
  else
    # local device
    VALUE=$(jq -r '.cameras['${i}'].device' "${CONFIG_PATH}")
    if [[ "${VALUE}" == /dev/video* ]]; then
      echo "videodevice ${VALUE}" >> "${CAMERA_CONF}"
      motion.log.trace "Set videodevice to ${VALUE}"
    else
      motion.log.error "Invalid videodevice ${VALUE}"
    fi
  fi

  # palette
  VALUE=$(jq -r '.cameras['${i}'].palette' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_DEFAULT_PALETTE}; fi
  motion.log.trace "Set palette to ${VALUE}"
  CAMERAS="${CAMERAS}"',"palette":'"${VALUE}"
  echo "v4l2_palette ${VALUE}" >> "${CAMERA_CONF}"

  # picture_quality 
  VALUE=$(jq -r '.cameras['${i}'].picture_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.picture_quality'); fi
  motion.log.trace "Set picture_quality to ${VALUE}"
  echo "picture_quality ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"picture_quality":'"${VALUE}"

  # stream_quality 
  VALUE=$(jq -r '.cameras['${i}'].stream_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_quality'); fi
  motion.log.trace "Set stream_quality to ${VALUE}"
  echo "stream_quality ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"stream_quality":'"${VALUE}"

  # threshold 
  VALUE=$(jq -r '.cameras['${i}'].threshold' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.threshold'); fi
  motion.log.trace "Set threshold to ${VALUE}"
  echo "threshold ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"threshold":'"${VALUE}"

  # width 
  VALUE=$(jq -r '.cameras['${i}'].width' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.width'); fi
  motion.log.trace "Set width to ${VALUE}"
  echo "width ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"width":'"${VALUE}"

  # height 
  VALUE=$(jq -r '.cameras['${i}'].height' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.height'); fi
  motion.log.trace "Set height to ${VALUE}"
  echo "height ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"height":'"${VALUE}"

  # rotate 
  VALUE=$(jq -r '.cameras['${i}'].rotate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.rotate'); fi
  motion.log.trace "Set rotate to ${VALUE}"
  echo "rotate ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"rotate":'"${VALUE}"

  # process camera fov; WCV80n is 61.5 (62); 56 or 75 degrees for PS3 Eye camera
  VALUE=$(jq -r '.cameras['${i}'].fov' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.fov' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=62; fi
  fi
  motion.log.trace "Set fov to ${VALUE}"
  CAMERAS="${CAMERAS}"',"fov":'"${VALUE}"

  # process camera fps; set on wcv80n web GUI; default 6
  VALUE=$(jq -r '.cameras['${i}'].fps' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.framerate' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=5; fi
  fi
  motion.log.trace "Set fps to ${VALUE}"
  echo "framerate ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"fps":'"${VALUE}"

  # process models string to array of strings
  VALUE=$(jq -r '.cameras['${i}'].models' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    W=$(echo "${WATSON:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"wvr:\1"\2/g' | fmt -1000)
    # motion.log.trace "WATSON: ${WATSON} ${W}"
    D=$(echo "${DIGITS:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"digits:\1"\2/g' | fmt -1000)
    # motion.log.trace "DIGITS: ${DIGITS} ${D}"
    VALUE=$(echo ${W} ${D})
    VALUE=$(echo "${VALUE}" | sed "s/ /,/g")
  else
    VALUE=$(echo "${VALUE}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
  fi
  motion.log.trace "Set models to ${VALUE}"
  CAMERAS="${CAMERAS}"',"models":['"${VALUE}"']'

  ## close CAMERAS structure
  CAMERAS="${CAMERAS}"'}'

  # add new camera configuration
  echo "camera ${CAMERA_CONF}" >> "${MOTION_CONF}"
done

### DONE w/ MOTION_CONF

## append to configuration JSON
if [ -n "${CAMERAS:-}" ]; then 
  JSON="${JSON}"',"cameras":'"${CAMERAS}"']'
fi

# set unit_system for events
VALUE=$(jq -r '.unit_system' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="imperial"; fi
motion.log.debug "Set unit_system to ${VALUE}"
JSON="${JSON}"',"unit_system":"'"${VALUE}"'"'

# set latitude for events
VALUE=$(jq -r '.latitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
motion.log.debug "Set latitude to ${VALUE}"
JSON="${JSON}"',"latitude":'"${VALUE}"

# set longitude for events
VALUE=$(jq -r '.longitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
motion.log.debug "Set longitude to ${VALUE}"
JSON="${JSON}"',"longitude":'"${VALUE}"

# set elevation for events
VALUE=$(jq -r '.elevation' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
motion.log.debug "Set elevation to ${VALUE}"
JSON="${JSON}"',"elevation":'"${VALUE}"

# set interval for events
VALUE=$(jq -r '.interval' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
motion.log.debug "Set interval to ${VALUE}"
JSON="${JSON}"',"interval":'"${VALUE}"
export MOTION_EVENT_INTERVAL="${VALUE}"

# set minimum_animate; minimum 2
VALUE=$(jq -r '.minimum_animate' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=2; fi
motion.log.debug "Set minimum_animate to ${VALUE}"
JSON="${JSON}"',"minimum_animate":'"${VALUE}"

# set post_pictures; enumerated [on,center,first,last,best,most]
VALUE=$(jq -r '.post_pictures' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="center"; fi
motion.log.debug "Set post_pictures to ${VALUE}"
JSON="${JSON}"',"post_pictures":"'"${VALUE}"'"'
export MOTION_POST_PICTURES="${VALUE}"

# MOTION_SHARE_DIR defined for all cameras base path
VALUE=$(jq -r ".share_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/share/$MOTION_GROUP"; fi
if [ ! -z ${MOTION_SHARE_DIR:-} ]; then echo "*** MOTION_SHARE_DIR *** ${MOTION_SHARE_DIR}"; VALUE="${MOTION_SHARE_DIR}"; else export MOTION_SHARE_DIR="${VALUE}"; fi
motion.log.debug "Set share_dir to ${VALUE}"
JSON="${JSON}"',"share_dir":"'"${VALUE}"'"'

###
### DONE w/ JSON
###

JSON="${JSON}"'}'

export MOTION_JSON_FILE="${MOTION_CONF%/*}/${MOTION_DEVICE}.json"
echo "${JSON}" | jq '.' > "${MOTION_JSON_FILE}"
if [ ! -s "${MOTION_JSON_FILE}" ]; then
  motion.log.error "Invalid JSON: ${JSON}"
  exit 1
else
  motion.log.notice "Publishing configuration to ${MQTT_HOST} topic ${MOTION_GROUP}/${MOTION_DEVICE}/start"
  mqtt_pub -r -q 2 -t "${MOTION_GROUP}/${MOTION_DEVICE}/start" -f "${MOTION_JSON_FILE}"
fi

###
### CLOUDANT
###

URL=$(jq -r ".cloudant.url" "${CONFIG_PATH}")
USERNAME=$(jq -r ".cloudant.username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".cloudant.password" "${CONFIG_PATH}")
if [ "${URL}" != "null" ] && [ "${USERNAME}" != "null" ] && [ "${PASSWORD}" != "null" ] && [ ! -z "${URL}" ] && [ ! -z "${USERNAME}" ] && [ ! -z "${PASSWORD}" ]; then
  motion.log.trace "Testing CLOUDANT"
  OK=$(curl -sL "${URL}" | jq '.couchdb?!=null')
  if [ "${OK}" == "false" ]; then
    motion.log.error "Cloudant failed at ${URL}; exiting"
    exit 1
  else
    export MOTION_CLOUDANT_URL="${URL%:*}"'://'"${USERNAME}"':'"${PASSWORD}"'@'"${USERNAME}"."${URL#*.}"
    motion.log.notice "Cloudant succeeded at ${MOTION_CLOUDANT_URL}; exiting"
  fi
  URL="${MOTION_CLOUDANT_URL}/${MOTION_GROUP}"
  DB=$(curl -sL "${URL}" | jq -r '.db_name')
  if [ "${DB}" != "${MOTION_GROUP}" ]; then
    # create DB
    OK=$(curl -sL -X PUT "${URL}" | jq '.ok')
    if [ "${OK}" != "true" ]; then
      motion.log.error "Failed to create CLOUDANT DB ${MOTION_GROUP}"
      OFF=TRUE
    else
      motion.log.notice "Created CLOUDANT DB ${MOTION_GROUP}"
    fi
  else
    motion.log.debug "CLOUDANT DB ${MOTION_GROUP} exists"
  fi
  if [ -s "${MOTION_JSON_FILE}" ] && [ -z "${OFF:-}" ]; then
    URL="${URL}/${MOTION_DEVICE}"
    REV=$(curl -sL "${URL}" | jq -r '._rev')
    if [ "${REV}" != "null" ] && [ ! -z "${REV}" ]; then
      motion.log.trace "Prior record exists ${REV}"
      URL="${URL}?rev=${REV}"
    fi
    OK=$(curl -sL "${URL}" -X PUT -d "@${MOTION_JSON_FILE}" | jq '.ok')
    if [ "${OK}" != "true" ]; then
      motion.log.error "Failed to update ${URL}" $(jq -c '.' "${MOTION_JSON_FILE}")
      exit 1
    else
      motion.log.trace "Configuration for ${MOTION_DEVICE} at ${MOTION_JSON_FILE}" $(jq -c '.' "${MOTION_JSON_FILE}")
    fi
  else
    motion.log.error "Failed; no DB or bad JSON"
    exit 1
  fi
else
  motion.log.warn "Cloudant URL, username and/or password undefined"
fi
if [ -z "${MOTION_CLOUDANT_URL:-}" ]; then
  motion.log.notice "Cloudant NOT SPECIFIED"
fi

# test hassio
motion.log.trace "Testing hassio ... $(curl -sL -H "X-HASSIO-KEY: ${HASSIO_TOKEN}" "http://hassio/supervisor/info" | jq -c '.')"
# test homeassistant
motion.log.trace "Testing homeassistant ... $(curl -sL -u ":${HASSIO_TOKEN}" "http://hassio/homeassistant/api/states" | jq -c '.')"

# start ftp_notifywait for all ftpd:// cameras (uses environment MOTION_JSON_FILE)
ftp_notifywait.sh "${MOTION_JSON_FILE}"

# build new yaml
mkyaml.sh "${CONFIG_PATH}"

# reload configuration
VALUE=$(jq -r ".reload" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="false"; fi
if [ "${VALUE}" != "false" ]; then 
  motion.log.notice "Re-defining configuration YAML: ${VALUE}"
  JSON="${JSON}"',"reload":'"${VALUE}"
  rlyaml.sh "${VALUE}"
else
  motion.log.notice "Not re-defining configuration YAML: ${VALUE}"
fi

###
### START MOTION
###

MOTION_CMD=$(command -v motion)
if [ ! -s "${MOTION_CMD}" ] || [ ! -s "${MOTION_CONF}" ]; then
  motion.log.warn "No motion installed ${MOTION_CMD} or motion configuration ${MOTION_CONF} does not exist"
else
  motion.log.debug "Starting ${MOTION_COUNT} motion daemons"
  CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"
  for (( i = 1; i <= MOTION_COUNT;  i++)); do
    # start motion
    motion.log.debug "*** Start motion ${i} with ${CONF}"
    motion -b -c "${CONF}"
    CONF="${MOTION_CONF%%.*}.${i}.${MOTION_CONF##*.}"
  done
fi

###
### initialize camera(s)
###
 
initcams.sh "${MOTION_JSON_FILE}"

###
### START HTTPD
###
if [ -s "${MOTION_APACHE_CONF}" ]; then
  # edit defaults
  sed -i 's|^Listen \(.*\)|Listen '${MOTION_APACHE_PORT}'|' "${MOTION_APACHE_CONF}"
  sed -i 's|^ServerName \(.*\)|ServerName '"${MOTION_APACHE_HOST}:${MOTION_APACHE_PORT}"'|' "${MOTION_APACHE_CONF}"
  sed -i 's|^ServerAdmin \(.*\)|ServerAdmin '"${MOTION_APACHE_ADMIN}"'|' "${MOTION_APACHE_CONF}"
  # sed -i 's|^ServerTokens \(.*\)|ServerTokens '"${MOTION_APACHE_TOKENS}"'|' "${MOTION_APACHE_CONF}"
  # sed -i 's|^ServerSignature \(.*\)|ServerSignature '"${MOTION_APACHE_SIGNATURE}"'|' "${MOTION_APACHE_CONF}"
  # enable CGI
  sed -i 's|^\([^#]\)#LoadModule cgi|\1LoadModule cgi|' "${MOTION_APACHE_CONF}"
  # pass environment
  echo 'PassEnv MOTION_JSON_FILE' >> "${MOTION_APACHE_CONF}"
  echo 'PassEnv MOTION_SHARE_DIR' >> "${MOTION_APACHE_CONF}"
  echo 'PassEnv MOTION_DATA_DIR' >> "${MOTION_APACHE_CONF}"
  if [ ! -z "${MOTION_CLOUDANT_URL:-}" ]; then
    echo 'PassEnv MOTION_CLOUDANT_URL' >> "${MOTION_APACHE_CONF}"
  fi
  if [ ! -z "${MOTION_WATSON_APIKEY:-}" ]; then
    echo 'PassEnv MOTION_WATSON_APIKEY' >> "${MOTION_APACHE_CONF}"
  fi
  # make /run/apache2 for PID file
  mkdir -p /run/apache2
  # start HTTP daemon in foreground
  motion.log.notice "Starting Apache: ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT} ${MOTION_APACHE_HTDOCS}"
  httpd -E /dev/stderr -e debug -f "${MOTION_APACHE_CONF}" -DFOREGROUND
fi
