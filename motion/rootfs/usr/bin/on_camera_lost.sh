#!/bin/bash

source ${USRBIN:-/usr/bin}/motion-tools.sh

# %$ - camera name
# %Y - The year as a decimal number including the century. 
# %m - The month as a decimal number (range 01 to 12). 
# %d - The day of the month as a decimal number (range 01 to 31).
# %H - The hour as a decimal number using a 24-hour clock (range 00 to 23)
# %M - The minute as a decimal number (range 00 to 59).
# %S - The second as a decimal number (range 00 to 61). 
#

on_camera_lost()
{

  motion.log.debug "${FUNCNAME[0]} ${*}"

  local CN="${1}"
  local YR="${2}"
  local MO="${3}"
  local DY="${4}"
  local HR="${5}"
  local MN="${6}"
  local SC="${7}"
  local TS="${YR}${MO}${DY}${HR}${MN}${SC}"
  local NOW=$(motion.util.dateconv -i '%Y%m%d%H%M%S' -f "%s" "$TS")
  local timestamp=$(date -u +%FT%TZ)
  local topic="$(motion.config.group)/$(motion.config.device)/${CN}/status/lost"
  local message='{"device":"'$(motion.config.device)'","camera":"'"${CN}"'","date":'"${NOW}"',"timestamp":"'${timestamp:-none}'","status":"lost"}'

  motion.log.notice "Camera lost: ${CN}; $(echo "${message:-null}" | jq -c '.')"

  # `status/lost`
  motion.mqtt.pub -q 2 -r -t "${topic}" -m "${message}"
}

camera_mqtt_lost_reset()
{
  local CN="${1}"

  # clean any retained messages
  if [ "${CN:-null}" != 'null' ]; then
    # no signal pattern to `image` 
    motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/${CN}/image" -f "/etc/motion/sample.jpg"
    motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/${CN}/image/end" -f "/etc/motion/sample.jpg"
    # no signal pattern to `image-animated`
    motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/$CN/image-animated" -f "/etc/motion/sample.gif"
    motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/$CN/image-animated-mask" -f "/etc/motion/sample.gif"
  fi
}

###
### MAIN
###

on_camera_lost ${*}
