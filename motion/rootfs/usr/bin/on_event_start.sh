#!/bin/bash

source /usr/bin/motion-tools.sh

#
# on_event_start.sh %$ %v %Y %m %d %H %M %S
#
# %$ - camera name
# %v - Event number. An event is a series of motion detections happening with less than 'gap' seconds between them. 
# %Y - The year as a decimal number including the century. 
# %m - The month as a decimal number (range 01 to 12). 
# %d - The day of the month as a decimal number (range 01 to 31).
# %H - The hour as a decimal number using a 24-hour clock (range 00 to 23)
# %M - The minute as a decimal number (range 00 to 59). >& /dev/stderr
# %S - The second as a decimal number (range 00 to 61). 
#

on_event_start()
{
  motion.log.debug "${FUNCNAME[0]} ${*}"

  local CN="${1}"
  local EN="${2}"
  local YR="${3}"
  local MO="${4}"
  local DY="${5}"
  local HR="${6}"
  local MN="${7}"
  local SC="${8}"
  local TS="${YR}${MO}${DY}${HR}${MN}${SC}"
  local NOW=$($dateconv -i '%Y%m%d%H%M%S' -f "%s" "$TS")

  # payload
  local EJ="$(motion.config.target_dir)/${CN}/${TS}-${EN}.json"
  echo '{"group":"'$(motion.config.group)'","device":"'$(motion.config.device)'","camera":"'${CN}'","event":"'${EN}'","start":'${NOW}'}' > "${EJ}"

  # send MQTT
  motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/${CN}/event/start" -f "$EJ"
}

###
### main
###

motion.log.debug "START ${*}"
on_event_start ${*}
motion.log.debug "FINISH ${*}"
