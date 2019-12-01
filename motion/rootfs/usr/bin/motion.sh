#!/bin/bash

## intialize log level from top-level
export MOTION_LOG_LEVEL="${1}"
source /usr/bin/motion-tools.sh

###
### START
###

# defaults
if [ -z "${MOTION_STREAM_PORT:-}" ]; then MOTION_STREAM_PORT=8090; fi
if [ -z "${MOTION_CONTROL_PORT:-}" ]; then MOTION_CONTROL_PORT=8080; fi
if [ -z "${MOTION_DEFAULT_PALETTE:-}" ]; then MOTION_DEFAULT_PALETTE=15; fi


## build internal configuration
JSON='{"config_path":"'"${CONFIG_PATH}"'","ipaddr":"'$(hostname -i)'","hostname":"'"$(hostname)"'","arch":"'$(arch)'","date":'$(/bin/date +%s)

# device name
VALUE=$(jq -r ".device" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="${HOSTNAME}"; fi
JSON="${JSON}"',"device":"'"${VALUE}"'"'
motion.log.debug "setting device ${VALUE} [MOTION_DEVICE]"

# device group
VALUE=$(jq -r ".group" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="motion"; fi
JSON="${JSON}"',"group":"'"${VALUE}"'"'
motion.log.debug "setting group ${VALUE} [MOTION_GROUP]"
MOTION_GROUP="${VALUE}"

## web
VALUE=$(jq -r ".www" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="${MOTION_DEVICE}.local"; fi
motion.log.debug "setting www ${VALUE}"
JSON="${JSON}"',"www":"'"${VALUE}"'"'

## time zone
VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="GMT"; fi
motion.log.debug "setting TIMEZONE ${VALUE}"
cp /usr/share/zoneinfo/${VALUE} /etc/localtime
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

##
## MQTT
##

# local MQTT server (hassio addon)
VALUE=$(jq -r ".mqtt.host" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="mqtt"; fi
motion.log.debug "Using MQTT at ${VALUE}"
MQTT='{"host":"'"${VALUE}"'"'
# username
VALUE=$(jq -r ".mqtt.username" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
motion.log.debug "Using MQTT username: ${VALUE}"
MQTT="${MQTT}"',"username":"'"${VALUE}"'"'
# password
VALUE=$(jq -r ".mqtt.password" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
motion.log.debug "Using MQTT password: ${VALUE}"
MQTT="${MQTT}"',"password":"'"${VALUE}"'"'
# port
VALUE=$(jq -r ".mqtt.port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
motion.log.debug "Using MQTT port: ${VALUE}"
MQTT="${MQTT}"',"port":'"${VALUE}"'}'

## finish
JSON="${JSON}"',"mqtt":'"${MQTT}"

###
## WATSON
###

if [ -n "${WATSON:-}" ]; then
  JSON="${JSON}"',"watson":'"${WATSON}"
else
  motion.log.debug "Watson Visual Recognition not specified"
  JSON="${JSON}"',"watson":null'
fi

###
## DIGITS
###

if [ -n "${DIGITS:-}" ]; then
  JSON="${JSON}"',"digits":'"${DIGITS}"
else
  motion.log.debug "DIGITS not specified"
  JSON="${JSON}"',"digits":null'
fi

###
### MOTION
###

motion.log.debug "+++ MOTION"

MOTION='{'

# set log_type (FIRST ENTRY)
VALUE=$(jq -r ".log_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="all"; fi
sed -i "s|.*log_type.*|log_type ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"'"log_type":"'"${VALUE}"'"'
motion.log.debug "Set log_type to ${VALUE}"

# set log_level
VALUE=$(jq -r ".log_motion" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=6; fi
sed -i "s/.*log_level.*/log_level ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_motion":'"${VALUE}"
motion.log.debug "Set log_motion to ${VALUE}"

# set log_file
VALUE=$(jq -r ".log_file" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/tmp/motion.log"; fi
sed -i "s|.*log_file.*|log_file ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_file":"'"${VALUE}"'"'
motion.log.debug "Set log_file to ${VALUE}"

# set auto_brightness
VALUE=$(jq -r ".auto_brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*auto_brightness.*/auto_brightness ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"auto_brightness":"'"${VALUE}"'"'
motion.log.debug "Set auto_brightness to ${VALUE}"

# set locate_motion_mode
VALUE=$(jq -r ".locate_motion_mode" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
sed -i "s/.*locate_motion_mode.*/locate_motion_mode ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_mode":"'"${VALUE}"'"'
motion.log.debug "Set locate_motion_mode to ${VALUE}"

# set locate_motion_style (box, redbox, cross, redcross)
VALUE=$(jq -r ".locate_motion_style" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="box"; fi
sed -i "s/.*locate_motion_style.*/locate_motion_style ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_style":"'"${VALUE}"'"'
motion.log.debug "Set locate_motion_style to ${VALUE}"

# set picture_output (on, off, first, best, center)
VALUE=$(jq -r ".picture_output" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*picture_output.*/picture_output ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_output":"'"${VALUE}"'"'
motion.log.debug "Set picture_output to ${VALUE}"

# set picture_type (jpeg, ppm)
VALUE=$(jq -r ".picture_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="jpeg"; fi
sed -i "s/.*picture_type .*/picture_type ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_type":"'"${VALUE}"'"'
motion.log.debug "Set picture_type to ${VALUE}"

# set threshold_tune (jpeg, ppm)
VALUE=$(jq -r ".threshold_tune" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*threshold_tune .*/threshold_tune ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold_tune":"'"${VALUE}"'"'
motion.log.debug "Set threshold_tune to ${VALUE}"

# set netcam_keepalive (off,force,on)
VALUE=$(jq -r ".netcam_keepalive" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*netcam_keepalive .*/netcam_keepalive ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"netcam_keepalive":"'"${VALUE}"'"'
motion.log.debug "Set netcam_keepalive to ${VALUE}"

## numeric values

# set v4l2_pallette
VALUE=$(jq -r ".v4l2_pallette" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then
  sed -i "s/.*v4l2_pallette\s[0-9]\+/v4l2_pallette ${VALUE}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"v4l2_pallette":'"${VALUE}"
  motion.log.debug "Set v4l2_pallette to ${VALUE}"
fi

# set pre_capture
VALUE=$(jq -r ".pre_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/.*pre_capture\s[0-9]\+/pre_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"pre_capture":'"${VALUE}"
motion.log.debug "Set pre_capture to ${VALUE}"

# set post_capture
VALUE=$(jq -r ".post_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/.*post_capture\s[0-9]\+/post_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"post_capture":'"${VALUE}"
motion.log.debug "Set post_capture to ${VALUE}"

# set event_gap
VALUE=$(jq -r ".event_gap" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=10; fi
sed -i "s/.*event_gap\s[0-9]\+/event_gap ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"event_gap":'"${VALUE}"
motion.log.debug "Set event_gap to ${VALUE}"

# set minimum_motion_frames
VALUE=$(jq -r ".minimum_motion_frames" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=10; fi
sed -i "s/.*minimum_motion_frames\s[0-9]\+/minimum_motion_frames ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_motion_frames":'"${VALUE}"
motion.log.debug "Set minimum_motion_frames to ${VALUE}"

# set quality
VALUE=$(jq -r ".picture_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=100; fi
sed -i "s/.*picture_quality\s[0-9]\+/picture_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_quality":'"${VALUE}"
motion.log.debug "Set picture_quality to ${VALUE}"

# set width
VALUE=$(jq -r ".width" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=640; fi
sed -i "s/.*width\s[0-9]\+/width ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"width":'"${VALUE}"
motion.log.debug "Set width to ${VALUE}"

# set height
VALUE=$(jq -r ".height" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=480; fi
sed -i "s/.*height\s[0-9]\+/height ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"height":'"${VALUE}"
motion.log.debug "Set height to ${VALUE}"

# set framerate
VALUE=$(jq -r ".framerate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=5; fi
sed -i "s/.*framerate\s[0-9]\+/framerate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"framerate":'"${VALUE}"
motion.log.debug "Set framerate to ${VALUE}"

# set minimum_frame_time
VALUE=$(jq -r ".minimum_frame_time" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/.*minimum_frame_time\s[0-9]\+/minimum_frame_time ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_frame_time":'"${VALUE}"
motion.log.debug "Set minimum_frame_time to ${VALUE}"

## vid_control_params

## ps3eye 
# ---------Controls---------
#   V4L2 ID   Name and Range
# ID09963776 Brightness, 0 to 255
# ID09963777 Contrast, 0 to 255
# ID09963778 Saturation, 0 to 255
# ID09963779 Hue, -90 to 90
# ID09963788 White Balance, Automatic, 0 to 1
# ID09963793 Exposure, 0 to 255
# ID09963794 Gain, Automatic, 0 to 1
# ID09963795 Gain, 0 to 63
# ID09963796 Horizontal Flip, 0 to 1
# ID09963797 Vertical Flip, 0 to 1
# ID09963800 Power Line Frequency, 0 to 1
#   menu item: Value 0 Disabled
#   menu item: Value 1 50 Hz
# ID09963803 Sharpness, 0 to 63
# ID10094849 Auto Exposure, 0 to 1
#   menu item: Value 0 Auto Mode
#   menu item: Value 1 Manual Mode
# --------------------------

# set brightness
VALUE=$(jq -r ".brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/brightness=[0-9]\+/brightness=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"brightness":'"${VALUE}"
motion.log.debug "Set brightness to ${VALUE}"

# set contrast
VALUE=$(jq -r ".contrast" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/contrast=[0-9]\+/contrast=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"contrast":'"${VALUE}"
motion.log.debug "Set contrast to ${VALUE}"

# set saturation
VALUE=$(jq -r ".saturation" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/saturation=[0-9]\+/saturation=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"saturation":'"${VALUE}"
motion.log.debug "Set saturation to ${VALUE}"

# set hue
VALUE=$(jq -r ".hue" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/hue=[0-9]\+/hue=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"hue":'"${VALUE}"
motion.log.debug "Set hue to ${VALUE}"

## other

# set rotate
VALUE=$(jq -r ".rotate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
motion.log.debug "Set rotate to ${VALUE}"
sed -i "s/.*rotate\s[0-9]\+/rotate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"rotate":'"${VALUE}"

# set webcontrol_port
VALUE=$(jq -r ".webcontrol_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
motion.log.debug "Set webcontrol_port to ${VALUE}"
sed -i "s/.*webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"webcontrol_port":'"${VALUE}"

# set stream_port
VALUE=$(jq -r ".stream_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; fi
motion.log.debug "Set stream_port to ${VALUE}"
sed -i "s/.*stream_port\s[0-9]\+/stream_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_port":'"${VALUE}"

# set stream_quality
VALUE=$(jq -r ".stream_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=100; fi
motion.log.debug "Set stream_quality to ${VALUE}"
sed -i "s/.*stream_quality\s[0-9]\+/stream_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_quality":'"${VALUE}"

# set threshold
VALUE=$(jq -r ".threshold" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1500; fi
motion.log.debug "Set threshold to ${VALUE}"
sed -i "s/.*threshold.*/threshold ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold":'"${VALUE}"

# set lightswitch
VALUE=$(jq -r ".lightswitch" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
motion.log.debug "Set lightswitch to ${VALUE}"
sed -i "s/.*lightswitch.*/lightswitch ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"lightswitch":'"${VALUE}"

## process collectively

# set username and password
USERNAME=$(jq -r ".default.username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".default.password" "${CONFIG_PATH}")
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

# base target_dir
VALUE=$(jq -r ".target_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_APACHE_HTDOCS}/cameras"; fi
motion.log.debug "Set target_dir to ${VALUE}"
sed -i "s|.*target_dir.*|target_dir ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"target_dir":"'"${VALUE}"'"'
MOTION_TARGET_DIR="${VALUE}"

## end motion structure; cameras section depends on well-formed JSON for $MOTION
MOTION="${MOTION}"'}'

motion.log.debug "${MOTION}"

## append to configuration JSON
JSON="${JSON}"',"motion":'"${MOTION}"

###
### process cameras 
###

ncamera=$(jq '.cameras|length' "${CONFIG_PATH}")
motion.log.notice "*** Found ${ncamera} cameras"

MOTION_COUNT=0

for (( CNUM=0, i=0; i < ncamera; i++)) ; do
  motion.log.debug "+++ CAMERA ${i}"

  ## TOP-LEVEL
  if [ -z "${CAMERAS:-}" ]; then CAMERAS='['; else CAMERAS="${CAMERAS}"','; fi
  motion.log.debug "CAMERA #: $i"
  CAMERAS="${CAMERAS}"'{"id":'${i}

  # process camera type; wcv80n, ps3eye, panasonic
  VALUE=$(jq -r '.cameras['${i}'].type' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    VALUE=$(jq -r '.camera_type' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="wcv80n"; fi
  fi
  motion.log.debug "Set type to ${VALUE}"
  CAMERAS="${CAMERAS}"',"type":"'"${VALUE}"'"'

  # name
  VALUE=$(jq -r '.cameras['${i}'].name' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="camera-name${i}"; fi
  motion.log.debug "Set name to ${VALUE}"
  CAMERAS="${CAMERAS}"',"name":"'"${VALUE}"'"'
  CNAME=${VALUE}

  # process models string to array of strings
  VALUE=$(jq -r '.cameras['${i}'].models' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    W=$(echo "${WATSON:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"wvr:\1"\2/g' | fmt -1000)
    # motion.log.debug "WATSON: ${WATSON} ${W}"
    D=$(echo "${DIGITS:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"digits:\1"\2/g' | fmt -1000)
    # motion.log.debug "DIGITS: ${DIGITS} ${D}"
    VALUE=$(echo ${W} ${D})
    VALUE=$(echo "${VALUE}" | sed "s/ /,/g")
  else
    VALUE=$(echo "${VALUE}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
  fi
  motion.log.debug "Set models to ${VALUE}"
  CAMERAS="${CAMERAS}"',"models":['"${VALUE}"']'

  # process camera fov; WCV80n is 61.5 (62); 56 or 75 degrees for PS3 Eye camera
  VALUE=$(jq -r '.cameras['${i}'].fov' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.fov' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=62; fi
  fi
  motion.log.debug "Set fov to ${VALUE}"
  CAMERAS="${CAMERAS}"',"fov":'"${VALUE}"

  # target_dir 
  VALUE=$(jq -r '.cameras['${i}'].target_dir' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_TARGET_DIR}/${CNAME}"; fi
  motion.log.debug "Set target_dir to ${VALUE}"
  if [ ! -d "${VALUE}" ]; then mkdir -p "${VALUE}"; fi
  CAMERAS="${CAMERAS}"',"target_dir":"'"${VALUE}"'"'
  TARGET_DIR="${VALUE}"

  # width 
  VALUE=$(jq -r '.cameras['${i}'].width' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.width'); fi
  CAMERAS="${CAMERAS}"',"width":'"${VALUE}"
  motion.log.debug "Set width to ${VALUE}"
  WIDTH=${VALUE}

  # height 
  VALUE=$(jq -r '.cameras['${i}'].height' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.height'); fi
  CAMERAS="${CAMERAS}"',"height":'"${VALUE}"
  motion.log.debug "Set height to ${VALUE}"
  HEIGHT=${VALUE}

  # process camera fps; set on wcv80n web GUI; default 6
  VALUE=$(jq -r '.cameras['${i}'].fps' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.framerate' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=5; fi
  fi
  motion.log.debug "Set fps to ${VALUE}"
  CAMERAS="${CAMERAS}"',"fps":'"${VALUE}"
  FRAMERATE=${VALUE}

  # FTPD type
  VALUE=$(jq -r '.cameras['${i}'].url' "${CONFIG_PATH}")
  if [[ "${VALUE}" == ftpd* ]]; then
    VALUE="${VALUE%*/}.jpg"
    CAMERAS="${CAMERAS}"',"url":"'"${VALUE}"'"'
    motion.log.debug "FTPD source; Set url to ${VALUE}; not configurig as motion camera"
    # close CAMERAS structure
    CAMERAS="${CAMERAS}"'}'
    # next camera
    continue
  fi

  ## handle more than one motion process (10 camera/process)
  if (( CNUM / 10 )); then
    if (( CNUM % 10 == 0 )); then
      MOTION_COUNT=$((MOTION_COUNT + 1))
      CNUM=1
      CONF="${MOTION_CONF%%.*}.${MOTION_COUNT}.${MOTION_CONF##*.}"
      cp "${MOTION_CONF}" "${CONF}"
      sed -i 's|^camera|; camera|' "${CONF}"
      MOTION_CONF=${CONF}
      # get webcontrol_port (base)
      VALUE=$(jq -r ".webcontrol_port" "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
      VALUE=$((VALUE + MOTION_COUNT))
      motion.log.debug "Set webcontrol_port to ${VALUE}"
      sed -i "s/.*webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
    else
      CNUM=$((CNUM+1))
    fi
  else
    CNUM=$((CNUM+1))
  fi
  # create configuration file
  if [ ${MOTION_CONF%/*} != ${MOTION_CONF} ]; then 
    CAMERA_CONF="${MOTION_CONF%/*}/${CNAME}.conf"
  else
    CAMERA_CONF="${CNAME}.conf"
  fi

  # document camera number
  CAMERAS="${CAMERAS}"',"cnum":'"${CNUM}"
  CAMERAS="${CAMERAS}"',"conf":"'"${CAMERA_CONF}"'"'

  # basics
  echo "camera_id ${CNUM}" > "${CAMERA_CONF}"
  echo "camera_name ${CNAME}" >> "${CAMERA_CONF}"
  echo "target_dir ${TARGET_DIR}" >> "${CAMERA_CONF}"
  echo "width ${WIDTH}" >> "${CAMERA_CONF}"
  echo "height ${HEIGHT}" >> "${CAMERA_CONF}"
  echo "framerate ${FRAMERATE}" >> "${CAMERA_CONF}"

  # local device
  if [ ! -z "${VALUE:-}" ] && [ "${VALUE:-}" != 'null' ]; then
    # network camera
    CAMERAS="${CAMERAS}"',"url":"'"${VALUE}"'"'
    echo "netcam_url ${VALUE}" >> "${CAMERA_CONF}"
    motion.log.debug "Set netcam_url to ${VALUE}"
    # userpass 
    VALUE=$(jq -r '.cameras['${i}'].userpass' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=; fi
    echo "netcam_userpass ${VALUE}" >> "${CAMERA_CONF}"
    CAMERAS="${CAMERAS}"',"userpass":"'"${VALUE}"'"'
    motion.log.debug "Set netcam_userpass to ${VALUE}"
    # keepalive 
    VALUE=$(jq -r '.cameras['${i}'].keepalive' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_keepalive'); fi
    echo "netcam_keepalive ${VALUE}" >> "${CAMERA_CONF}"
    CAMERAS="${CAMERAS}"',"keepalive":"'"${VALUE}"'"'
    motion.log.debug "Set netcam_keepalive to ${VALUE}"
  else 
    VALUE=$(jq -r '.cameras['${i}'].device' "${CONFIG_PATH}")
    if [[ "${VALUE}" != /dev/video* ]]; then
      motion.log.fatal "Camera: ${i}; name: ${CNAME}; invalid videodevice ${VALUE}; exiting"
      exit 1
    fi
    echo "videodevice ${VALUE}" >> "${CAMERA_CONF}"
    motion.log.debug "Set videodevice to ${VALUE}"
  fi

  # stream_port (calculated)
  VALUE=$(jq -r '.cameras['${i}'].port' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; VALUE=$((VALUE + i)); fi
  motion.log.debug "Set stream_port to ${VALUE}"
  echo "stream_port ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"port":"'"${VALUE}"'"'

  # palette
  VALUE=$(jq -r '.cameras['${i}'].palette' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_DEFAULT_PALETTE}; fi
  CAMERAS="${CAMERAS}"',"palette":'"${VALUE}"
  echo "v4l2_palette ${VALUE}" >> "${CAMERA_CONF}"
  motion.log.debug "Set palette to ${VALUE}"

  # picture_quality 
  VALUE=$(jq -r '.cameras['${i}'].picture_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.picture_quality'); fi
  echo "picture_quality ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"picture_quality":'"${VALUE}"
  motion.log.debug "Set picture_quality to ${VALUE}"

  # stream_quality 
  VALUE=$(jq -r '.cameras['${i}'].stream_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_quality'); fi
  echo "stream_quality ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"stream_quality":'"${VALUE}"
  motion.log.debug "Set stream_quality to ${VALUE}"

  # threshold 
  VALUE=$(jq -r '.cameras['${i}'].threshold' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.threshold'); fi
  echo "threshold ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"threshold":'"${VALUE}"
  motion.log.debug "Set threshold to ${VALUE}"

  # rotate 
  VALUE=$(jq -r '.cameras['${i}'].rotate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.rotate'); fi
  motion.log.debug "Set rotate to ${VALUE}"
  echo "rotate ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"rotate":'"${VALUE}"

  # close CAMERAS structure
  CAMERAS="${CAMERAS}"'}'

  # add new camera configuration
  echo "camera ${CAMERA_CONF}" >> "${MOTION_CONF}"
done

## DONE w/ MOTION_CONF

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

# set post_pictures; enumerated [on,center,first,last,best,most]
VALUE=$(jq -r '.post_pictures' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="center"; fi
motion.log.debug "Set post_pictures to ${VALUE}"
JSON="${JSON}"',"post_pictures":"'"${VALUE}"'"'
export MOTION_POST_PICTURES="${VALUE}"

# shared directory for results (not images and JSON)
VALUE=$(jq -r ".share_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/share/${MOTION_GROUP}"; fi
motion.log.debug "Set share_dir to ${VALUE}"
JSON="${JSON}"',"share_dir":"'"${VALUE}"'"'

# DONE w/ JSON
JSON="${JSON}"'}'

## INSPECT FOR QUALITY

echo "${JSON}" | jq '.' > "$(motion.config.file)"
if [ ! -s "$(motion.config.file)" ]; then
  motion.log.error "Invalid motion JSON: ${JSON}"
  exit 1
else
  motion.log.debug "Valid configuration file $(motion.config.file): $(jq -c '.' $(motion.config.file))"
fi

## publish
motion.mqtt.pub -r -q 2 -t "$(motion.config.group)/$(motion.config.group)/start" -f "$(motion.config.file)"
motion.log.notice "Published $(motion.config.file) to $(motion.config.group)/$(motion.config.device)/start"

###
### FTPD
###

motion.log.notice "Settting up notifywait for FTPD cameras"
ftp_notifywait.sh "$(motion.config.file)"

###
### MOTION
###

# check for motion
MOTION_CMD=$(command -v motion)
if [ ! -s "${MOTION_CMD}" ] || [ ! -s "${MOTION_CONF}" ]; then
  motion.log.fatal "No motion installed ${MOTION_CMD} or motion configuration ${MOTION_CONF} does not exist"
  exit 1
fi

# get first configuration
CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"

# process all motion configurations
motion.log.debug "Starting ${MOTION_COUNT} motion daemons"
for (( i = 1; i <= MOTION_COUNT;  i++)); do
    if [ ! -s "${CONF}" ]; then
       motion.log.fatal "missing configuration for daemon ${i} with ${CONF}"
       exit 1
    fi
    motion.log.debug "Starting motion configuration ${i}: ${CONF}"
    motion -b -c "${CONF}"
    # get next configuration
    CONF="${MOTION_CONF%%.*}.${i}.${MOTION_CONF##*.}"
done

###
### APACHE
###

if [ ! -s "${MOTION_APACHE_CONF}" ]; then
  motion.log.fatal "Missing Apache configuration: ${MOTION_APACHE_CONF}"
  exit 1
fi

# edit defaults
sed -i 's|^Listen \(.*\)|Listen '${MOTION_APACHE_PORT}'|' "${MOTION_APACHE_CONF}"
sed -i 's|^ServerName \(.*\)|ServerName '"${MOTION_APACHE_HOST}:${MOTION_APACHE_PORT}"'|' "${MOTION_APACHE_CONF}"
sed -i 's|^ServerAdmin \(.*\)|ServerAdmin '"${MOTION_APACHE_ADMIN}"'|' "${MOTION_APACHE_CONF}"
# sed -i 's|^ServerTokens \(.*\)|ServerTokens '"${MOTION_APACHE_TOKENS}"'|' "${MOTION_APACHE_CONF}"
# sed -i 's|^ServerSignature \(.*\)|ServerSignature '"${MOTION_APACHE_SIGNATURE}"'|' "${MOTION_APACHE_CONF}"

# enable CGI
sed -i 's|^\([^#]\)#LoadModule cgi|\1LoadModule cgi|' "${MOTION_APACHE_CONF}"

# export environment
export MOTION_JSON_FILE=$(motion.config.file)
export MOTION_SHARE_DIR=$(motion.config.share_dir)

# pass environment
echo 'PassEnv MOTION_JSON_FILE' >> "${MOTION_APACHE_CONF}"
echo 'PassEnv MOTION_SHARE_DIR' >> "${MOTION_APACHE_CONF}"

# test CLOUDANT
if [ ! -z "${MOTION_CLOUDANT_URL:-}" ]; then
  echo 'PassEnv MOTION_CLOUDANT_URL' >> "${MOTION_APACHE_CONF}"
fi

# test WATSON
if [ ! -z "${MOTION_WATSON_APIKEY:-}" ]; then
  echo 'PassEnv MOTION_WATSON_APIKEY' >> "${MOTION_APACHE_CONF}"
fi

# make /run/apache2 for PID file
mkdir -p /run/apache2

# start HTTP daemon in foreground
motion.log.debug "Starting Apache: ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT} ${MOTION_APACHE_HTDOCS}"
MOTION_JSON_FILE=$(motion.config.file) httpd -E /tmp/motion.log -e debug -f "${MOTION_APACHE_CONF}" -DFOREGROUND

