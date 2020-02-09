#!/bin/bash

## initiate logging
export MOTION_LOG_LEVEL="${1}"
source ${USRBIN:-/usr/bin}/motion-tools.sh

###
### PRE-FLIGHT
###

## motion command
MOTION_CMD=$(command -v motion)
if [ ! -s "${MOTION_CMD}" ] || [ ! -s "${MOTION_CONF}" ]; then
  motion.log.error "Motion not installed; command: ${MOTION_CMD}; OR configuration does not exist; file: ${MOTION_CONF}"
  exit 1
fi

## defaults
if [ -z "${MOTION_CONTROL_PORT:-}" ]; then MOTION_CONTROL_PORT=8080; fi
if [ -z "${MOTION_STREAM_PORT:-}" ]; then MOTION_STREAM_PORT=8090; fi


## apache
if [ ! -s "${MOTION_APACHE_CONF}" ]; then
  motion.log.error "Missing Apache configuration"
  exit 1
fi
if [ -z "${MOTION_APACHE_HOST:-}" ]; then
  motion.log.error "Missing Apache ServerName"
  exit 1
fi
if [ -z "${MOTION_APACHE_HOST:-}" ]; then
  motion.log.error "Missing Apache ServerAdmin"
  exit 1
fi
if [ -z "${MOTION_APACHE_HTDOCS:-}" ]; then
  motion.log.error "Missing Apache HTML documents directory"
  exit 1
fi


###
## FUNCTIONS
###

## start the apache server in FOREGROUND (does not exit)
start_apache()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  local conf=${1}
  local host=${2}
  local port=${3}
  local admin="${4:-root@${host}}"
  local tokens="${5:-}"
  local signature="${6:-}"

  # edit defaults
  sed -i 's|^Listen .*|Listen '${port}'|' "${conf}"
  sed -i 's|^ServerName .*|ServerName '"${host}:${port}"'|' "${conf}"
  sed -i 's|^ServerAdmin .*|ServerAdmin '"${admin}"'|' "${conf}"

  # SSL
  if [ ! -z "${tokens:-}" ]; then
    sed -i 's|^ServerTokens.*|ServerTokens '"${tokens}"'|' "${conf}"
  fi
  if [ ! -z "${signature:-}" ]; then
    sed -i 's|^ServerSignature.*|ServerSignature '"${signature}"'|' "${conf}"
  fi

  # enable CGI
  sed -i 's|^\([^#]\)#LoadModule cgi|\1LoadModule cgi|' "${conf}"

  # export environment
  export MOTION_JSON_FILE=$(motion.config.file)
  export MOTION_SHARE_DIR=$(motion.config.share_dir)

  # pass environment
  echo 'PassEnv MOTION_JSON_FILE' >> "${conf}"
  echo 'PassEnv MOTION_SHARE_DIR' >> "${conf}"

  # make /run/apache2 for PID file
  mkdir -p /run/apache2

  # start HTTP daemon
  motion.log.info "Starting Apache: ${conf} ${host} ${port}"

  MOTION_JSON_FILE=$(motion.config.file) httpd -E /tmp/motion.log -e debug -f "${MOTION_APACHE_CONF}" -DFOREGROUND
}

process_config_camera_ftpd()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

process_config_camera_mjpeg()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

process_config_camera_http()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

process_config_camera_v4l2()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json='null'
  local value
  
  # set v4l2_pallette
  value=$(echo "${config:-null}" | jq -r ".v4l2_pallette")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=15; fi
  json=$(echo "${json}" | jq '.v4l2_palette='${value})
  sed -i "s/.*v4l2_palette\s[0-9]\+/v4l2_palette ${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"v4l2_palette":'"${value}"
  motion.log.debug "Set v4l2_palette to ${value}"
  
  # set brightness
  value=$(echo "${config:-null}" | jq -r ".v4l2_brightness")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/brightness=[0-9]\+/brightness=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"brightness":'"${value}"
  motion.log.debug "Set brightness to ${value}"
  
  # set contrast
  value=$(jq -r ".v4l2_contrast" "${CONFIG_PATH}")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/contrast=[0-9]\+/contrast=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"contrast":'"${value}"
  motion.log.debug "Set contrast to ${value}"
  
  # set saturation
  value=$(jq -r ".v4l2_saturation" "${CONFIG_PATH}")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/saturation=[0-9]\+/saturation=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"saturation":'"${value}"
  motion.log.debug "Set saturation to ${value}"
  
  # set hue
  value=$(jq -r ".v4l2_hue" "${CONFIG_PATH}")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/hue=[0-9]\+/hue=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"hue":'"${value}"
  motion.log.debug "Set hue to ${value}"

  echo "${json:-null}"
}

