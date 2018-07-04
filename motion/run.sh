#!/bin/bash

# location of configuration file
if [ -z ${CONFIG_PATH} ]; then 
  CONFIG_PATH=/data/options.json
  MOTION_CONF=/etc/motion/motion.conf
else
  CONFIG_PATH=/tmp/options.json
  MOTION_CONF=/tmp/motion.conf
  jq '.options' $PWD/config.json > ${CONFIG_PATH}
  cp $PWD/motion.conf /tmp/motion.conf
fi

###
### START JSON
###
JSON='{'

##
## IP address
##
IPADDR=$(ipaddr show | egrep "inet" | egrep dynamic | awk '{ print $2 }')
if [ -n "${IPADDR}" ]; then
  # start building device JSON information record
  JSON="${JSON}"'"ip_address":"'"${IPADDR}"'"'
else
  echo "Cannot determine IP address; exiting"
  # exit
fi

##
## time zone
##
TIMEZONE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ -n "${TIMEZONE}" ]; then
  echo "Setting TIMEZONE ${TIMEZONE}"
  cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
  JSON="${JSON}"',"timezone":"'"${TIMEZONE}"'"'
else
  echo "Time zone not set; exiting"
  exit
fi

##
## device name & location
##
NAME=$(jq -r ".name" "${CONFIG_PATH}")
LOCATION=$(jq -r ".location" "${CONFIG_PATH}")
if [ -n "${NAME}" ] && [ -n "${LOCATION}" ]; then
  JSON="${JSON}"',"name":"'"${NAME}"'","location":"'"${LOCATION}"'","date":'$(/bin/date +%s)
else
  echo "Device name and/or location undefined; exiting"
  exit
fi

## MQTT
# local MQTT server (hassio addon)
MQTT_HOST=$(jq -r ".mqtt_host" "${CONFIG_PATH}")
MQTT_PORT=$(jq -r ".mqtt_port" "${CONFIG_PATH}")
if [ -n "${MQTT_PORT}" ] && [ -n "${MQTT_HOST}" ]; then
  echo "Using MQTT at ${MQTT_HOST}"
  JSON="${JSON}"',"mqtt":{"host":"'"${MQTT_HOST}"'","port":'"${MQTT_PORT}"'}'
else
  echo "MQTT host or port undefined; exiting"
  exit
fi

