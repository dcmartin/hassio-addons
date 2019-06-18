#!/bin/bash

source /usr/bin/motion-tools.sh

###
### MAIN
###

hzn.log.trace "started program: $0"

if [ -z "${MOTION_JSON_FILE:-}" ]; then
  hzn.log.error "cannot find configuration file; specify MOTION_JSON_FILE; exiting"
  exit 1
fi

# ger all cameras
cameras=$(jq -r '.cameras[].name' ${MOTION_JSON_FILE})

# initiate all cameras
for c in ${cameras}; do
  # get current time in seconds since the epoch
  dtime=$(date '+%s')
  # make it into a timestamp
  dateattr=$($dateconv -f '%Y %m %d %H %M %S' -i "%s" "$dtime")
  # notify cameras has been found
  on_camera_found.sh $c $dateattr
done

hzn.log.trace "completed program: $0"
