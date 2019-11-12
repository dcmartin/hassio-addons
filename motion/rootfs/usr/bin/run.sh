#!/bin/bash

# motion tools
source /usr/bin/motion-tools.sh

hzn.log.notice $(date) "$0 $*"

if [ ! -s "${CONFIG_PATH}" ]; then
  hzn.log.error "Cannot find options ${CONFIG_PATH}; exiting"
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
hzn.log.trace "Setting device ${VALUE} [MOTION_DEVICE]"
JSON="${JSON}"',"device":"'"${VALUE}"'"'
export MOTION_DEVICE="${VALUE}"

## web
VALUE=$(jq -r ".www" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="${MOTION_DEVICE}.local"; fi
hzn.log.trace "Setting www ${VALUE}"
JSON="${JSON}"',"www":"'"${VALUE}"'"'

##
## device group
##
VALUE=$(jq -r ".group" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="motion"; fi
hzn.log.trace "Setting group ${VALUE} [MOTION_GROUP]"
JSON="${JSON}"',"group":"'"${VALUE}"'"'
export MOTION_GROUP="${VALUE}"

##
## time zone
##
VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="GMT"; fi
hzn.log.trace "Setting TIMEZONE ${VALUE}"
cp /usr/share/zoneinfo/${VALUE} /etc/localtime
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

##
## MQTT
##

# local MQTT server (hassio addon)
VALUE=$(jq -r ".mqtt.host" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="mqtt"; fi
hzn.log.trace "Using MQTT at ${VALUE}"
MQTT='{"host":"'"${VALUE}"'"'
export MQTT_HOST="${VALUE}"
# username
VALUE=$(jq -r ".mqtt.username" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
hzn.log.trace "Using MQTT username: ${VALUE}"
MQTT="${MQTT}"',"username":"'"${VALUE}"'"'
export MQTT_USERNAME="${VALUE}"
# password
VALUE=$(jq -r ".mqtt.password" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
hzn.log.trace "Using MQTT password: ${VALUE}"
MQTT="${MQTT}"',"password":"'"${VALUE}"'"'
export MQTT_PASSWORD="${VALUE}"
# port
VALUE=$(jq -r ".mqtt.port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
hzn.log.trace "Using MQTT port: ${VALUE}"
MQTT="${MQTT}"',"port":'"${VALUE}"'}'
export MQTT_PORT="${VALUE}"
# finish
JSON="${JSON}"',"mqtt":'"${MQTT}"

## WATSON
WVR_URL=$(jq -r ".watson.url" "${CONFIG_PATH}")
WVR_APIKEY=$(jq -r ".watson.apikey" "${CONFIG_PATH}")
WVR_CLASSIFIER=$(jq -r ".watson.classifier" "${CONFIG_PATH}")
WVR_DATE=$(jq -r ".watson.date" "${CONFIG_PATH}")
WVR_VERSION=$(jq -r ".watson.version" "${CONFIG_PATH}")
if [ ! -z "${WVR_URL}" ] && [ ! -z "${WVR_APIKEY}" ] && [ ! -z "${WVR_DATE}" ] && [ ! -z "${WVR_VERSION}" ] && [ "${WVR_URL}" != "null" ] && [ "${WVR_APIKEY}" != "null" ] && [ "${WVR_DATE}" != "null" ] && [ "${WVR_VERSION}" != "null" ]; then
  hzn.log.trace "Watson Visual Recognition at ${WVR_URL} date ${WVR_DATE} version ${WVR_VERSION}"
  WATSON='{"url":"'"${WVR_URL}"'","date":"'"${WVR_DATE}"'","version":"'"${WVR_VERSION}"'","models":['
  if [ ! -z "${WVR_CLASSIFIER}" ] && [ "${WVR_CLASSIFIER}" != "null" ]; then
    # quote the model names
    CLASSIFIERS=$(echo "${WVR_CLASSIFIER}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
    hzn.log.trace "Using classifiers(s): ${CLASSIFIERS}"
    WATSON="${WATSON}""${CLASSIFIERS}"
  else
    # add default iif none specified
    WATSON="${WATSON}"'"default"'
  fi
  WATSON="${WATSON}"']}'
  # make available
  export MOTION_WATSON_APIKEY="${WVR_APIKEY}"
fi
if [ -n "${WATSON:-}" ]; then
  JSON="${JSON}"',"watson":'"${WATSON}"
else
  hzn.log.trace "Watson Visual Recognition not specified"
  JSON="${JSON}"',"watson":null'
fi

## DIGITS
VALUE=$(jq -r ".digits.url" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then
  DIGITS_SERVER_URL="${VALUE}"
  DIGITS='{"url":"'"${DIGITS_SERVER_URL}"'"'
  VALUE=$(jq -r ".digits.jobid" "${CONFIG_PATH}")
  if [ ! -z "${VALUE}" ] && [ "${VALUE}" != "null" ]; then
    DIGITS_JOBIDS=$(echo "${VALUE}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
    hzn.log.trace "Using DIGITS at ${DIGITS_SERVER_URL} and ${DIGITS_JOBIDS}"
    DIGITS="${DIGITS}"',"models":['"${DIGITS_JOBIDS}"']'
  else
    DIGITS="${DIGITS}"',"models":[]'
  fi
  DIGITS="${DIGITS}"'}'
fi
if [ -n "${DIGITS:-}" ]; then
  JSON="${JSON}"',"digits":'"${DIGITS}"
else
  hzn.log.trace "DIGITS not specified"
  JSON="${JSON}"',"digits":null'
fi

###
### MOTION
###

hzn.log.trace "+++ MOTION"

MOTION='{'

# set log_type (FIRST ENTRY)
VALUE=$(jq -r ".log_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="all"; fi
hzn.log.trace "Set log_type to ${VALUE}"
sed -i "s|.*log_type .*|log_type ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"'"log_type":"'"${VALUE}"'"'

# set auto_brightness
VALUE=$(jq -r ".auto_brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
hzn.log.trace "Set auto_brightness to ${VALUE}"
sed -i "s/.*auto_brightness .*/auto_brightness ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"auto_brightness":"'"${VALUE}"'"'

# set locate_motion_mode
VALUE=$(jq -r ".locate_motion_mode" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
hzn.log.trace "Set locate_motion_mode to ${VALUE}"
sed -i "s/.*locate_motion_mode .*/locate_motion_mode ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_mode":"'"${VALUE}"'"'

# set locate_motion_style (box, redbox, cross, redcross)
VALUE=$(jq -r ".locate_motion_style" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="box"; fi
hzn.log.trace "Set locate_motion_style to ${VALUE}"
sed -i "s/.*locate_motion_style .*/locate_motion_style ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_style":"'"${VALUE}"'"'

# set output_pictures (on, off, first, best, center)
VALUE=$(jq -r ".output_pictures" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
hzn.log.trace "Set output_pictures to ${VALUE}"
sed -i "s/.*output_pictures .*/output_pictures ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"output_pictures":"'"${VALUE}"'"'

# set picture_type (jpeg, ppm)
VALUE=$(jq -r ".picture_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="jpeg"; fi
hzn.log.trace "Set picture_type to ${VALUE}"
sed -i "s/.*picture_type .*/picture_type ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_type":"'"${VALUE}"'"'

# set threshold_tune (jpeg, ppm)
VALUE=$(jq -r ".threshold_tune" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
hzn.log.trace "Set threshold_tune to ${VALUE}"
sed -i "s/.*threshold_tune .*/threshold_tune ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold_tune":"'"${VALUE}"'"'

# set netcam_keepalive (off,force,on)
VALUE=$(jq -r ".netcam_keepalive" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
hzn.log.trace "Set netcam_keepalive to ${VALUE}"
sed -i "s/.*netcam_keepalive .*/netcam_keepalive ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"netcam_keepalive":"'"${VALUE}"'"'

## numeric values

# set log_level
VALUE=$(jq -r ".log_motion" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=2; fi
hzn.log.trace "Set motion log_level to ${VALUE}"
sed -i "s/.*log_level\s[0-9]\+/log_level ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_level":'"${VALUE}"

# set v4l2_pallette
VALUE=$(jq -r ".v4l2_pallette" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then
  hzn.log.trace "Set v4l2_pallette to ${VALUE}"
  sed -i "s/.*v4l2_pallette\s[0-9]\+/v4l2_pallette ${VALUE}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"v4l2_pallette":'"${VALUE}"
fi

# set pre_capture
VALUE=$(jq -r ".pre_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn.log.trace "Set pre_capture to ${VALUE}"
sed -i "s/.*pre_capture\s[0-9]\+/pre_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"pre_capture":'"${VALUE}"

# set post_capture
VALUE=$(jq -r ".post_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn.log.trace "Set post_capture to ${VALUE}"
sed -i "s/.*post_capture\s[0-9]\+/post_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"post_capture":'"${VALUE}"

# set event_gap
VALUE=$(jq -r ".event_gap" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=10; fi
hzn.log.trace "Set event_gap to ${VALUE}"
sed -i "s/.*event_gap\s[0-9]\+/event_gap ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"event_gap":'"${VALUE}"

# set minimum_motion_frames
VALUE=$(jq -r ".minimum_motion_frames" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1; fi
hzn.log.trace "Set minimum_motion_frames to ${VALUE}"
sed -i "s/.*minimum_motion_frames\s[0-9]\+/minimum_motion_frames ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_motion_frames":'"${VALUE}"

# set quality
VALUE=$(jq -r ".quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=75; fi
hzn.log.trace "Set quality to ${VALUE}"
sed -i "s/.*quality\s[0-9]\+/quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"quality":'"${VALUE}"

# set width
VALUE=$(jq -r ".width" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=640; fi
hzn.log.trace "Set width to ${VALUE}"
sed -i "s/.*width\s[0-9]\+/width ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"width":'"${VALUE}"

# set height
VALUE=$(jq -r ".height" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=480; fi
hzn.log.trace "Set height to ${VALUE}"
sed -i "s/.*height\s[0-9]\+/height ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"height":'"${VALUE}"

# set framerate
VALUE=$(jq -r ".framerate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=5; fi
hzn.log.trace "Set framerate to ${VALUE}"
sed -i "s/.*framerate\s[0-9]\+/framerate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"framerate":'"${VALUE}"

# set minimum_frame_time
VALUE=$(jq -r ".minimum_frame_time" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn.log.trace "Set minimum_frame_time to ${VALUE}"
sed -i "s/.*minimum_frame_time\s[0-9]\+/minimum_frame_time ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_frame_time":'"${VALUE}"

# set brightness
VALUE=$(jq -r ".brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn.log.trace "Set brightness to ${VALUE}"
sed -i "s/.*brightness\s[0-9]\+/brightness ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"brightness":'"${VALUE}"

# set contrast
VALUE=$(jq -r ".contrast" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn.log.trace "Set contrast to ${VALUE}"
sed -i "s/.*contrast\s[0-9]\+/contrast ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"contrast":'"${VALUE}"

# set saturation
VALUE=$(jq -r ".saturation" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn.log.trace "Set saturation to ${VALUE}"
sed -i "s/.*saturation\s[0-9]\+/saturation ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"saturation":'"${VALUE}"

# set hue
VALUE=$(jq -r ".hue" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn.log.trace "Set hue to ${VALUE}"
sed -i "s/.*hue\s[0-9]\+/hue ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"hue":'"${VALUE}"

# set rotate
VALUE=$(jq -r ".rotate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn.log.trace "Set rotate to ${VALUE}"
sed -i "s/.*rotate\s[0-9]\+/rotate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"rotate":'"${VALUE}"

# set webcontrol_port
VALUE=$(jq -r ".webcontrol_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
hzn.log.trace "Set webcontrol_port to ${VALUE}"
sed -i "s/.*webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"webcontrol_port":'"${VALUE}"

# set stream_port
VALUE=$(jq -r ".stream_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; fi
hzn.log.trace "Set stream_port to ${VALUE}"
sed -i "s/.*stream_port\s[0-9]\+/stream_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_port":'"${VALUE}"

# set stream_quality
VALUE=$(jq -r ".stream_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=50; fi
hzn.log.trace "Set stream_quality to ${VALUE}"
sed -i "s/.*stream_quality\s[0-9]\+/stream_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_quality":'"${VALUE}"

# set threshold
VALUE=$(jq -r ".threshold" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1500; fi
hzn.log.trace "Set threshold to ${VALUE}"
sed -i "s/.*threshold .*/threshold ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold":'"${VALUE}"

# set lightswitch
VALUE=$(jq -r ".lightswitch" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn.log.trace "Set lightswitch to ${VALUE}"
sed -i "s/.*lightswitch\s[0-9]\+/lightswitch ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"lightswitch":'"${VALUE}"

## process collectively

# set username and password
USERNAME=$(jq -r ".username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".password" "${CONFIG_PATH}")
if [ "${USERNAME}" != "null" ] && [ "${PASSWORD}" != "null" ] && [ ! -z "${USERNAME}" ] && [ ! -z "${PASSWORD}" ]; then
  hzn.log.debug "Set authentication to Basic for both stream and webcontrol"
  sed -i "s/.*stream_auth_method.*/stream_auth_method 1/" "${MOTION_CONF}"
  sed -i "s/.*stream_authentication.*/stream_authentication ${USERNAME}:${PASSWORD}/" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_authentication.*/webcontrol_authentication ${USERNAME}:${PASSWORD}/" "${MOTION_CONF}"
  hzn.log.debug "Enable access for any host"
  sed -i "s/.*stream_localhost .*/stream_localhost off/" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_localhost .*/webcontrol_localhost off/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"stream_auth_method":"Basic"'
else
  hzn.log.debug "WARNING: no username and password; stream and webcontrol limited to localhost only"
  sed -i "s/.*stream_localhost .*/stream_localhost on/" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_localhost .*/webcontrol_localhost on/" "${MOTION_CONF}"
fi

# MOTION_DATA_DIR defined for all cameras base path
VALUE=$(jq -r ".target_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_APACHE_HTDOCS}/cameras"; fi
hzn.log.debug "Set target_dir to ${VALUE}"
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
hzn.log.notice "*** Found ${ncamera} cameras"

MOTION_COUNT=1

for ((i = 0 ; i <= 1000 ; i++)); do
  echo "Counter: $i"
done

hzn.log.trace "*** Processing ${ncamera} cameras"
for (( i = 0; i < ncamera ; i++)) ; do
  hzn.log.trace "+++ CAMERA ${i}"

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
      VALUE=$(echo "$VALUE + $MOTION_COUNT" | bc)
      hzn.log.trace "Set webcontrol_port to ${VALUE}"
      sed -i "s/.*webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
      MOTION_COUNT=$(echo "${MOTION_COUNT} + 1" | bc)
      CNUM=0
    else
      CNUM=$(echo "$CNUM + 1" | bc)
    fi
  else
    CNUM=$i
  fi

  ## TOP-LEVEL
  if [ -z "${CAMERAS:-}" ]; then CAMERAS='['; else CAMERAS="${CAMERAS}"','; fi

  hzn.log.trace "CAMERA #: $i CONF: ${MOTION_CONF} NUM: $CNUM"
  CAMERAS="${CAMERAS}"'{"id":'${i}

  # name
  VALUE=$(jq -r '.cameras['${i}'].name' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="camera-name${i}"; fi
  hzn.log.trace "Set name to ${VALUE}"
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
  hzn.log.trace "Set target_dir to ${VALUE}"
  echo "target_dir ${VALUE}" >> "${CAMERA_CONF}"
  if [ ! -d "${VALUE}" ]; then mkdir -p "${VALUE}"; fi
  CAMERAS="${CAMERAS}"',"target_dir":"'"${VALUE}"'"'

  # process camera fov; WCV80n is 61.5 (62); 56 or 75 degrees for PS3 Eye camera
  VALUE=$(jq -r '.cameras['${i}'].fov' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.fov' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=62; fi
  fi
  hzn.log.trace "Set fov to ${VALUE}"
  CAMERAS="${CAMERAS}"',"fov":'"${VALUE}"

  # process camera fps; set on wcv80n web GUI; default 6
  VALUE=$(jq -r '.cameras['${i}'].fps' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.framerate' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=5; fi
  fi
  hzn.log.trace "Set fps to ${VALUE}"
  echo "framerate ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"fps":'"${VALUE}"

  # process camera type; wcv80n, ps3eye, panasonic
  VALUE=$(jq -r '.cameras['${i}'].type' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    VALUE=$(jq -r '.camera_type' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="wcv80n"; fi
  fi
  hzn.log.trace "Set type to ${VALUE}"
  CAMERAS="${CAMERAS}"',"type":"'"${VALUE}"'"'

  # stream_port 
  VALUE=$(jq -r '.cameras['${i}'].port' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; VALUE=$((VALUE + i)); fi
  hzn.log.trace "Set stream_port to ${VALUE}"
  echo "stream_port ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"port":"'"${VALUE}"'"'

  # camera specification; url or device
  VALUE=$(jq -r '.cameras['${i}'].url' "${CONFIG_PATH}")
  if [[ "${VALUE}" == ftpd* ]]; then
    VALUE="${VALUE%*/}.jpg"
    NETCAM_URL=$(echo "${VALUE}" | sed 's|^ftpd|file|')
  elif [ ! -z "${VALUE} ]; then
    # HANDLE NETCAM
    NETCAM_URL="${VALUE}"
  fi
  if [ ! -z "${NETCAM_URL}" ]; then
    CAMERAS="${CAMERAS}"',"url":"'"${VALUE}"'"'
    hzn.log.trace "Set netcam_url to ${NETCAM_URL}"
    echo "netcam_url ${NETCAM_URL}" >> "${CAMERA_CONF}"
  else
    VALUE=$(jq -r '.cameras['${i}'].device' "${CONFIG_PATH}")
    if [[ "${VALUE}" == /dev/video* ]]; then
      echo "videodevice ${VALUE}" >> "${CAMERA_CONF}"
      hzn.log.trace "Set videodevice to ${VALUE}"
    else
      hzn.log.error "Invalid videodevice ${VALUE}"
    fi
  fi

  # palette
  VALUE=$(jq -r '.cameras['${i}'].palette' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_DEFAULT_PALETTE}; fi
  hzn.log.trace "Set palette to ${VALUE}"
  CAMERAS="${CAMERAS}"',"palette":'"${VALUE}"
  echo "v4l2_palette ${VALUE}" >> "${CAMERA_CONF}"
  # keepalive 
  VALUE=$(jq -r '.cameras['${i}'].keepalive' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_keepalive'); fi
  hzn.log.trace "Set netcam_keepalive to ${VALUE}"
  echo "netcam_keepalive ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"keepalive":"'"${VALUE}"'"'
  # userpass 
  VALUE=$(jq -r '.cameras['${i}'].userpass' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=; fi
  hzn.log.trace "Set netcam_userpass to ${VALUE}"
  echo "netcam_userpass ${VALUE}" >> "${CAMERA_CONF}"
  # DO NOT RECORD; CAMERAS="${CAMERAS}"',"userpass":"'"${VALUE}"'"'

  # stream_quality 
  VALUE=$(jq -r '.cameras['${i}'].stream_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_quality'); fi
  hzn.log.trace "Set stream_quality to ${VALUE}"
  echo "stream_quality ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"quality":'"${VALUE}"

  # threshold 
  VALUE=$(jq -r '.cameras['${i}'].threshold' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.threshold'); fi
  hzn.log.trace "Set threshold to ${VALUE}"
  echo "threshold ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"threshold":'"${VALUE}"

  # width 
  VALUE=$(jq -r '.cameras['${i}'].width' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.width'); fi
  hzn.log.trace "Set width to ${VALUE}"
  echo "width ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"width":'"${VALUE}"

  # height 
  VALUE=$(jq -r '.cameras['${i}'].height' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.height'); fi
  hzn.log.trace "Set height to ${VALUE}"
  echo "height ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"height":'"${VALUE}"

  # rotate 
  VALUE=$(jq -r '.cameras['${i}'].rotate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.rotate'); fi
  hzn.log.trace "Set rotate to ${VALUE}"
  echo "rotate ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"rotate":'"${VALUE}"

  # process models string to array of strings
  VALUE=$(jq -r '.cameras['${i}'].models' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    W=$(echo "${WATSON:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"wvr:\1"\2/g' | fmt -1000)
    # hzn.log.trace "WATSON: ${WATSON} ${W}"
    D=$(echo "${DIGITS:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"digits:\1"\2/g' | fmt -1000)
    # hzn.log.trace "DIGITS: ${DIGITS} ${D}"
    VALUE=$(echo ${W} ${D})
    VALUE=$(echo "${VALUE}" | sed "s/ /,/g")
  else
    VALUE=$(echo "${VALUE}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
  fi
  hzn.log.trace "Set models to ${VALUE}"
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
hzn.log.debug "Set unit_system to ${VALUE}"
JSON="${JSON}"',"unit_system":"'"${VALUE}"'"'

# set latitude for events
VALUE=$(jq -r '.latitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
hzn.log.debug "Set latitude to ${VALUE}"
JSON="${JSON}"',"latitude":'"${VALUE}"

# set longitude for events
VALUE=$(jq -r '.longitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
hzn.log.debug "Set longitude to ${VALUE}"
JSON="${JSON}"',"longitude":'"${VALUE}"

# set elevation for events
VALUE=$(jq -r '.elevation' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn.log.debug "Set elevation to ${VALUE}"
JSON="${JSON}"',"elevation":'"${VALUE}"

# set interval for events
VALUE=$(jq -r '.interval' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn.log.debug "Set interval to ${VALUE}"
JSON="${JSON}"',"interval":'"${VALUE}"
export MOTION_EVENT_INTERVAL="${VALUE}"

# set minimum_animate; minimum 2
VALUE=$(jq -r '.minimum_animate' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=2; fi
hzn.log.debug "Set minimum_animate to ${VALUE}"
JSON="${JSON}"',"minimum_animate":'"${VALUE}"

# set post_pictures; enumerated [on,center,first,last,best,most]
VALUE=$(jq -r '.post_pictures' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="center"; fi
hzn.log.debug "Set post_pictures to ${VALUE}"
JSON="${JSON}"',"post_pictures":"'"${VALUE}"'"'
export MOTION_POST_PICTURES="${VALUE}"

# MOTION_SHARE_DIR defined for all cameras base path
VALUE=$(jq -r ".share_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/share/$MOTION_GROUP"; fi
if [ ! -z ${MOTION_SHARE_DIR:-} ]; then echo "*** MOTION_SHARE_DIR *** ${MOTION_SHARE_DIR}"; VALUE="${MOTION_SHARE_DIR}"; else export MOTION_SHARE_DIR="${VALUE}"; fi
hzn.log.debug "Set share_dir to ${VALUE}"
JSON="${JSON}"',"share_dir":"'"${VALUE}"'"'

###
### DONE w/ JSON
###

JSON="${JSON}"'}'

export MOTION_JSON_FILE="${MOTION_CONF%/*}/${MOTION_DEVICE}.json"
echo "${JSON}" | jq '.' > "${MOTION_JSON_FILE}"
if [ ! -s "${MOTION_JSON_FILE}" ]; then
  hzn.log.error "Invalid JSON: ${JSON}"
  exit 1
else
  hzn.log.notice "Publishing configuration to ${MQTT_HOST} topic ${MOTION_GROUP}/${MOTION_DEVICE}/start"
  mqtt_pub -r -q 2 -t "${MOTION_GROUP}/${MOTION_DEVICE}/start" -f "${MOTION_JSON_FILE}"
fi

###
### CLOUDANT
###

URL=$(jq -r ".cloudant.url" "${CONFIG_PATH}")
USERNAME=$(jq -r ".cloudant.username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".cloudant.password" "${CONFIG_PATH}")
if [ "${URL}" != "null" ] && [ "${USERNAME}" != "null" ] && [ "${PASSWORD}" != "null" ] && [ ! -z "${URL}" ] && [ ! -z "${USERNAME}" ] && [ ! -z "${PASSWORD}" ]; then
  hzn.log.trace "Testing CLOUDANT"
  OK=$(curl -sL "${URL}" | jq '.couchdb?!=null')
  if [ "${OK}" == "false" ]; then
    hzn.log.error "Cloudant failed at ${URL}; exiting"
    exit 1
  else
    export MOTION_CLOUDANT_URL="${URL%:*}"'://'"${USERNAME}"':'"${PASSWORD}"'@'"${USERNAME}"."${URL#*.}"
    hzn.log.notice "Cloudant succeeded at ${MOTION_CLOUDANT_URL}; exiting"
  fi
  URL="${MOTION_CLOUDANT_URL}/${MOTION_GROUP}"
  DB=$(curl -sL "${URL}" | jq -r '.db_name')
  if [ "${DB}" != "${MOTION_GROUP}" ]; then
    # create DB
    OK=$(curl -sL -X PUT "${URL}" | jq '.ok')
    if [ "${OK}" != "true" ]; then
      hzn.log.error "Failed to create CLOUDANT DB ${MOTION_GROUP}"
      OFF=TRUE
    else
      hzn.log.notice "Created CLOUDANT DB ${MOTION_GROUP}"
    fi
  else
    hzn.log.debug "CLOUDANT DB ${MOTION_GROUP} exists"
  fi
  if [ -s "${MOTION_JSON_FILE}" ] && [ -z "${OFF:-}" ]; then
    URL="${URL}/${MOTION_DEVICE}"
    REV=$(curl -sL "${URL}" | jq -r '._rev')
    if [ "${REV}" != "null" ] && [ ! -z "${REV}" ]; then
      hzn.log.trace "Prior record exists ${REV}"
      URL="${URL}?rev=${REV}"
    fi
    OK=$(curl -sL "${URL}" -X PUT -d "@${MOTION_JSON_FILE}" | jq '.ok')
    if [ "${OK}" != "true" ]; then
      hzn.log.error "Failed to update ${URL}" $(jq -c '.' "${MOTION_JSON_FILE}")
      exit 1
    else
      hzn.log.trace "Configuration for ${MOTION_DEVICE} at ${MOTION_JSON_FILE}" $(jq -c '.' "${MOTION_JSON_FILE}")
    fi
  else
    hzn.log.error "Failed; no DB or bad JSON"
    exit 1
  fi
else
  hzn.log.warning "Cloudant URL, username and/or password undefined"
fi
if [ -z "${MOTION_CLOUDANT_URL:-}" ]; then
  hzn.log.notice "Cloudant NOT SPECIFIED"
fi

# test hassio
hzn.log.trace "Testing hassio ..." $(curl -sL -H "X-HASSIO-KEY: ${HASSIO_TOKEN}" "http://hassio/supervisor/info" | jq -c '.')
# test homeassistant
hzn.log.trace "Testing homeassistant ..." $(curl -sL -u ":${HASSIO_TOKEN}" "http://hassio/homeassistant/api/states" | jq -c '.')

# start ftp_notifywait for all ftpd:// cameras (uses environment MOTION_JSON_FILE)
ftp_notifywait.sh "${MOTION_JSON_FILE}"

# build new yaml
mkyaml.sh "${CONFIG_PATH}"

# reload configuration
VALUE=$(jq -r ".reload" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="false"; fi
if [ "${VALUE}" != "false" ]; then 
  hzn.log.notice "Re-defining configuration YAML: ${VALUE}"
  JSON="${JSON}"',"reload":'"${VALUE}"
  rlyaml.sh "${VALUE}"
else
  hzn.log.notice "Not re-defining configuration YAML: ${VALUE}"
fi

###
### START MOTION
###

MOTION_CMD=$(command -v motion)
if [ ! -s "${MOTION_CMD}" ] || [ ! -s "${MOTION_CONF}" ]; then
  hzn.log.warning "No motion installed (${MOTION_CMD}) or motion configuration ${MOTION_CONF} does not exist"
else
  hzn.log.debug "Starting ${MOTION_COUNT} motion daemons"
  CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"
  for (( i = 1; i <= MOTION_COUNT;  i++)); do
    # start motion
    hzn.log.debug "*** Start motion ${i} with ${CONF}"
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
  # set environment
  echo 'PassEnv MOTION_JSON_FILE' >> "${MOTION_APACHE_CONF}"
  echo 'PassEnv MOTION_CLOUDANT_URL' >> "${MOTION_APACHE_CONF}"
  echo 'PassEnv MOTION_SHARE_DIR' >> "${MOTION_APACHE_CONF}"
  echo 'PassEnv MOTION_DATA_DIR' >> "${MOTION_APACHE_CONF}"
  echo 'PassEnv MOTION_WATSON_APIKEY' >> "${MOTION_APACHE_CONF}"
  # make /run/apache2 for PID file
  mkdir -p /run/apache2
  # start HTTP daemon in foreground
  hzn.log.notice "Starting Apache: ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT} ${MOTION_APACHE_HTDOCS}"
  httpd -E /dev/stderr -e debug -f "${MOTION_APACHE_CONF}" -DFOREGROUND
fi