## cameras
process_config_cameras()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

## defaults
process_config_defaults()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

## mqtt
process_config_mqtt()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local result=
  local value
  local json

  # local json server (hassio addon)
  value=$(echo "${config}" | jq -r ".host")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value="core-mosquitto"; fi
  motion.log.debug "Using MQTT host: ${value}"
  json='{"host":"'"${value}"'"'

  # username
  value=$(echo "${config}" | jq -r ".username")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=""; fi
  motion.log.debug "Using MQTT username: ${value}"
  json="${json}"',"username":"'"${value}"'"'

  # password
  value=$(echo "${config}" | jq -r ".password")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=""; fi
  motion.log.debug "Using MQTT password: ${value}"
  json="${json}"',"password":"'"${value}"'"'

  # port
  value=$(echo "${config}" | jq -r ".port")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=1883; fi
  motion.log.debug "Using MQTT port: ${value}"
  json="${json}"',"port":'"${value}"'}'

  echo "${json:-null}"
}

## process configuration 
process_config_system()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  local timestamp=$(date -u +%FT%TZ)
  local hostname=$(hostname)
  local json='{"ipaddr":"'$(hostname -i)'","hostname":"'${hostname}'","arch":"'$(arch)'","date":'$(date -u +%s)',"timestamp":"'${timestamp}'"}'

  echo "${json:-null}"
}

## process configuration 
process_config_motion()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  local path=${1}
  local json

  json=$(echo "${json:-null}" | jq '.+='$(process_config_system ${path}))
  json=$(echo "${json:-null}" | jq '.+='$(process_config_mqtt ${path}))
  json=$(echo "${json:-null}" | jq '.+='$(process_config_defaults ${path}))
  json=$(echo "${json:-null}" | jq '.+='$(process_config_cameras ${path}))

  echo "${json:-null}"
}

start_motion()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  local path=${1}
  local json

  json=$(process_config_motion ${path})
  
  echo "${json:-null}"
}

###
### START
###

## build internal configuration
JSON='{"config_path":"'"${CONFIG_PATH}"'","ipaddr":"'$(hostname -i)'","hostname":"'"$(hostname)"'","arch":"'$(arch)'","date":'$(date -u +%s)