## WATSON
# watson visual recognition
WVR_URL=$(jq -r ".wvr_url" "${CONFIG_PATH}")
WVR_APIKEY=$(jq -r ".wvr_apikey" "${CONFIG_PATH}")
WVR_CLASSIFIER=$(jq -r ".wvr_classifier" "${CONFIG_PATH}")
WVR_DATE=$(jq -r ".wvr_date" "${CONFIG_PATH}")
WVR_VERSION=$(jq -r ".wvr_version" "${CONFIG_PATH}")
if [ -n "${WVR_URL}" ] && [ -n "${WVR_APIKEY}" ] && [ -n "${WVR_DATE}" ] && [ -n "${WVR_VERSION}" ]; then
  echo "Watson Visual Recognition at ${WVR_URL} with ${WVR_DATE} and {$WVR_VERSION}"
  JSON="${JSON}"',"watson":{"url":"'"${WVR_URL}"'","release":"'"${WVR_DATE}"'","version":"'"${WVR_VERSION}"'","models":['
  if [ -n "${WVR_CLASSIFIER}" ]; then
    # quote the model names
    CLASSIFIERS=$(echo "${WVR_CLASSIFIER}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
    echo "Using custom classifiers(s): ${CLASSIFIERS}"
    JSON="${JSON}"','"${CLASSIFIERS}"
  else
    # add default iif none specified
    JSON="${JSON}"'"default"'
  fi
  JSON="${JSON}"']}'
else
  echo "Watson Visual Recognition NOT CONFIGURED"
  JSON="${JSON}"',"watson":null'
fi

## DIGITS
# local nVidia DIGITS/Caffe image classification server
DIGITS_JOBID=$(jq -r ".digits_jobid" "${CONFIG_PATH}")
DIGITS_SERVER_URL=$(jq -r ".digits_server_url" "${CONFIG_PATH}")
if [ -n "${DIGITS_JOBID}" ] && [ -n "${DIGITS_SERVER_URL}" ]; then
  JOBIDS=$(echo "${DIGITS_JOBID}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
  echo "Using DIGITS ${JOBIDS}"
  JSON="${JSON}"',"digits":{"host":"'"${DIGITS_SERVER_URL}"'","models":['"${JOBIDS}"']}'
else
  echo "DIGITS NOT CONFIGURED"
  JSON="${JSON}"',"digits":null'
fi

###
### MOTION
###

MOTION='"motion":{'

## alphanumeric values

# set videodevice
VALUE=$(jq -r ".videodevice" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE="/dev/video0"; fi
echo "Set videodevice to ${VALUE}"
sed -i "s/^videodevice\s[0-9]\+/videodevice ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"videodevice":"'"${VALUE}"'"'

# set auto_brightness
VALUE=$(jq -r ".auto_brightness" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE="off"; fi
echo "Set auto_brightness to ${VALUE}"
sed -i "s/^auto_brightness\s[0-9]\+/auto_brightness ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"auto_brightness":"'"${VALUE}"'"'

# set locate_motion_mode
VALUE=$(jq -r ".locate_motion_mode" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE="off"; fi
echo "Set locate_motion_mode to ${VALUE}"
sed -i "s/^locate_motion_mode\s[0-9]\+/locate_motion_mode ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_mode":"'"${VALUE}"'"'

# set locate_motion_style (box, redbox, cross, redcross)
VALUE=$(jq -r ".locate_motion_style" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE="box"; fi
echo "Set locate_motion_style to ${VALUE}"
sed -i "s/^locate_motion_style\s[0-9]\+/locate_motion_style ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_style":"'"${VALUE}"'"'

# set output_pictures (on, off, first, best, center)
VALUE=$(jq -r ".output_pictures" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE="on"; fi
echo "Set output_pictures to ${VALUE}"
sed -i "s/^output_pictures\s[0-9]\+/output_pictures ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"output_pictures":"'"${VALUE}"'"'

# set picture_type (jpeg, ppm)
VALUE=$(jq -r ".picture_type" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE="jpeg"; fi
echo "Set picture_type to ${VALUE}"
sed -i "s/^picture_type\s[0-9]\+/picture_type ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_type":"'"${VALUE}"'"'

# set threshold_tune (jpeg, ppm)
VALUE=$(jq -r ".threshold_tune" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE="off"; fi
echo "Set threshold_tune to ${VALUE}"
sed -i "s/^threshold_tune\s[0-9]\+/threshold_tune ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold_tune":"'"${VALUE}"'"'

## numeric values

# set v412_pallette
VALUE=$(jq -r ".v412_pallette" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=17; fi
echo "Set v412_pallette to ${VALUE}"
sed -i "s/^v412_pallette\s[0-9]\+/v412_pallette ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"v412_pallette":'"${VALUE}"

# set pre_capture
VALUE=$(jq -r ".pre_capture" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=0; fi
echo "Set pre_capture to ${VALUE}"
sed -i "s/^pre_capture\s[0-9]\+/pre_capture ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"pre_capture":'"${VALUE}"

# set post_capture
VALUE=$(jq -r ".post_capture" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=0; fi
echo "Set post_capture to ${VALUE}"
sed -i "s/^post_capture\s[0-9]\+/post_capture ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"post_capture":'"${VALUE}"

# set event_gap
VALUE=$(jq -r ".event_gap" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=60; fi
echo "Set event_gap to ${VALUE}"
sed -i "s/^event_gap\s[0-9]\+/event_gap ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"event_gap":'"${VALUE}"

# set minimum_motion_frames
VALUE=$(jq -r ".minimum_motion_frames" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=1; fi
echo "Set minimum_motion_frames to ${VALUE}"
sed -i "s/^minimum_motion_frames\s[0-9]\+/minimum_motion_frames ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_motion_frames":'"${VALUE}"

# set quality
VALUE=$(jq -r ".quality" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=7; fi
echo "Set quality to ${VALUE}"
sed -i "s/^quality\s[0-9]\+/quality ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"quality":'"${VALUE}"

# set width
VALUE=$(jq -r ".width" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=640; fi
echo "Set width to ${VALUE}"
sed -i "s/^width\s[0-9]\+/width ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"width":'"${VALUE}"

# set height
VALUE=$(jq -r ".height" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=480; fi
echo "Set height to ${VALUE}"
sed -i "s/^height\s[0-9]\+/height ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"height":'"${VALUE}"

# set framerate
VALUE=$(jq -r ".framerate" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=100; fi
echo "Set framerate to ${VALUE}"
sed -i "s/^framerate\s[0-9]\+/framerate ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"framerate":'"${VALUE}"

# set minimum_frame_time
VALUE=$(jq -r ".minimum_frame_time" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=0; fi
echo "Set minimum_frame_time to ${VALUE}"
sed -i "s/^minimum_frame_time\s[0-9]\+/minimum_frame_time ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_frame_time":'"${VALUE}"

# set brightness
VALUE=$(jq -r ".brightness" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=0; fi
echo "Set brightness to ${VALUE}"
sed -i "s/^brightness\s[0-9]\+/brightness ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"brightness":'"${VALUE}"

# set contrast
VALUE=$(jq -r ".contrast" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=0; fi
echo "Set contrast to ${VALUE}"
sed -i "s/^contrast\s[0-9]\+/contrast ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"contrast":'"${VALUE}"

# set saturation
VALUE=$(jq -r ".saturation" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=0; fi
echo "Set saturation to ${VALUE}"
sed -i "s/^saturation\s[0-9]\+/saturation ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"saturation":'"${VALUE}"

# set hue
VALUE=$(jq -r ".hue" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=0; fi
echo "Set hue to ${VALUE}"
sed -i "s/^hue\s[0-9]\+/hue ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"hue":'"${VALUE}"

# set rotate
VALUE=$(jq -r ".rotate" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=0; fi
echo "Set rotate to ${VALUE}"
sed -i "s/^rotate\s[0-9]\+/rotate ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"rotate":'"${VALUE}"

# set webcontrol_port
VALUE=$(jq -r ".webcontrol_port" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=8080; fi
echo "Set webcontrol_port to ${VALUE}"
sed -i "s/^webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"webcontrol_port":'"${VALUE}"

# set stream_port
VALUE=$(jq -r ".stream_port" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=8081; fi
echo "Set stream_port to ${VALUE}"
sed -i "s/^stream_port\s[0-9]\+/stream_port ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_port":'"${VALUE}"

# set stream_quality
VALUE=$(jq -r ".stream_quality" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=50; fi
echo "Set stream_quality to ${VALUE}"
sed -i "s/^stream_quality\s[0-9]\+/stream_quality ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_quality":'"${VALUE}"

# set threshold
VALUE=$(jq -r ".threshold" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=1500; fi
echo "Set threshold to ${VALUE}"
sed -i "s/^threshold\s[0-9]\+/threshold ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold":'"${VALUE}"

# set lightswitch
VALUE=$(jq -r ".lightswitch" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=0; fi
echo "Set lightswitch to ${VALUE}"
sed -i "s/^lightswitch\s[0-9]\+/lightswitch ${VALUE}/g" "${MOTION_CONF}"
MOTION="${MOTION}"',"lightswitch":'"${VALUE}"

## process collectively

# set username and password
USERNAME=$(jq -r ".username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".password" "${CONFIG_PATH}")
if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
  echo "Set authentication to Basic for both stream and webcontrol"
  sed -i "s/^stream_auth_method.*/stream_auth_method 1/g" "${MOTION_CONF}"
  sed -i "s/.*stream_authentication.*/stream_authentication ${USERNAME}:${PASSWORD}/g" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_authentication.*/webcontrol_authentication ${USERNAME}:${PASSWORD}/g" "${MOTION_CONF}"
  MOTION="${MOTION}"',"stream_auth_method":"Basic"'
fi

# set netcam parameters
URL=$(jq -r ".netcam_url" "${CONFIG_PATH}")
USERPASS=$(jq -r ".netcam_userpass" "${CONFIG_PATH}")
if [ -n "${URL}" ] && [ -n "${USERPASS}" ]; then
  echo "Using network camera at ${URL} with ${USERPASS}"
  sed -i "s|.*netcam_url.*|netcam_url ${URL}|" "${MOTION_CONF}"
  sed -i "s|.*netcam_userpass.*|netcam_userpass ${USERPASS}|" "${MOTION_CONF}"
  MOTION="${MOTION}"',"netcam_url":"'"${URL}"'"'
fi

### end motion
MOTION="${MOTION}"'}'

JSON="${JSON}"','"${MOTION}"

###
### parameters not in prior configuration 
###

# set field of view; 56 or 75 degrees for PS3 Eye camera
VALUE=$(jq -r ".fov" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE=75; fi
echo "Set field of view to ${VALUE}"
JSON="${JSON}"',"fov":"'"${VALUE}"'"'

###
### DONE w/ JSON
###

JSON="${JSON}"'}'

###
### CLOUDANT
###

URL=$(jq -r ".cloudant_url" "${CONFIG_PATH}")
USERNAME=$(jq -r ".cloudant_username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".cloudant_password" "${CONFIG_PATH}")
if [ -n "${URL}" ] && [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
  echo "Using CLOUDANT as ${USERNAME}"
  DB=$(curl -u "${USERNAME}":"${PASSWORD}" -q -s -X GET "${URL}/devices" | jq '.db_name')
  if [ "${DB}" == "null" ]; then
    # create DB
    DB=$(curl -u "${USERNAME}":"${PASSWORD}" -q -s -X PUT "${URL}/devices" | jq '.ok')
    if [ "${DB}" != "true" ]; then
      OFF=TRUE
    fi
  fi
  if [ -z "${OFF}" ]; then
    URL="${URL}/${DEVICE_NAME}"
    REV=$(curl -u "${USERNAME}":"${PASSWORD}" -s -q "${URL}" | jq -r '._rev')
    if [ -n "${REV}" ]; then
      URL="${URL}?rev=${REV}"
    fi
    echo "Updating ${DEVICE_NAME} with " $(echo "${JSON}" | jq -c '.')
    curl -u "${USERNAME}":"${PASSWORD}" -q -s -H "Content-type: application/json" -X PUT "${URL}" -d "${JSON}"
  else
    echo "Failed to access/create DB"
    exit
  fi
else
  echo "Cloudant URL, username and/or password undefined; exiting"
  # exit
fi

## TARGET_DIR
VALUE=$(jq -r ".target_dir" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE="/share/motion"; fi
echo "Set target_dir to ${VALUE}"
sed -i "s/^target_dir\s.*/target_dir ${VALUE}/g" "${MOTION_CONF}"
echo "CHANGING CURRENT WORKING DIRECTORY TO ${VALUE}"
mkdir -p "${VALUE}" ; cd "${VALUE}"

## DAEMON MODE
VALUE=$(jq -r ".daemon" "${CONFIG_PATH}")
if [ -n "${VALUE}" ]; then VALUE="on"; fi
echo "Set daemon to ${VALUE}"
sed -i "s/^daemon\s.*/daemon ${VALUE}/g" "${MOTION_CONF}"

# run
echo "START MOTION"
motion -l /dev/stderr

# start python httpd server

echo "START PYTHON"
python3 -m http.server
