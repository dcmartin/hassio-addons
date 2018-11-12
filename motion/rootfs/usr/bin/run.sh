#!/usr/bin/with-contenv bash
# ==============================================================================
set -o pipefail # Return exit status of the last command in the pipe that failed
set -o nounset  # Exit script on use of an undefined variable
# set -o errexit  # DO NOT Exit script when a command exits with non-zero status
# set -o errtrace # DO NOT Exit on error inside any functions or sub-shells

# shellcheck disable=SC1091
source /usr/lib/hassio-addons/base.sh

echo $(date) "$0 $*" >&2

if [ ! -s "${CONFIG_PATH}" ]; then
  echo "Cannot find options ${CONFIG_PATH}; exiting" >&2
  exit
fi

###
### START JSON
###
JSON='{"config_path":"'"${CONFIG_PATH}"'","ipaddr":"'$(hostname -i)'","hostname":"'"$(hostname)"'","arch":"'$(arch)'","date":'$(/bin/date +%s)


##
## host name
##
VALUE=$(jq -r ".name" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="${HOSTNAME}"; fi
echo "Setting name ${VALUE} [MOTION_DEVICE_NAME]" >&2
JSON="${JSON}"',"name":"'"${VALUE}"'"'
export MOTION_DEVICE_NAME="${VALUE}"

## web
VALUE=$(jq -r ".www" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="${MOTION_DEVICE_NAME}.local"; fi
echo "Setting www ${VALUE}" >&2
JSON="${JSON}"',"www":"'"${VALUE}"'"'

##
## device db name
##
VALUE=$(jq -r ".devicedb" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="motion"; fi
echo "Setting devicedb ${VALUE} [MOTION_DEVICE_DB]" >&2
JSON="${JSON}"',"devicedb":"'"${VALUE}"'"'
export MOTION_DEVICE_DB="${VALUE}"

##
## time zone
##
VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="GMT"; fi
echo "Setting TIMEZONE ${VALUE}" >&2
cp /usr/share/zoneinfo/${VALUE} /etc/localtime
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

## MQTT
# local MQTT server (hassio addon)
VALUE=$(jq -r ".mqtt.host" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then
  echo "Using MQTT at ${VALUE}" >&2
  MQTT='{"host":"'"${VALUE}"'"'
  export MOTION_MQTT_HOST="${VALUE}"
fi

if [ -n "${MQTT:-}" ]; then
  VALUE=$(jq -r ".mqtt.port" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
  echo "Using MQTT port: ${VALUE}" >&2
  MQTT="${MQTT}"',"port":'"${VALUE}"'}'
  export MOTION_MQTT_PORT="${VALUE}"
else
  echo "MQTT undefined; continuing" >&2
fi

if [ -n "${MQTT:-}" ]; then
  JSON="${JSON}"',"mqtt":'"${MQTT}"
else
  JSON="${JSON}"',"mqtt":null'
fi

## WATSON
WVR_URL=$(jq -r ".watson.url" "${CONFIG_PATH}")
WVR_APIKEY=$(jq -r ".watson.apikey" "${CONFIG_PATH}")
WVR_CLASSIFIER=$(jq -r ".watson.classifier" "${CONFIG_PATH}")
WVR_DATE=$(jq -r ".watson.date" "${CONFIG_PATH}")
WVR_VERSION=$(jq -r ".watson.version" "${CONFIG_PATH}")
if [ ! -z "${WVR_URL}" ] && [ ! -z "${WVR_APIKEY}" ] && [ ! -z "${WVR_DATE}" ] && [ ! -z "${WVR_VERSION}" ] && [ "${WVR_URL}" != "null" ] && [ "${WVR_APIKEY}" != "null" ] && [ "${WVR_DATE}" != "null" ] && [ "${WVR_VERSION}" != "null" ]; then
  echo "Watson Visual Recognition at ${WVR_URL} date ${WVR_DATE} version ${WVR_VERSION}" >&2
  WATSON='{"url":"'"${WVR_URL}"'","date":"'"${WVR_DATE}"'","version":"'"${WVR_VERSION}"'","models":['
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
  # make available
  export MOTION_WATSON_APIKEY="${WVR_APIKEY}"
fi
if [ -n "${WATSON:-}" ]; then
  JSON="${JSON}"',"watson":'"${WATSON}"
else
  echo "Watson Visual Recognition not specified" >&2
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
    echo "Using DIGITS at ${DIGITS_SERVER_URL} and ${DIGITS_JOBIDS}" >&2
    DIGITS="${DIGITS}"',"models":['"${DIGITS_JOBIDS}"']'
  else
    DIGITS="${DIGITS}"',"models":[]'
  fi
  DIGITS="${DIGITS}"'}'
fi
if [ -n "${DIGITS:-}" ]; then
  JSON="${JSON}"',"digits":'"${DIGITS}"
else
  echo "DIGITS not specified" >&2
  JSON="${JSON}"',"digits":null'
fi

###
### MOTION
###

echo "+++ MOTION" >&2

MOTION='{'

## DAEMON MODE
VALUE=$(jq -r ".daemon" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
echo "Set daemon to ${VALUE}" >&2
sed -i "s/^daemon\s.*/daemon ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"'"daemon":"'"${VALUE}"'"'

# set videodevice
VALUE=$(jq -r ".videodevice" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then 
  echo "Set videodevice to ${VALUE}" >&2
  sed -i "s|.*videodevice .*|videodevice ${VALUE}|" "${MOTION_CONF}"
  MOTION="${MOTION}"',"videodevice":"'"${VALUE}"'"'
fi

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
VALUE=$(jq -r ".log_motion" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=2; fi
echo "Set motion log_level to ${VALUE}" >&2
sed -i "s/.*log_level\s[0-9]\+/log_level ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_level":'"${VALUE}"

# set v4l2_pallette
VALUE=$(jq -r ".v4l2_pallette" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then
  echo "Set v4l2_pallette to ${VALUE}" >&2
  sed -i "s/.*v4l2_pallette\s[0-9]\+/v4l2_pallette ${VALUE}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"v4l2_pallette":'"${VALUE}"
fi

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
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=5; fi
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
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=8090; fi
echo "Set stream_port to ${VALUE}" >&2
sed -i "s/.*stream_port\s[0-9]\+/stream_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_port":'"${VALUE}"

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
fi
NETCAM_USERPASS="${VALUE}"

# MOTION_DATA_DIR defined for all cameras base path
VALUE=$(jq -r ".target_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_APACHE_HTDOCS}/cameras"; fi
echo "Set target_dir to ${VALUE}" >&2
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
echo "*** Found ${ncamera} cameras" >&2

MOTION_COUNT=1

for (( i=0; i<ncamera ; i++)) ; do

  ## handle more than one motion process (10 camera/process)
  if (( i / 10 )); then
    if (( i % 10 == 0 )); then
      CONF="${MOTION_CONF%%.*}.${MOTION_COUNT}.${MOTION_CONF##*.}"
      cp "${MOTION_CONF}" "${CONF}"
      sed -i 's|^camera|; camera|' "${CONF}"
      MOTION_CONF=${CONF}
      # get webcontrol_port (base)
      VALUE=$(jq -r ".webcontrol_port" "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=8080; fi
      VALUE=$(echo "$VALUE + $MOTION_COUNT" | bc)
      echo "Set webcontrol_port to ${VALUE}" >&2
      sed -i "s/.*webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
      MOTION_COUNT=$(echo "${MOTION_COUNT} + 1" | bc)
      CNUM=0
    else
      CNUM=$(echo "$CNUM + 1" | bc)
    fi
  else
    CNUM=$i
  fi

  echo "CAMERA #: $i CONF: ${MOTION_CONF} NUM: $CNUM" >&2

  if [ -z "${CAMERAS:-}" ]; then CAMERAS='['; else CAMERAS="${CAMERAS}"','; fi

  echo "+++ CAMERA ${i}" >&2

  CAMERAS="${CAMERAS}"'{"id":'${i}

  ## TOP-LEVEL

  # name
  VALUE=$(jq -r '.cameras['${i}'].name' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="camera-name${i}"; fi
  echo "Set name to ${VALUE}" >&2
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
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.target_dir'); VALUE="${VALUE}/${CNAME}"; fi
  echo "Set target_dir to ${VALUE}" >&2
  echo "target_dir ${VALUE}" >> "${CAMERA_CONF}"
  if [ ! -d "${VALUE}" ]; then mkdir -p "${VALUE}"; fi
  CAMERAS="${CAMERAS}"',"target_dir":"'"${VALUE}"'"'

  # process camera fov; WCV80n is 61.5 (62); 56 or 75 degrees for PS3 Eye camera
  VALUE=$(jq -r '.cameras['${i}'].fov' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.fov' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=62; fi
  fi
  echo "Set fov to ${VALUE}" >&2
  CAMERAS="${CAMERAS}"',"fov":'"${VALUE}"

  # process camera fps; set on wcv80n web GUI; default 6
  VALUE=$(jq -r '.cameras['${i}'].fps' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.framerate' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=5; fi
  fi
  echo "Set fps to ${VALUE}" >&2
  echo "framerate ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"fps":'"${VALUE}"

  # process camera type; wcv80n, ps3eye, panasonic
  VALUE=$(jq -r '.cameras['${i}'].type' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    VALUE=$(jq -r '.camera_type' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="wcv80n"; fi
  fi
  echo "Set type to ${VALUE}" >&2
  CAMERAS="${CAMERAS}"',"type":"'"${VALUE}"'"'

  # stream_port 
  VALUE=$(jq -r '.cameras['${i}'].port' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_port'); VALUE=$((VALUE + i)); fi
  echo "Set stream_port to ${VALUE}" >&2
  echo "stream_port ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"port":"'"${VALUE}"'"'

  # process videodevice; only "/dev/video0" enabled in config.json
  VALUE=$(jq -r '.cameras['${i}'].device?' "${CONFIG_PATH}")
  if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then 
    ## HANDLE DEVICE CAMERA
    echo "Set device to ${VALUE}" >&2
    echo "videodevice ${VALUE}" >> "${CAMERA_CONF}"
    CAMERAS="${CAMERAS}"',"device":"'"${VALUE}"'"'
    VALUE='file://'"${VALUE}"
  else
    VALUE=$(jq -r '.cameras['${i}'].url' "${CONFIG_PATH}")
    if [[ "${VALUE}" == ftpd* ]]; then
      VALUE="${VALUE%*/}.jpg"
      NETCAM_URL=$(echo "${VALUE}" | sed 's|^ftpd|file|')
    else
      # HANDLE NETCAM
      NETCAM_URL="${VALUE}"
    fi
    CAMERAS="${CAMERAS}"',"url":"'"${VALUE}"'"'
    echo "Set netcam_url to ${NETCAM_URL}" >&2
    echo "netcam_url ${NETCAM_URL}" >> "${CAMERA_CONF}"
  fi

  # palette
  VALUE=$(jq -r '.cameras['${i}'].palette' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=8; fi
  echo "Set palette to ${VALUE}" >&2
  CAMERAS="${CAMERAS}"',"palette":'"${VALUE}"
  echo "v4l2_palette ${VALUE}" >> "${CAMERA_CONF}"
  # keepalive 
  VALUE=$(jq -r '.cameras['${i}'].keepalive' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_keepalive'); fi
  echo "Set netcam_keepalive to ${VALUE}" >&2
  echo "netcam_keepalive ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"keepalive":"'"${VALUE}"'"'
  # userpass 
  VALUE=$(jq -r '.cameras['${i}'].userpass' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${NETCAM_USERPASS}"; fi
  echo "Set netcam_userpass to ${VALUE}" >&2
  echo "netcam_userpass ${VALUE}" >> "${CAMERA_CONF}"
  # DO NOT RECORD; CAMERAS="${CAMERAS}"',"userpass":"'"${VALUE}"'"'

  # stream_quality 
  VALUE=$(jq -r '.cameras['${i}'].stream_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_quality'); fi
  echo "Set stream_quality to ${VALUE}" >&2
  echo "stream_quality ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"quality":'"${VALUE}"

  # threshold 
  VALUE=$(jq -r '.cameras['${i}'].threshold' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.threshold'); fi
  echo "Set threshold to ${VALUE}" >&2
  echo "threshold ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"threshold":'"${VALUE}"

  # width 
  VALUE=$(jq -r '.cameras['${i}'].width' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.width'); fi
  echo "Set width to ${VALUE}" >&2
  echo "width ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"width":'"${VALUE}"

  # height 
  VALUE=$(jq -r '.cameras['${i}'].height' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.height'); fi
  echo "Set height to ${VALUE}" >&2
  echo "height ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"height":'"${VALUE}"

  # rotate 
  VALUE=$(jq -r '.cameras['${i}'].rotate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.rotate'); fi
  echo "Set rotate to ${VALUE}" >&2
  echo "rotate ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"rotate":'"${VALUE}"

  # process models string to array of strings
  VALUE=$(jq -r '.cameras['${i}'].models' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    W=$(echo "${WATSON:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"wvr:\1"\2/g' | fmt -1000)
    # echo "WATSON: ${WATSON} ${W}" >&2
    D=$(echo "${DIGITS:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"digits:\1"\2/g' | fmt -1000)
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
echo "Set unit_system to ${VALUE}" >&2
JSON="${JSON}"',"unit_system":"'"${VALUE}"'"'

# set latitude for events
VALUE=$(jq -r '.latitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
echo "Set latitude to ${VALUE}" >&2
JSON="${JSON}"',"latitude":'"${VALUE}"

# set longitude for events
VALUE=$(jq -r '.longitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
echo "Set longitude to ${VALUE}" >&2
JSON="${JSON}"',"longitude":'"${VALUE}"

# set elevation for events
VALUE=$(jq -r '.elevation' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
echo "Set elevation to ${VALUE}" >&2
JSON="${JSON}"',"elevation":'"${VALUE}"

# set interval for events
VALUE=$(jq -r '.interval' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
echo "Set interval to ${VALUE}" >&2
JSON="${JSON}"',"interval":'"${VALUE}"
export MOTION_EVENT_INTERVAL="${VALUE}"

# set minimum_animate; minimum 2
VALUE=$(jq -r '.minimum_animate' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=2; fi
echo "Set minimum_animate to ${VALUE}" >&2
JSON="${JSON}"',"minimum_animate":'"${VALUE}"

# set post_pictures; enumerated [on,center,first,last,best,most]
VALUE=$(jq -r '.post_pictures' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="center"; fi
echo "Set post_pictures to ${VALUE}" >&2
JSON="${JSON}"',"post_pictures":"'"${VALUE}"'"'
export MOTION_POST_PICTURES="${VALUE}"

# MOTION_SHARE_DIR defined for all cameras base path
VALUE=$(jq -r ".share_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/share/$MOTION_DEVICE_DB"; fi
if [ ! -z ${MOTION_SHARE_DIR:-} ]; then echo "*** MOTION_SHARE_DIR *** ${MOTION_SHARE_DIR}"; VALUE="${MOTION_SHARE_DIR}"; else export MOTION_SHARE_DIR="${VALUE}"; fi
echo "Set share_dir to ${VALUE}" >&2
JSON="${JSON}"',"share_dir":"'"${VALUE}"'"'

###
### DONE w/ JSON
###

JSON="${JSON}"'}'

export MOTION_JSON_FILE="${MOTION_CONF%/*}/${MOTION_DEVICE_NAME}.json"
echo "${JSON}" | jq '.' > "${MOTION_JSON_FILE}"
if [ ! -s "${MOTION_JSON_FILE}" ]; then
  echo "Invalid JSON: ${JSON}" >&2
  exit
else
  echo "Publishing configuration to ${MOTION_MQTT_HOST} topic ${MOTION_DEVICE_DB}/${MOTION_DEVICE_NAME}/start" >&2
  mosquitto_pub -r -q 2 -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "${MOTION_DEVICE_DB}/${MOTION_DEVICE_NAME}/start" -f "${MOTION_JSON_FILE}"
fi

###
### CLOUDANT
###

URL=$(jq -r ".cloudant.url" "${CONFIG_PATH}")
USERNAME=$(jq -r ".cloudant.username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".cloudant.password" "${CONFIG_PATH}")
if [ "${URL}" != "null" ] && [ "${USERNAME}" != "null" ] && [ "${PASSWORD}" != "null" ] && [ ! -z "${URL}" ] && [ ! -z "${USERNAME}" ] && [ ! -z "${PASSWORD}" ]; then
  echo "Testing CLOUDANT" >&2
  OK=$(curl -s -q -f -L "${URL}" -u "${USERNAME}:${PASSWORD}" | jq -r '.couchdb')
  if [ "${OK}" == "null" ] || [ -z "${OK}" ]; then
    echo "Cloudant failed at ${URL} with ${USERNAME} and ${PASSWORD}; exiting" >&2
    exit
  else
    export MOTION_CLOUDANT_URL="${URL%:*}"'://'"${USERNAME}"':'"${PASSWORD}"'@'"${USERNAME}"."${URL#*.}"
  fi
  URL="${MOTION_CLOUDANT_URL}/${MOTION_DEVICE_DB}"
  DB=$(curl -s -q -f -L "${URL}" | jq -r '.db_name')
  if [ "${DB}" != "${MOTION_DEVICE_DB}" ]; then
    # create DB
    OK=$(curl -s -q -f -L -X PUT "${URL}" | jq '.ok')
    if [ "${OK}" != "true" ]; then
      echo "Failed to create CLOUDANT DB ${MOTION_DEVICE_DB}" >&2
      OFF=TRUE
    else
      echo "Created CLOUDANT DB ${MOTION_DEVICE_DB}" >&2
    fi
  else
    echo "CLOUDANT DB ${MOTION_DEVICE_DB} exists" >&2
  fi
  if [ -s "${MOTION_JSON_FILE}" ] && [ -z "${OFF:-}" ]; then
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
if [ -z "${MOTION_CLOUDANT_URL:-}" ]; then
  echo "Cloudant NOT SPECIFIED" >&2
fi

# test hassio
echo "Testing hassio ..." $(curl -s -q -f -L -H "X-HASSIO-KEY: ${HASSIO_TOKEN}" "http://hassio/supervisor/info" | jq -c '.result') >&2
# test homeassistant
echo "Testing homeassistant ..." $(curl -s -q -f -L -u ":${HASSIO_TOKEN}" "http://hassio/homeassistant/api/states" | jq -c '.|length') "states" >&2

# start ftp_notifywait for all ftpd:// cameras (uses environment MOTION_JSON_FILE)
ftp_notifywait.sh "${MOTION_JSON_FILE}"

# build new yaml
mkyaml.sh "${CONFIG_PATH}"

# reload configuration
VALUE=$(jq -r ".reload" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="false"; fi
if [ "${VALUE}" != "false" ]; then 
  echo "Re-defining configuration YAML (${VALUE})" >&2
  JSON="${JSON}"',"reload":'"${VALUE}"
  rlyaml.sh "${VALUE}"
else
  echo "Not re-defining configuration YAML (${VALUE})" >&2
fi

###
### START MOTION
###

MOTION_CMD=$(command -v motion)
if [ ! -s "${MOTION_CMD}" ] || [ ! -s "${MOTION_CONF}" ]; then
  echo "No motion installed (${MOTION_CMD}) or motion configuration ${MOTION_CONF} does not exist" >&2
else
  echo "Starting ${MOTION_COUNT} motion daemons" >&2
  CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"
  for (( i = 1; i <= MOTION_COUNT;  i++)); do
    # start motion
    echo "*** Start motion ${i} with ${CONF}" >&2
    motion -b -c "${CONF}" -l /dev/stderr
    CONF="${MOTION_CONF%%.*}.${i}.${MOTION_CONF##*.}"
  done
fi

###
### CUSTOMIZE MQTT BROKER
###

mqttconf="/share/motion/mosquitto/mosquitto.conf"
mkdir -p "${mqttconf%/*}"
echo "NOTIFY -- Change Hass.io Mosquitto add-on configuration to include: $mqttconf" >&2
echo '  "customize": {' >&2
echo '    "active": true,' >&2
echo '    "folder": "motion/mosquitto"' >&2
echo '  }' >&2
echo "NOTIFY -- Re-start MQTT add-on" >&2
# change configuration
rm -f /share/motion/mosquitto/mosquitto.conf
echo "max_connections -1" >> /share/motion/mosquitto/mosquitto.conf
echo "max_inflight_messages 0" >> /share/motion/mosquitto/mosquitto.conf
echo "max_queued_messages 1000" >> /share/motion/mosquitto/mosquitto.conf

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
  echo "Starting Apache: ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT} ${MOTION_APACHE_HTDOCS}" >&2
  httpd -E /dev/stderr -e debug -f "${MOTION_APACHE_CONF}" -DFOREGROUND
fi

#if [ ! -z "${MOTION_DATA_DIR:-}" ]; then
#  if [ ! -d "${MOTION_DATA_DIR}" ]; then mkdir -p "${MOTION_DATA_DIR}"; fi
#  echo "Changing working directory: ${MOTION_DATA_DIR}" >&2
#  cd "${MOTION_DATA_DIR}"
#  # start python httpd server
#  echo "Starting python httpd server" >&2
#  python3 -m http.server
#else
#  echo "Motion data directory not defined; exiting" >&2
#fi