# device name
VALUE=$(jq -r ".device" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
  VALUE="${HOSTNAME}"
  motion.log.warn "device unspecifieid; setting device: ${VALUE}"
fi
JSON="${JSON}"',"device":"'"${VALUE}"'"'
motion.log.info "MOTION_DEVICE: ${VALUE}"
MOTION_DEVICE="${VALUE}"

# device group
VALUE=$(jq -r ".group" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
  VALUE="motion"
  motion.log.warn "group unspecifieid; setting group: ${VALUE}"
fi
JSON="${JSON}"',"group":"'"${VALUE}"'"'
motion.log.info "MOTION_GROUP: ${VALUE}"
MOTION_GROUP="${VALUE}"

# client
VALUE=$(jq -r ".client" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
  VALUE="${MOTION_DEVICE}"
  motion.log.warn "client unspecifieid; setting client: ${VALUE}"
fi
JSON="${JSON}"',"client":"'"${VALUE}"'"'
motion.log.info "MOTION_CLIENT: ${VALUE}"
MOTION_CLIENT="${VALUE}"

## time zone
VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
  VALUE="GMT"
  motion.log.warn "timezone unspecified; defaulting to ${VALUE}"
else
  motion.log.info "TIMEZONE: ${VALUE}"
fi
if [ -s "/usr/share/zoneinfo/${VALUE}" ]; then
  cp /usr/share/zoneinfo/${VALUE} /etc/localtime
  echo "${VALUE}" > /etc/timezone
else
  motion.log.error "No known timezone: ${VALUE}"
fi
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

# set unit_system for events
VALUE=$(jq -r '.unit_system' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="imperial"; fi
motion.log.info "Set unit_system to ${VALUE}"
JSON="${JSON}"',"unit_system":"'"${VALUE}"'"'

# set latitude for events
VALUE=$(jq -r '.latitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
motion.log.info "Set latitude to ${VALUE}"
JSON="${JSON}"',"latitude":'"${VALUE}"

# set longitude for events
VALUE=$(jq -r '.longitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
motion.log.info "Set longitude to ${VALUE}"
JSON="${JSON}"',"longitude":'"${VALUE}"

# set elevation for events
VALUE=$(jq -r '.elevation' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
motion.log.info "Set elevation to ${VALUE}"
JSON="${JSON}"',"elevation":'"${VALUE}"

##
## MQTT
##

# local MQTT server (hassio addon)
VALUE=$(jq -r ".mqtt.host" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="mqtt"; fi
motion.log.info "Using MQTT at ${VALUE}"
MQTT='{"host":"'"${VALUE}"'"'
# username
VALUE=$(jq -r ".mqtt.username" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
motion.log.info "Using MQTT username: ${VALUE}"
MQTT="${MQTT}"',"username":"'"${VALUE}"'"'
# password
VALUE=$(jq -r ".mqtt.password" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
motion.log.info "Using MQTT password: ${VALUE}"
MQTT="${MQTT}"',"password":"'"${VALUE}"'"'
# port
VALUE=$(jq -r ".mqtt.port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
motion.log.info "Using MQTT port: ${VALUE}"
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
VALUE=$(jq -r ".log_motion_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="ALL"; fi
sed -i "s|.*log_type.*|log_type ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"'"log_type":"'"${VALUE}"'"'
motion.log.debug "Set motion.log_type to ${VALUE}"

# set log_level
VALUE=$(jq -r ".log_motion_level" "${CONFIG_PATH}")
case ${VALUE} in
  emergency)
    VALUE=1
    ;;
  alert)
    VALUE=2
    ;;
  critical)
    VALUE=3
    ;;
  error)
    VALUE=4
    ;;
  warn)
    VALUE=5
    ;;
  info)
    VALUE=7
    ;;
  debug)
    VALUE=8
    ;;
  all)
    VALUE=9
    ;;
  *|notice)
    VALUE=6
    ;;
esac
sed -i "s/.*log_level.*/log_level ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_level":'"${VALUE}"
motion.log.debug "Set motion.log_level to ${VALUE}"

# set log_file
VALUE=$(jq -r ".log_file" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/tmp/motion.log"; fi
sed -i "s|.*log_file.*|log_file ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_file":"'"${VALUE}"'"'
motion.log.debug "Set log_file to ${VALUE}"

# shared directory for results (not images and JSON)
VALUE=$(jq -r ".share_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/share/${MOTION_GROUP}"; fi
motion.log.debug "Set share_dir to ${VALUE}"
JSON="${JSON}"',"share_dir":"'"${VALUE}"'"'
MOTION_SHARE_DIR="${VALUE}"

# base target_dir
VALUE=$(jq -r ".default.target_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_APACHE_HTDOCS}/cameras"; fi
motion.log.debug "Set target_dir to ${VALUE}"
sed -i "s|.*target_dir.*|target_dir ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"target_dir":"'"${VALUE}"'"'
MOTION_TARGET_DIR="${VALUE}"

# set auto_brightness
VALUE=$(jq -r ".default.auto_brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*auto_brightness.*/auto_brightness ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"auto_brightness":"'"${VALUE}"'"'
motion.log.debug "Set auto_brightness to ${VALUE}"

# set locate_motion_mode
VALUE=$(jq -r ".default.locate_motion_mode" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
sed -i "s/.*locate_motion_mode.*/locate_motion_mode ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_mode":"'"${VALUE}"'"'
motion.log.debug "Set locate_motion_mode to ${VALUE}"

# set locate_motion_style (box, redbox, cross, redcross)
VALUE=$(jq -r ".default.locate_motion_style" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="box"; fi
sed -i "s/.*locate_motion_style.*/locate_motion_style ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_style":"'"${VALUE}"'"'
motion.log.debug "Set locate_motion_style to ${VALUE}"

# set post_pictures; enumerated [on,center,first,last,best,most]
VALUE=$(jq -r '.default.post_pictures' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="center"; fi
motion.log.debug "Set post_pictures to ${VALUE}"
MOTION="${MOTION}"',"post_pictures":"'"${VALUE}"'"'
export MOTION_POST_PICTURES="${VALUE}"

# set picture_output (on, off, first, best, center)
VALUE=$(jq -r ".default.picture_output" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="best"; fi
sed -i "s/.*picture_output.*/picture_output ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_output":"'"${VALUE}"'"'
motion.log.debug "Set picture_output to ${VALUE}"
PICTURE_OUTPUT=${VALUE}

# set movie_output (on, off)
if [ "${PICTURE_OUTPUT:-}" == 'best' ]; then
  motion.log.notice "Picture output: ${PICTURE_OUTPUT}; defaulting movie_output to on"
  VALUE="on"
else
  VALUE=$(jq -r ".default.movie_output" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    motion.log.debug "movie_output unspecified; defaulting: off"
    VALUE="off"
  else
    case "${VALUE}" in
    3gp)
      motion.log.error "movie_output: video type ${VALUE}; ensure camera type: ftpd"
      VALUE="off"
    ;;
    mp4)
      motion.log.debug "movie_output: supported codec: ${VALUE}; - MPEG-4 Part 14 H264 encoding"
      VALUE="on"
    ;;
    mpeg4|swf|flv|ffv1|mov|mkv|hevc)
      motion.log.warn "movie_output: unsupported option: ${VALUE}"
      VALUE="on"
    ;;
    off)
     motion.log.debug "movie_output: off defined"
     VALUE="off"
    ;;
    *)
     motion.log.warn "movie_output: unknown option for movie_output: ${VALUE}"
     VALUE="off"
    ;;
    esac
  fi
fi
sed -i "s/.*movie_output .*/movie_output ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"movie_output":"'"${VALUE}"'"'
motion.log.info "Set movie_output to ${VALUE}"

# set picture_type (jpeg, ppm)
VALUE=$(jq -r ".default.picture_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="jpeg"; fi
sed -i "s/.*picture_type .*/picture_type ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_type":"'"${VALUE}"'"'
motion.log.debug "Set picture_type to ${VALUE}"

# set netcam_keepalive (off,force,on)
VALUE=$(jq -r ".default.netcam_keepalive" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*netcam_keepalive .*/netcam_keepalive ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"netcam_keepalive":"'"${VALUE}"'"'
motion.log.debug "Set netcam_keepalive to ${VALUE}"

# set netcam_userpass 
VALUE=$(jq -r ".default.netcam_userpass" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
sed -i "s/.*netcam_userpass .*/netcam_userpass ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"netcam_userpass":"'"${VALUE}"'"'
motion.log.debug "Set netcam_userpass to ${VALUE}"

## numeric values

# set v4l2_palette
VALUE=$(jq -r ".default.palette" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then
  sed -i "s/.*v4l2_palette\s[0-9]\+/v4l2_palette ${VALUE}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"palette":'"${VALUE}"
  motion.log.debug "Set palette to ${VALUE}"
fi

# set pre_capture
VALUE=$(jq -r ".default.pre_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/.*pre_capture\s[0-9]\+/pre_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"pre_capture":'"${VALUE}"
motion.log.debug "Set pre_capture to ${VALUE}"

# set post_capture
VALUE=$(jq -r ".default.post_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/.*post_capture\s[0-9]\+/post_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"post_capture":'"${VALUE}"
motion.log.debug "Set post_capture to ${VALUE}"

# set event_gap
VALUE=$(jq -r ".default.event_gap" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=5; fi
sed -i "s/.*event_gap\s[0-9]\+/event_gap ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"event_gap":'"${VALUE}"
motion.log.debug "Set event_gap to ${VALUE}"

# set fov
VALUE=$(jq -r ".default.fov" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=60; fi
MOTION="${MOTION}"',"fov":'"${VALUE}"
motion.log.debug "Set fov to ${VALUE}"

# set minimum_motion_frames
VALUE=$(jq -r ".default.minimum_motion_frames" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1; fi
sed -i "s/.*minimum_motion_frames\s[0-9]\+/minimum_motion_frames ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_motion_frames":'"${VALUE}"
motion.log.debug "Set minimum_motion_frames to ${VALUE}"

# set quality
VALUE=$(jq -r ".default.picture_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=100; fi
sed -i "s/.*picture_quality\s[0-9]\+/picture_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_quality":'"${VALUE}"
motion.log.debug "Set picture_quality to ${VALUE}"

# set framerate
VALUE=$(jq -r ".default.framerate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=5; fi
sed -i "s/.*framerate\s[0-9]\+/framerate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"framerate":'"${VALUE}"
motion.log.debug "Set framerate to ${VALUE}"

# set text_changes
VALUE=$(jq -r ".default.changes" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE='off'; fi
sed -i "s/.*text_changes\s[0-9]\+/text_changes ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"changes":"'"${VALUE}"'"'
motion.log.debug "Set text_changes to ${VALUE}"

# set text_scale
VALUE=$(jq -r ".default.text_scale" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1; fi
sed -i "s/.*text_scale\s[0-9]\+/text_scale ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"text_scale":'"${VALUE}"
motion.log.debug "Set text_scale to ${VALUE}"

# set despeckle_filter
VALUE=$(jq -r ".default.despeckle" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE='EedDl'; fi
sed -i "s/.*despeckle_filter\s[0-9]\+/despeckle_filter ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"despeckle_filter":"'"${VALUE}"'"'
motion.log.debug "Set despeckle_filter to ${VALUE}"

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
VALUE=$(jq -r ".default.brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/brightness=[0-9]\+/brightness=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"brightness":'"${VALUE}"
motion.log.debug "Set brightness to ${VALUE}"

# set contrast
VALUE=$(jq -r ".default.contrast" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/contrast=[0-9]\+/contrast=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"contrast":'"${VALUE}"
motion.log.debug "Set contrast to ${VALUE}"

# set saturation
VALUE=$(jq -r ".default.saturation" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/saturation=[0-9]\+/saturation=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"saturation":'"${VALUE}"
motion.log.debug "Set saturation to ${VALUE}"

# set hue
VALUE=$(jq -r ".default.hue" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/hue=[0-9]\+/hue=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"hue":'"${VALUE}"
motion.log.debug "Set hue to ${VALUE}"

## other

# set rotate
VALUE=$(jq -r ".default.rotate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
motion.log.debug "Set rotate to ${VALUE}"
sed -i "s/.*rotate\s[0-9]\+/rotate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"rotate":'"${VALUE}"

# set webcontrol_port
VALUE=$(jq -r ".default.webcontrol_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
motion.log.debug "Set webcontrol_port to ${VALUE}"
sed -i "s/.*webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"webcontrol_port":'"${VALUE}"

# set stream_port
VALUE=$(jq -r ".default.stream_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; fi
motion.log.debug "Set stream_port to ${VALUE}"
sed -i "s/.*stream_port\s[0-9]\+/stream_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_port":'"${VALUE}"

# set stream_quality
VALUE=$(jq -r ".default.stream_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=100; fi
motion.log.debug "Set stream_quality to ${VALUE}"
sed -i "s/.*stream_quality\s[0-9]\+/stream_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_quality":'"${VALUE}"

# set width
VALUE=$(jq -r ".default.width" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=640; fi
sed -i "s/.*width\s[0-9]\+/width ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"width":'"${VALUE}"
WIDTH=${VALUE}
motion.log.debug "Set width to ${VALUE}"

# set height
VALUE=$(jq -r ".default.height" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=480; fi
sed -i "s/.*height\s[0-9]\+/height ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"height":'"${VALUE}"
HEIGHT=${VALUE}
motion.log.debug "Set height to ${VALUE}"

# set threshold_tune (on/off)
VALUE=$(jq -r ".default.threshold_tune" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*threshold_tune .*/threshold_tune ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold_tune":"'"${VALUE}"'"'
motion.log.debug "Set threshold_tune to ${VALUE}"

# set threshold_percent
VALUE=$(jq -r ".default.threshold_percent" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [ ${VALUE:-0} == 0 ]; then 
  VALUE=$(jq -r ".default.threshold" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    VALUE=10
    motion.log.debug "DEFAULT threshold_percent to ${VALUE}"
    MOTION="${MOTION}"',"threshold_percent":'"${VALUE}"
    VALUE=$((VALUE * WIDTH * HEIGHT / 100))
  fi
else
  motion.log.debug "Set threshold_percent to ${VALUE}"
  MOTION="${MOTION}"',"threshold_percent":'"${VALUE}"
  VALUE=$((VALUE * WIDTH * HEIGHT / 100))
fi
# set threshold
motion.log.debug "Set threshold to ${VALUE}"
sed -i "s/.*threshold.*/threshold ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold":'"${VALUE}"

# set lightswitch
VALUE=$(jq -r ".default.lightswitch" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
motion.log.debug "Set lightswitch to ${VALUE}"
sed -i "s/.*lightswitch.*/lightswitch ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"lightswitch":'"${VALUE}"

# set interval for events
VALUE=$(jq -r '.default.interval' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=30; fi
motion.log.debug "Set interval to ${VALUE}"
MOTION="${MOTION}"',"interval":'"${VALUE}"
export MOTION_EVENT_INTERVAL="${VALUE}"

# set type
VALUE=$(jq -r '.default.type' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="rtsp"; fi
motion.log.debug "Set type to ${VALUE}"
MOTION="${MOTION}"',"type":"'"${VALUE}"'"'

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

## end motion structure; cameras section depends on well-formed JSON for $MOTION
MOTION="${MOTION}"'}'

## append to configuration JSON
JSON="${JSON}"',"motion":'"${MOTION}"

motion.log.debug "MOTION: $(echo "${MOTION}" | jq -c '.')"

###
### process cameras 
###

ncamera=$(jq '.cameras|length' "${CONFIG_PATH}")

MOTION_COUNT=0
CNUM=0

##
## LOOP THROUGH ALL CAMERAS
##

for (( i=0; i < ncamera; i++)); do

  motion.log.debug "+++ CAMERA ${i}"

  ## TOP-LEVEL
  if [ -z "${CAMERAS:-}" ]; then CAMERAS='['; else CAMERAS="${CAMERAS}"','; fi
  motion.log.debug "CAMERA #: $i"
  CAMERAS="${CAMERAS}"'{"id":'${i}

  # process camera type
  VALUE=$(jq -r '.cameras['${i}'].type' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    VALUE=$(jq -r '.default.type' "${CONFIG_PATH}")
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
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [ ${VALUE} -lt 1 ]; then VALUE=$(echo "${MOTION}" | jq -r '.fov'); fi
  motion.log.debug "Set fov to ${VALUE}"
  CAMERAS="${CAMERAS}"',"fov":'"${VALUE}"

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

  # process camera framerate; set on wcv80n web GUI; default 6
  VALUE=$(jq -r '.cameras['${i}'].framerate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.framerate' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=$(echo "${MOTION}" | jq -r '.framerate'); fi
  fi
  motion.log.debug "Set framerate to ${VALUE}"
  CAMERAS="${CAMERAS}"',"framerate":'"${VALUE}"
  FRAMERATE=${VALUE}

  # process camera event_gap; set on wcv80n web GUI; default 6
  VALUE=$(jq -r '.cameras['${i}'].event_gap' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.event_gap' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=$(echo "${MOTION}" | jq -r '.event_gap'); fi
  fi
  motion.log.debug "Set event_gap to ${VALUE}"
  CAMERAS="${CAMERAS}"',"event_gap":'"${VALUE}"
  EVENT_GAP=${VALUE}

  # target_dir 
  VALUE=$(jq -r '.cameras['${i}'].target_dir' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_TARGET_DIR}/${CNAME}"; fi
  motion.log.debug "Set target_dir to ${VALUE}"
  if [ ! -d "${VALUE}" ]; then mkdir -p "${VALUE}"; fi
  CAMERAS="${CAMERAS}"',"target_dir":"'"${VALUE}"'"'
  TARGET_DIR="${VALUE}"

  # TYPE
  VALUE=$(jq -r '.cameras['${i}'].type' "${CONFIG_PATH}")
  case "${VALUE}" in
    local|netcam)
        TYPE="${VALUE}"
        motion.log.info "Camera: ${CNAME}; number: ${CNUM}; type: ${TYPE}"
        CAMERAS="${CAMERAS}"',"type":"'"${TYPE}"'"'
	;;
    ftpd|mqtt)
        TYPE="${VALUE}"
        motion.log.info "Camera: ${CNAME}; number: ${CNUM}; type: ${TYPE}"
        CAMERAS="${CAMERAS}"',"type":"'"${TYPE}"'"'

        # live
        VALUE=$(jq -r '.cameras['${i}'].netcam_url' "${CONFIG_PATH}")
        if [ "${VALUE}" != "null" ] || [ ! -z "${VALUE}" ]; then 
          CAMERAS="${CAMERAS}"',"netcam_url":"'"${VALUE}"'"'
          UP=$(jq -r '.cameras['${i}'].netcam_userpass' "${CONFIG_PATH}")
          if [ "${UP}" != "null" ] && [ ! -z "${UP}" ]; then 
            CAMERAS="${CAMERAS}"',"netcam_userpass":"'"${UP}"'"'
            VALUE="${VALUE%%//*}//${UP}@${VALUE##*://}"
          fi
        fi
        motion.log.debug "Set mjpeg_url to ${VALUE}"
        CAMERAS="${CAMERAS}"',"mjpeg_url":"'"${VALUE}"'"'

        # icon
        VALUE=$(jq -r '.cameras['${i}'].icon' "${CONFIG_PATH}")
        if [ "${VALUE}" != "null" ] || [ ! -z "${VALUE}" ]; then 
          motion.log.debug "Set icon to ${VALUE}"
          CAMERAS="${CAMERAS}"',"icon":"'"${VALUE}"'"'
        fi

        # FTP share_dir
        if [ "${TYPE}" == 'ftpd' ]; then
          VALUE="${MOTION_SHARE_DIR%/*}/ftp/${CNAME}"
          motion.log.debug "Set share_dir to ${VALUE}"
          CAMERAS="${CAMERAS}"',"share_dir":"'"${VALUE}"'"'
        fi

        # complete
        CAMERAS="${CAMERAS}"'}'
        continue
	;;
    *)
        TYPE="unknown"
        motion.log.error "Camera: ${CNAME}; number: ${CNUM}; invalid camera type: ${VALUE}; setting to ${TYPE}; skipping"
        CAMERAS="${CAMERAS}"',"type":"'"${TYPE}"'"'
        # complete
        CAMERAS="${CAMERAS}"'}'
        continue
	;;
  esac

  ##
  ## handle more than one motion process (10 camera/process)
  ##

  if (( CNUM / 10 )); then
    if (( CNUM % 10 == 0 )); then
      MOTION_COUNT=$((MOTION_COUNT + 1))
      MOTION_STREAM_PORT=$((MOTION_STREAM_PORT + MOTION_COUNT))
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
    if [ ${MOTION_COUNT} -eq 0 ]; then MOTION_COUNT=1; fi
    CNUM=$((CNUM+1))
  fi
  # create configuration file
  if [ ${MOTION_CONF%/*} != ${MOTION_CONF} ]; then 
    CAMERA_CONF="${MOTION_CONF%/*}/${CNAME}.conf"
  else
    CAMERA_CONF="${CNAME}.conf"
  fi
  # add to JSON
  CAMERAS="${CAMERAS}"',"server":'"${MOTION_COUNT}"
  CAMERAS="${CAMERAS}"',"cnum":'"${CNUM}"
  CAMERAS="${CAMERAS}"',"conf":"'"${CAMERA_CONF}"'"'

  # calculate mjpeg_url for camera
  VALUE="http://127.0.0.1:${MOTION_STREAM_PORT}/${CNUM}"
  motion.log.debug "Set mjpeg_url to ${VALUE}"
  CAMERAS="${CAMERAS}"',"mjpeg_url":"'${VALUE}'"'

  ##
  ## make camera configuration file
  ##

  # basics
  echo "camera_id ${CNUM}" > "${CAMERA_CONF}"
  echo "camera_name ${CNAME}" >> "${CAMERA_CONF}"
  echo "target_dir ${TARGET_DIR}" >> "${CAMERA_CONF}"
  echo "width ${WIDTH}" >> "${CAMERA_CONF}"
  echo "height ${HEIGHT}" >> "${CAMERA_CONF}"
  echo "framerate ${FRAMERATE}" >> "${CAMERA_CONF}"
  echo "event_gap ${EVENT_GAP}" >> "${CAMERA_CONF}"

  # rotate 
  VALUE=$(jq -r '.cameras['${i}'].rotate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.rotate'); fi
  motion.log.debug "Set rotate to ${VALUE}"
  echo "rotate ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"rotate":'"${VALUE}"

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
  VALUE=$(jq -r '.cameras['${i}'].threshold_percent' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [ ${VALUE:-0} == 0 ]; then 
    VALUE=$(jq -r '.cameras['${i}'].threshold' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
      VALUE=$(echo "${MOTION}" | jq -r '.threshold_percent')
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [ ${VALUE:-0} == 0 ]; then 
        VALUE=$(echo "${MOTION}" | jq -r '.threshold')
      else
        motion.log.debug "Set threshold_percent to ${VALUE}"
        CAMERAS="${CAMERAS}"',"threshold_percent":'"${VALUE}"
        VALUE=$((VALUE * WIDTH * HEIGHT / 100))
      fi
    fi
  else
    # threshold as percent
    motion.log.debug "Set threshold_percent to ${VALUE}"
    CAMERAS="${CAMERAS}"',"threshold_percent":'"${VALUE}"
    VALUE=$((VALUE * WIDTH * HEIGHT / 100))
  fi
  motion.log.debug "Set threshold to ${VALUE}"
  echo "threshold ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"threshold":'"${VALUE}"

  if [ "${TYPE}" == 'netcam' ]; then
    # network camera
    VALUE=$(jq -r '.cameras['${i}'].netcam_url' "${CONFIG_PATH}")
    if [ ! -z "${VALUE:-}" ] && [ "${VALUE:-}" != 'null' ]; then
      # network camera
      CAMERAS="${CAMERAS}"',"netcam_url":"'"${VALUE}"'"'
      echo "netcam_url ${VALUE}" >> "${CAMERA_CONF}"
      motion.log.debug "Set netcam_url to ${VALUE}"
      # userpass 
      VALUE=$(jq -r '.cameras['${i}'].netcam_userpass' "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_userpass'); fi
      echo "netcam_userpass ${VALUE}" >> "${CAMERA_CONF}"
      CAMERAS="${CAMERAS}"',"netcam_userpass":"'"${VALUE}"'"'
      motion.log.debug "Set netcam_userpass to ${VALUE}"
      # keepalive 
      VALUE=$(jq -r '.cameras['${i}'].keepalive' "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_keepalive'); fi
      echo "netcam_keepalive ${VALUE}" >> "${CAMERA_CONF}"
      CAMERAS="${CAMERAS}"',"keepalive":"'"${VALUE}"'"'
      motion.log.debug "Set netcam_keepalive to ${VALUE}"
    else
      motion.log.error "No netcam_url specified; skipping"
      # close CAMERAS structure
      CAMERAS="${CAMERAS}"'}'
      continue;
    fi
  elif [ "${TYPE}" == 'local' ]; then
    # local camera
    VALUE=$(jq -r '.cameras['${i}'].device' "${CONFIG_PATH}")
    if [[ "${VALUE}" != /dev/video* ]]; then
      motion.log.fatal "Camera: ${i}; name: ${CNAME}; invalid videodevice ${VALUE}; exiting"
      exit 1
    fi
    echo "videodevice ${VALUE}" >> "${CAMERA_CONF}"
    motion.log.debug "Set videodevice to ${VALUE}"
    # palette
    VALUE=$(jq -r '.cameras['${i}'].palette' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.palette'); fi
    CAMERAS="${CAMERAS}"',"palette":'"${VALUE}"
    echo "v4l2_palette ${VALUE}" >> "${CAMERA_CONF}"
    motion.log.debug "Set palette to ${VALUE}"
  fi

  # close CAMERAS structure
  CAMERAS="${CAMERAS}"'}'

  # add new camera configuration
  echo "camera ${CAMERA_CONF}" >> "${MOTION_CONF}"
done
# finish CAMERAS
if [ -n "${CAMERAS:-}" ]; then 
  CAMERAS="${CAMERAS}"']'
else
  CAMERAS='null'
fi

motion.log.debug "CAMERAS: $(echo "${CAMERAS}" | jq -c '.')"

###
## append camera, finish JSON configuration, and validate
###

JSON="${JSON}"',"cameras":'"${CAMERAS}"'}'
echo "${JSON}" | jq '.' > "$(motion.config.file)"
if [ ! -s "$(motion.config.file)" ]; then
  motion.log.error "INVALID CONFIGURATION; metadata: ${JSON}"
  exit 1
fi
motion.log.debug "CONFIGURATION; file: $(motion.config.file); metadata: $(jq -c '.' $(motion.config.file))"

###
## configure inotify() for any 'ftpd' cameras
###

motion.log.debug "Settting up notifywait for FTPD cameras"
ftp_notifywait.sh "$(motion.config.file)"

###
## start all motion daemons
###

CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"
# process all motion configurations
for (( i = 1; i <= MOTION_COUNT;  i++)); do
  # test for configuration file
  if [ ! -s "${CONF}" ]; then
     motion.log.fatal "missing configuration for daemon ${i} with ${CONF}"
     exit 1
  fi
  motion.log.debug "Starting motion configuration ${i}: ${CONF}"
  motion -b -c "${CONF}"

  # get next configuration
  CONF="${MOTION_CONF%%.*}.${i}.${MOTION_CONF##*.}"
done

## publish MQTT start
motion.log.notice "PUBLISHING CONFIGURATION; topic: $(motion.config.group)/$(motion.config.device)/start"
motion.mqtt.pub -r -q 2 -t "$(motion.config.group)/$(motion.config.device)/start" -f "$(motion.config.file)"

## run apache forever
start_apache ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}
