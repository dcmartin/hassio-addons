#!/bin/bash

source /usr/bin/motion-tools.sh

#
# on_event_end.sh %$ %v %Y %m %d %H %M %S
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

on_event_end()
{
  motion.log.debug "${FUNCNAME[0]} ${*}"

  # export environment and run legacy tcsh script
  export \
    MOTION_GROUP=$(motion.config.group) \
    MOTION_DEVICE=$(motion.config.device) \
    MOTION_JSON_FILE=$(motion.config.file) \
    MOTION_TARGET_DIR=$(motion.config.target_dir) \
    MOTION_MQTT_HOST=$(echo $(motion.config.mqtt) | jq -r '.host') \
    MOTION_MQTT_PORT=$(echo $(motion.config.mqtt) | jq -r '.port') \
    MOTION_MQTT_USERNAME=$(echo $(motion.config.mqtt) | jq -r '.username') \
    MOTION_MQTT_PASSWORD=$(echo $(motion.config.mqtt) | jq -r '.password') \
    MOTION_LOG_LEVEL=${MOTION_LOG_LEVEL} \
    MOTION_LOGTO=${MOTION_LOGTO} \
    MOTION_FRAME_SELECT='all' \
    && \
    /usr/bin/on_event_end.tcsh ${*}
}

###
### main
###

on_event_end ${*}
