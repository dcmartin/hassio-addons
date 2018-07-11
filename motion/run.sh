#!/bin/bash

if [ ! -s "${CONFIG_PATH}" ]; then
  echo "Cannot find options ${CONFIG_PATH}; exiting" >&2
  ls -al /data >&2
  exit
fi

###
### START JSON
###
JSON='{'

##
## host name
##
VALUE=$(jq -r ".name" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="${HOSTNAME}"; fi
echo "Setting name ${VALUE} [MOTION_DEVICE_NAME]" >&2
# FIRST ITEM NO COMMA
JSON="${JSON}"'"name":"'"${VALUE}"'","date":'$(/bin/date +%s)
export MOTION_DEVICE_NAME="${VALUE}"

##
## time zone
##
TIMEZONE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ ! -z "${TIMEZONE}" ] && [ "${TIMEZONE}" != "null" ]; then
  echo "Setting TIMEZONE ${TIMEZONE}" >&2
  cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
  JSON="${JSON}"',"timezone":"'"${TIMEZONE}"'"'
else
  echo "Time zone not set; exiting" >&2
  exit
fi

## MQTT
# local MQTT server (hassio addon)
VALUE=$(jq -r ".mqtt_host" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then
  echo "Using MQTT at ${VALUE}" >&2
  MQTT='{"host":"'"${VALUE}"'"'
  export MOTION_MQTT_HOST="${VALUE}"
fi

if [ -n "${MQTT}" ]; then
  VALUE=$(jq -r ".mqtt_port" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
  echo "Using MQTT port: ${VALUE}" >&2
  MQTT="${MQTT}"',"port":'"${VALUE}"'}'
  export MOTION_MQTT_PORT="${VALUE}"
else
  echo "MQTT undefined; continuing" >&2
fi

if [ -n "${MQTT}" ]; then
  JSON="${JSON}"',"mqtt":'"${MQTT}"
else
  JSON="${JSON}"',"mqtt":null'
fi

# local MQTT server (hassio addon)
MQTT_HOST=$(jq -r ".mqtt_host" "${CONFIG_PATH}")
MQTT_PORT=$(jq -r ".mqtt_port" "${CONFIG_PATH}")
if [ "${MQTT_PORT}" != "null" ] && [ "${MQTT_HOST}" != "null" ] && [ ! -z "${MQTT_HOST}" ]; then
  echo "Using MQTT at ${MQTT_HOST}" >&2
  JSON="${JSON}"',"mqtt":{"host":"'"${MQTT_HOST}"'","port":'"${MQTT_PORT}"'}'
else
  JSON="${JSON}"',"mqtt":null'
  echo "MQTT host or port undefined" >&2
fi

## WATSON
# watson visual recognition
WVR_URL=$(jq -r ".wvr_url" "${CONFIG_PATH}")
WVR_APIKEY=$(jq -r ".wvr_apikey" "${CONFIG_PATH}")
WVR_CLASSIFIER=$(jq -r ".wvr_classifier" "${CONFIG_PATH}")
WVR_DATE=$(jq -r ".wvr_date" "${CONFIG_PATH}")
WVR_VERSION=$(jq -r ".wvr_version" "${CONFIG_PATH}")
if [ ! -z "${WVR_URL}" ] && [ ! -z "${WVR_APIKEY}" ] && [ ! -z "${WVR_DATE}" ] && [ ! -z "${WVR_VERSION}" ] && [ "${WVR_URL}" != "null" ] && [ "${WVR_APIKEY}" != "null" ] && [ "${WVR_DATE}" != "null" ] && [ "${WVR_VERSION}" != "null" ]; then
  echo "Watson Visual Recognition at ${WVR_URL} date ${WVR_DATE} version ${WVR_VERSION}" >&2
  WATSON='{"url":"'"${WVR_URL}"'","release":"'"${WVR_DATE}"'","version":"'"${WVR_VERSION}"'","models":['
  if [ ! -z "${WVR_CLASSIFIER}" ] && [ "${WVR_CLASSIFIER}" != "null" ]; then
    # quote the model names
    CLASSIFIERS=$(echo "${WVR_CLASSIFIER}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
    echo "Using classifiers(s): ${CLASSIFIERS}" >&2
    WATSON="${WATSON}""${CLASSIFIERS}"
  else
    # add default iif none specified
    WATSON="${WATSON}"'"default"'
  fi
  WATSON="${WATSON}"']}'
fi
if [ -n "${WATSON}" ]; then
  JSON="${JSON}"',"watson":'"${WATSON}"
else
  echo "Watson Visual Recognition NOT CONFIGURED" >&2
  JSON="${JSON}"',"watson":null'
fi

## DIGITS
# local nVidia DIGITS/Caffe image classification server
VALUE=$(jq -r ".digits_server_url" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then
  DIGITS='{"host":"'"${VALUE}"'"'
  if [ -z "${DIGITS_SERVER_URL}" ]; then DIGITS_SERVER_URL="${VALUE}"; fi
  VALUE=$(jq -r ".digits_jobid" "${CONFIG_PATH}")
  if [ ! -z "${VALUE}" ] && [ "${VALUE}" != "null" ]; then
    DIGITS_JOBIDS=$(echo "${VALUE}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
    echo "Using DIGITS at ${DIGITS_SERVER_URL} and ${DIGITS_JOBIDS}" >&2
    DIGITS="${DIGITS}"',"models":['"${DIGITS_JOBIDS}"']'
  fi
  DIGITS="${DIGITS}"'}'
fi
if [ -n "${DIGITS}" ]; then
  JSON="${JSON}"',"digits":'"${DIGITS}"
else
  echo "DIGITS server URL not specified" >&2
  JSON="${JSON}"',"digits":null'
fi

###
### MOTION
###

echo "+++ MOTION" >&2

MOTION='{'

## alphanumeric values

# set videodevice
VALUE=$(jq -r ".videodevice" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/dev/video0"; fi
echo "Set videodevice to ${VALUE}" >&2
sed -i "s|.*videodevice .*|videodevice ${VALUE}|" "${MOTION_CONF}"
# FIRST ITEM NO COMMA
MOTION="${MOTION}"'"videodevice":"'"${VALUE}"'"'

# set log_type
VALUE=$(jq -r ".log_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="all"; fi
echo "Set log_type to ${VALUE}" >&2
sed -i "s|.*log_type .*|log_type ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_type":"'"${VALUE}"'"'

# set auto_brightness
VALUE=$(jq -r ".auto_brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
echo "Set auto_brightness to ${VALUE}" >&2
sed -i "s/.*auto_brightness .*/auto_brightness ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"auto_brightness":"'"${VALUE}"'"'

# set locate_motion_mode
VALUE=$(jq -r ".locate_motion_mode" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
echo "Set locate_motion_mode to ${VALUE}" >&2
sed -i "s/.*locate_motion_mode .*/locate_motion_mode ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_mode":"'"${VALUE}"'"'

# set locate_motion_style (box, redbox, cross, redcross)
VALUE=$(jq -r ".locate_motion_style" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="box"; fi
echo "Set locate_motion_style to ${VALUE}" >&2
sed -i "s/.*locate_motion_style .*/locate_motion_style ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_style":"'"${VALUE}"'"'

# set output_pictures (on, off, first, best, center)
VALUE=$(jq -r ".output_pictures" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
echo "Set output_pictures to ${VALUE}" >&2
sed -i "s/.*output_pictures .*/output_pictures ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"output_pictures":"'"${VALUE}"'"'

# set picture_type (jpeg, ppm)
VALUE=$(jq -r ".picture_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="jpeg"; fi
echo "Set picture_type to ${VALUE}" >&2
sed -i "s/.*picture_type .*/picture_type ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_type":"'"${VALUE}"'"'

# set threshold_tune (jpeg, ppm)
VALUE=$(jq -r ".threshold_tune" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
echo "Set threshold_tune to ${VALUE}" >&2
sed -i "s/.*threshold_tune .*/threshold_tune ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold_tune":"'"${VALUE}"'"'

# set netcam_keepalive (off,force,on)
VALUE=$(jq -r ".netcam_keepalive" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
echo "Set netcam_keepalive to ${VALUE}" >&2
sed -i "s/.*netcam_keepalive .*/netcam_keepalive ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"netcam_keepalive":"'"${VALUE}"'"'

## numeric values

# set log_level
VALUE=$(jq -r ".log_level" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=6; fi
echo "Set log_level to ${VALUE}" >&2
sed -i "s/.*log_level\s[0-9]\+/log_level ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_level":'"${VALUE}"

# set v412_pallette
VALUE=$(jq -r ".v412_pallette" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=17; fi
echo "Set v412_pallette to ${VALUE}" >&2
sed -i "s/.*v412_pallette\s[0-9]\+/v412_pallette ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"v412_pallette":'"${VALUE}"

# set pre_capture
VALUE=$(jq -r ".pre_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
echo "Set pre_capture to ${VALUE}" >&2
sed -i "s/.*pre_capture\s[0-9]\+/pre_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"pre_capture":'"${VALUE}"

# set post_capture
VALUE=$(jq -r ".post_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
echo "Set post_capture to ${VALUE}" >&2
sed -i "s/.*post_capture\s[0-9]\+/post_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"post_capture":'"${VALUE}"

# set event_gap
VALUE=$(jq -r ".event_gap" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=10; fi
echo "Set event_gap to ${VALUE}" >&2
sed -i "s/.*event_gap\s[0-9]\+/event_gap ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"event_gap":'"${VALUE}"

# set minimum_motion_frames
VALUE=$(jq -r ".minimum_motion_frames" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1; fi
echo "Set minimum_motion_frames to ${VALUE}" >&2
sed -i "s/.*minimum_motion_frames\s[0-9]\+/minimum_motion_frames ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_motion_frames":'"${VALUE}"

# set quality
VALUE=$(jq -r ".quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=75; fi
echo "Set quality to ${VALUE}" >&2
sed -i "s/.*quality\s[0-9]\+/quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"quality":'"${VALUE}"

# set width
VALUE=$(jq -r ".width" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=640; fi
echo "Set width to ${VALUE}" >&2
sed -i "s/.*width\s[0-9]\+/width ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"width":'"${VALUE}"

# set height
VALUE=$(jq -r ".height" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=480; fi
echo "Set height to ${VALUE}" >&2
sed -i "s/.*height\s[0-9]\+/height ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"height":'"${VALUE}"

# set framerate
VALUE=$(jq -r ".framerate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=100; fi
echo "Set framerate to ${VALUE}" >&2
sed -i "s/.*framerate\s[0-9]\+/framerate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"framerate":'"${VALUE}"

# set minimum_frame_time
VALUE=$(jq -r ".minimum_frame_time" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
echo "Set minimum_frame_time to ${VALUE}" >&2
sed -i "s/.*minimum_frame_time\s[0-9]\+/minimum_frame_time ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_frame_time":'"${VALUE}"

# set brightness
VALUE=$(jq -r ".brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
echo "Set brightness to ${VALUE}" >&2
sed -i "s/.*brightness\s[0-9]\+/brightness ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"brightness":'"${VALUE}"

# set contrast
VALUE=$(jq -r ".contrast" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
echo "Set contrast to ${VALUE}" >&2
sed -i "s/.*contrast\s[0-9]\+/contrast ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"contrast":'"${VALUE}"

# set saturation
VALUE=$(jq -r ".saturation" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
echo "Set saturation to ${VALUE}" >&2
sed -i "s/.*saturation\s[0-9]\+/saturation ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"saturation":'"${VALUE}"

# set hue
VALUE=$(jq -r ".hue" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
echo "Set hue to ${VALUE}" >&2
sed -i "s/.*hue\s[0-9]\+/hue ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"hue":'"${VALUE}"

# set rotate
VALUE=$(jq -r ".rotate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
echo "Set rotate to ${VALUE}" >&2
sed -i "s/.*rotate\s[0-9]\+/rotate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"rotate":'"${VALUE}"

# set webcontrol_port
VALUE=$(jq -r ".webcontrol_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=8080; fi
echo "Set webcontrol_port to ${VALUE}" >&2
sed -i "s/.*webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"webcontrol_port":'"${VALUE}"

# set stream_port
VALUE=$(jq -r ".stream_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=8081; fi
echo "Set stream_port to ${VALUE}" >&2
sed -i "s/.*stream_port\s[0-9]\+/stream_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_port":'"${VALUE}"
if [ -z ${MOTION_STREAM_PORT} ]; then MOTION_STREAM_PORT=${VALUE}; fi

# set stream_quality
VALUE=$(jq -r ".stream_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=50; fi
echo "Set stream_quality to ${VALUE}" >&2
sed -i "s/.*stream_quality\s[0-9]\+/stream_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_quality":'"${VALUE}"

# set threshold
VALUE=$(jq -r ".threshold" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1500; fi
echo "Set threshold to ${VALUE}" >&2
sed -i "s/.*threshold .*/threshold ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold":'"${VALUE}"

# set lightswitch
VALUE=$(jq -r ".lightswitch" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
echo "Set lightswitch to ${VALUE}" >&2
sed -i "s/.*lightswitch\s[0-9]\+/lightswitch ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"lightswitch":'"${VALUE}"

## process collectively

# set username and password
USERNAME=$(jq -r ".username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".password" "${CONFIG_PATH}")
if [ "${USERNAME}" != "null" ] && [ "${PASSWORD}" != "null" ] && [ ! -z "${USERNAME}" ] && [ ! -z "${PASSWORD}" ]; then
  echo "Set authentication to Basic for both stream and webcontrol" >&2
  sed -i "s/.*stream_auth_method.*/stream_auth_method 1/" "${MOTION_CONF}"
  sed -i "s/.*stream_authentication.*/stream_authentication ${USERNAME}:${PASSWORD}/" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_authentication.*/webcontrol_authentication ${USERNAME}:${PASSWORD}/" "${MOTION_CONF}"
  echo "Enable access for any host" >&2
  sed -i "s/.*stream_localhost .*/stream_localhost off/" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_localhost .*/webcontrol_localhost off/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"stream_auth_method":"Basic"'
else
  echo "WARNING: no username and password; stream and webcontrol limited to localhost only" >&2
  sed -i "s/.*stream_localhost .*/stream_localhost on/" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_localhost .*/webcontrol_localhost on/" "${MOTION_CONF}"
fi

# set netcam_url to be shared across all cameras
VALUE=$(jq -r ".netcam_url" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then
  echo "Set netcam_url to ${VALUE}" >&2
  sed -i "s|.*netcam_url .*|netcam_url ${VALUE}|" "${MOTION_CONF}"
  MOTION="${MOTION}"',"netcam_url":"'"${VALUE}"'"'
fi

# set netcam_userpass across all cameras
VALUE=$(jq -r ".netcam_userpass" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then
  echo "Set netcam_userpass to ${VALUE}" >&2
  sed -i "s/.*netcam_userpass .*/netcam_userpass ${VALUE}/" "${MOTION_CONF}"
  # DO NOT RECORD; MOTION="${MOTION}"',"netcam_userpass":"'"${VALUE}"'"'
  NETCAM_USERPASS="${VALUE}"
fi

# MOTION_TARGET_DIR defined for all cameras base path
VALUE=$(jq -r ".target_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/share/motion"; fi
if [ ! -z ${MOTION_TARGET_DIR} ]; then echo "*** MOTION_TARGET_DIR *** ${MOTION_TARGET_DIR}"; VALUE="${MOTION_TARGET_DIR}"; else export MOTION_TARGET_DIR="${VALUE}"; fi
echo "Set target_dir to ${VALUE}" >&2
sed -i "s|.*target_dir.*|target_dir ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"target_dir":"'"${VALUE}"'"'

## end motion structure; cameras section depends on well-formed JSON for $MOTION
MOTION="${MOTION}"'}'

## append to configuration JSON
JSON="${JSON}"',"motion":'"${MOTION}"

###
### process cameras 
###

ncamera=$(jq '.cameras|length' "${CONFIG_PATH}")
echo "Found ${ncamera} cameras" >&2
for (( i=0; i<ncamera ; i++)) ; do

  if [ -z "${CAMERAS}" ]; then CAMERAS='['; else CAMERAS="${CAMERAS}"','; fi

  echo "+++ CAMERA $i" >&2

  CAMERAS="${CAMERAS}"'{"id":'${i}

  # name
  VALUE=$(jq -r '.cameras['$i'].name' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="camera-name${i}"; fi
  echo "Set name to ${VALUE}" >&2
  CAMERAS="${CAMERAS}"',"name":"'"${VALUE}"'"'

  # SPECIAL CASE FOR NAME
  CNAME=${VALUE}
  if [ ${MOTION_CONF%/*} != ${MOTION_CONF} ]; then 
    CAMERA_CONF="${MOTION_CONF%/*}/${CNAME}.conf"
  else
    CAMERA_CONF="${CNAME}.conf"
  fi
  echo "camera_id ${i}" > "${CAMERA_CONF}"
  echo "camera_name ${VALUE}" >> "${CAMERA_CONF}"

  # process camera type; only wcv80n
  VALUE=$(jq -r '.cameras['$i'].type' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="wcv80n"; fi
  echo "Set type to ${VALUE}" >&2
  CAMERAS="${CAMERAS}"',"type":"'"${VALUE}"'"'
  # process camera fov; WCV80n is 61.5 (62); 56 or 75 degrees for PS3 Eye camera
  VALUE=$(jq -r '.cameras['$i'].fov' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=62; fi
  echo "Set fov to ${VALUE}" >&2
  CAMERAS="${CAMERAS}"',"fov":'"${VALUE}"
  # process camera fps; set on wcv80n web GUI; default 6
  VALUE=$(jq -r '.cameras['$i'].fps' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=6; fi
  echo "Set fps to ${VALUE}" >&2
  CAMERAS="${CAMERAS}"',"fps":'"${VALUE}"

  # target_dir 
  VALUE=$(jq -r '.cameras['$i'].target_dir' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.target_dir'); VALUE="${VALUE}/${CNAME}"; fi
  echo "Set target_dir to ${VALUE}" >&2
  echo "target_dir ${VALUE}" >> "${CAMERA_CONF}"
  if [ ! -d "${VALUE}" ]; then mkdir -p "${VALUE}"; fi
  CAMERAS="${CAMERAS}"',"target_dir":"'"${VALUE}"'"'

  # url
  VALUE=$(jq -r '.cameras['$i'].url' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_url'); fi
  echo "Set url to ${VALUE}" >&2
  echo "netcam_url ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"url":"'"${VALUE}"'"'

  # stream_port 
  VALUE=$(jq -r '.cameras['$i'].port' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_port'); VALUE=$((VALUE + i)); fi
  echo "Set stream_port to ${VALUE}" >&2
  echo "stream_port ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"port":"'"${VALUE}"'"'

  # keepalive 
  VALUE=$(jq -r '.cameras['$i'].keepalive' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_keepalive'); fi
  echo "Set netcam_keepalive to ${VALUE}" >&2
  echo "netcam_keepalive ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"keepalive":"'"${VALUE}"'"'

  # userpass 
  VALUE=$(jq -r '.cameras['$i'].userpass' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${NETCAM_USERPASS}"; fi
  echo "Set netcam_userpass to ${VALUE}" >&2
  echo "netcam_userpass ${VALUE}" >> "${CAMERA_CONF}"
  # DO NOT RECORD; CAMERAS="${CAMERAS}"',"userpass":"'"${VALUE}"'"'

  ## numeric VALUE

  # stream_quality 
  VALUE=$(jq -r '.cameras['$i'].stream_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_quality'); fi
  echo "Set stream_quality to ${VALUE}" >&2
  echo "stream_quality ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"quality":'"${VALUE}"

  # threshold 
  VALUE=$(jq -r '.cameras['$i'].threshold' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.threshold'); fi
  echo "Set threshold to ${VALUE}" >&2
  echo "threshold ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"threshold":'"${VALUE}"

  # width 
  VALUE=$(jq -r '.cameras['$i'].width' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.width'); fi
  echo "Set width to ${VALUE}" >&2
  echo "width ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"width":'"${VALUE}"

  # height 
  VALUE=$(jq -r '.cameras['$i'].height' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.height'); fi
  echo "Set height to ${VALUE}" >&2
  echo "height ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"height":'"${VALUE}"

  # rotate 
  VALUE=$(jq -r '.cameras['$i'].rotate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.rotate'); fi
  echo "Set rotate to ${VALUE}" >&2
  echo "rotate ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"rotate":'"${VALUE}"

  # process models string to array of strings
  VALUE=$(jq -r '.cameras['$i'].models' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    W=$(echo "${WATSON}" | jq -r '.models[]?'| sed 's/\([^,]*\)\([,]*\)/"wvr:\1"\2/g' | fmt -1000)
    # echo "WATSON: ${WATSON} ${W}" >&2
    D=$(echo "${DIGITS}" | jq -r '.models[]?'| sed 's/\([^,]*\)\([,]*\)/"digits:\1"\2/g' | fmt -1000)
    # echo "DIGITS: ${DIGITS} ${D}" >&2
    VALUE=$(echo ${W} ${D})
    VALUE=$(echo "${VALUE}" | sed "s/ /,/g")
  else
    VALUE=$(echo "${VALUE}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
  fi
  echo "Set models to ${VALUE}" >&2
  CAMERAS="${CAMERAS}"',"models":['"${VALUE}"']'

  ## close CAMERAS structure
  CAMERAS="${CAMERAS}"'}'

  # modify primary configuration file with new camera configuration
  sed -i 's|; camera .*camera'"$i"'.*|camera '"${CAMERA_CONF}"'|' "${MOTION_CONF}"

done

## append to configuration JSON
if [ -n "${CAMERAS}" ]; then 
  JSON="${JSON}"',"cameras":'"${CAMERAS}"']'
fi

# set interval for events
VALUE=$(jq -r '.interval' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=30; fi
echo "Set interval to ${VALUE}" >&2
JSON="${JSON}"',"interval":'"${VALUE}"
export MOTION_EVENT_INTERVAL="${VALUE}"

# set minimum_animate; minimum 2
VALUE=$(jq -r '.minimum_animate' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=5; fi
echo "Set minimum_animate to ${VALUE}" >&2
JSON="${JSON}"',"minimum_animate":'"${VALUE}"
export MOTION_MINIMUM_ANIMATE="${VALUE}"

###
### DONE w/ JSON
###

JSON="${JSON}"'}'

export MOTION_JSON_FILE="${MOTION_CONF%/*}/${MOTION_DEVICE_NAME}.json"
echo "${JSON}" | jq '.' > "${MOTION_JSON_FILE}"
if [ ! -s "${MOTION_JSON_FILE}" ]; then
  echo "Invalid JSON: ${JSON}" >&2
  exit
fi

###
### CLOUDANT
###

URL=$(jq -r ".cloudant_url" "${CONFIG_PATH}")
USERNAME=$(jq -r ".cloudant_username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".cloudant_password" "${CONFIG_PATH}")
if [ "${URL}" != "null" ] && [ "${USERNAME}" != "null" ] && [ "${PASSWORD}" != "null" ] && [ ! -z "${URL}" ] && [ ! -z "${USERNAME}" ] && [ ! -z "${PASSWORD}" ]; then
  echo "Testing CLOUDANT" >&2
  OK=$(curl -s -q -f -L "${URL}" -u "${USERNAME}:${PASSWORD}" | jq -r '.couchdb')
  if [ "${OK}" == "null" ] || [ -z "${OK}" ]; then
    echo "Cloudant failed at ${URL} with ${USERNAME} and ${PASSWORD}; exiting" >&2
    exit
  else
    export MOTION_CLOUDANT_URL="${URL%:*}"'://'"${USERNAME}"':'"${PASSWORD}"'@'"${USERNAME}"."${URL#*.}"
  fi
  URL="${MOTION_CLOUDANT_URL}/motion"
  DB=$(curl -s -q -f -L "${URL}" | jq -r '.db_name')
  if [ "${DB}" != "motion" ]; then
    # create DB
    OK=$(curl -s -q -f -L -X PUT "${URL}" | jq '.ok')
    if [ "${OK}" != "true" ]; then
      echo "Failed to create CLOUDANT DB motion" >&2
      OFF=TRUE
    else
      echo "Created CLOUDANT DB motion" >&2
    fi
  else
    echo "CLOUDANT DB motion exists" >&2
  fi
  if [ -s "${MOTION_JSON_FILE}" ] && [ -z "${OFF}" ]; then
    URL="${URL}/${MOTION_DEVICE_NAME}"
    REV=$(curl -s -q -f -L "${URL}" | jq -r '._rev')
    if [ "${REV}" != "null" ] && [ ! -z "${REV}" ]; then
      echo "Prior record exists ${REV}" >&2
      URL="${URL}?rev=${REV}"
    fi
    OK=$(curl -s -q -f -L "${URL}" -X PUT -d "@${MOTION_JSON_FILE}" | jq '.ok')
    if [ "${OK}" != "true" ]; then
      echo "Failed to update ${URL}" $(jq -c '.' "${MOTION_JSON_FILE}") >&2
      echo "Exiting" >&2; exit
    else
      echo "Configuration for ${MOTION_DEVICE_NAME} at ${MOTION_JSON_FILE}" $(jq -c '.' "${MOTION_JSON_FILE}") >&2
    fi
  else
    echo "Failed; no DB or bad JSON" >&2
    echo "Exiting" >&2; exit
  fi
else
  echo "Cloudant URL, username and/or password undefined" >&2
fi

## DAEMON MODE
VALUE=$(jq -r ".daemon" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
echo "Set daemon to ${VALUE}" >&2
sed -i "s/^daemon\s.*/daemon ${VALUE}/" "${MOTION_CONF}"

# test hassio
echo "Testing hassio ..." $(curl -s -q -f -L -H "X-HASSIO-KEY: ${HASSIO_TOKEN}" "http://hassio/supervisor/info" | jq -c '.result') >&2
# test homeassistant
echo "Testing homeassistant ..." $(curl -s -q -f -L -u ":${HASSIO_TOKEN}" "http://hassio/homeassistant/api/states" | jq -c '.|length') "states" >&2

MOTION_CMD=$(command -v motion)
if [ ! -s "${MOTION_CMD}" ] || [ ! -s "${MOTION_CONF}" ]; then
  echo "No motion installed (${MOTION_CMD}) or motion configuration ${MOTION_CONF} does not exist" >&2
else
  # start motion
  echo "Start motion with ${MOTION_CONF}" >&2
  motion -c "${MOTION_CONF}" -l /dev/stderr
fi

if [ ! -z "${MOTION_TARGET_DIR}" ]; then
  if [ ! -d "${MOTION_TARGET_DIR}" ]; then mkdir -p "${MOTION_TARGET_DIR}"; fi
  echo "Changing working directory: ${MOTION_TARGET_DIR}" >&2
  cd "${MOTION_TARGET_DIR}"
  # start python httpd server
  echo "Starting python httpd server" >&2
  python3 -m http.server
else
  echo "Motion target directory not defined; exiting" >&2
  exit
fi
