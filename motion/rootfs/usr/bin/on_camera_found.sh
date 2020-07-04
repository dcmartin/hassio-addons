#!/bin/bash

source ${USRBIN:-/usr/bin}/motion-tools.sh
#
# %$ - camera name
# %Y - The year as a decimal number including the century. 
# %m - The month as a decimal number (range 01 to 12). 
# %d - The day of the month as a decimal number (range 01 to 31).
# %H - The hour as a decimal number using a 24-hour clock (range 00 to 23)
# %M - The minute as a decimal number (range 00 to 59).
# %S - The second as a decimal number (range 00 to 61). 
#

on_camera_found()
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
  #local NOW=$(motion.util.dateconv -i '%Y%m%d%H%M%S' -f "%s" "${TS}")
  local NOW=$(date -u +%s)
  local timestamp=$(date -u +%FT%TZ)
  local topic="$(motion.config.group)/$(motion.config.device)/${CN}/status/found"
  local message='{"group":"'$(motion.config.group)'","device":"'$(motion.config.device)'","camera":"'"${CN}"'","date":'"${NOW}"',"timestamp":"'${timestamp:-none}'","status":"found"}'

  motion.log.notice "Camera found: ${CN}; $(echo "${message:-null}" | jq -c '.')"

  # `status/found`
  motion.mqtt.pub -q 2 -t "${topic}" -m "${message}"
}

camera_mqtt_found_reset()
{
  local CN="${1}"

  # clean any retained messages
  if [ "${CN:-null}" != 'null' ]; then
    motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/${CN}/event" -n
    motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/${CN}/event/start" -n
    motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/${CN}/event/end" -n
    motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/${CN}/image" -n
    motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/${CN}/image/end" -n
  fi
}

###
### MAIN
###

on_camera_found ${*}
