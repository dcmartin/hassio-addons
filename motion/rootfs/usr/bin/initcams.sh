#!/bin/bash

source /usr/bin/motion-tools.sh

###
### initcams.sh
###

motion.log.debug "START ${*}"

if [ -z "${1:-}" ]; then
  motion.log.error "requires specification of MOTION_JSON_FILE as argument"
  exit 1
fi

# ger all cameras
cameras=$(jq -r '.cameras[].name' ${1})

# initiate all cameras
for c in ${cameras}; do
  # get current time in seconds since the epoch
  dtime=$(date '+%s')
  # make it into a timestamp
  dateattr=$($dateconv -f '%Y %m %d %H %M %S' -i "%s" "$dtime")
  # notify cameras has been found
  on_camera_found.sh $c $dateattr
done

motion.log.debug "FINISH ${*}"
