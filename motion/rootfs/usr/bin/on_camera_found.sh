#!/bin/bash

source /usr/bin/motion-tools.sh

#
# %$ - camera name
# %Y - The year as a decimal number including the century. 
# %m - The month as a decimal number (range 01 to 12). 
# %d - The day of the month as a decimal number (range 01 to 31).
# %H - The hour as a decimal number using a 24-hour clock (range 00 to 23)
# %M - The minute as a decimal number (range 00 to 59).
# %S - The second as a decimal number (range 00 to 61). 
#

###
### MAIN
###

motion.log.debug "START ${*}"

CN="${1}"
YR="${2}"
MO="${3}"
DY="${4}"
HR="${5}"
MN="${6}"
SC="${7}"
TS="${YR}${MO}${DY}${HR}${MN}${SC}"

# get time
NOW=$($dateconv -i '%Y%m%d%H%M%S' -f "%s" "$TS")

topic="$(motion.config.group)/$(motion.config.device)/${CN}/status/found"
message='{"device":"'$(motion.config.device)'","camera":"'"${CN}"'","time":'"${NOW}"',"status":"found"}'

# `status/found`
motion.log.debug "sending ${message} to ${topic}"
motion.mqtt.pub -q 2 -r -t "${topic}" -m "${message}"

# test pattern to `image` 
#motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/${CN}/image" -f "/etc/motion/test.jpg"
#motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/${CN}/image/end" -f "/etc/motion/test.jpg"

# test pattern to `image-animated`
#motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/$CN/image-animated" -f "/etc/motion/test.gif"
#motion.mqtt.pub -q 2 -r -t "$(motion.config.group)/$(motion.config.device)/$CN/image-animated-mask" -f "/etc/motion/test.gif"

motion.log.debug "FINISH ${*}"
