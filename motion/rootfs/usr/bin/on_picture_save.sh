#!/bin/bash

source /usr/bin/motion-tools.sh

# 
# on_picture_save on_picture_save.sh %$ %v %f %n %K %L %i %J %D %N
#
# %Y = year, %m = month, %d = date,
# %H = hour, %M = minute, %S = second,
# %v = event, %q = frame number, %t = thread (camera) number,
# %D = changed pixels, %N = noise level,
# %i and %J = width and height of motion area,
# %K and %L = X and Y coordinates of motion center
# %C = value defined by text_event
# %f = filename with full path
# %n = number indicating filetype
# Both %f and %n are only defined for on_picture_save, on_movie_start and on_movie_end
#

## publish JSON and image

on_picture_save()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local CN="${1}"
  local EN="${2}"
  local IF="${3}"
  local IT="${4}"
  local MX="${5}"
  local MY="${6}"
  local MW="${7}"
  local MH="${8}"
  local SZ="${9}"
  local NL="${10}"
  local ID=${IF##*/} && ID=${ID%.*}
  local TS=$(echo "${ID}" | sed 's/\(.*\)-.*-.*/\1/') 
  local SN=$(echo "${ID}" | sed 's/.*-..-\(.*\).*/\1/')
  local NOW=$($dateconv -i '%Y%m%d%H%M%S' -f "%s" "$TS")

  # create JSON
  echo '{"device":"'$(motion.config.device)'","camera":"'"${CN}"'","type":"jpeg","date":'"${NOW}"',"seqno":"'"${SN}"'","event":"'"${EN}"'","id":"'"${ID}"'","center":{"x":'"${MX}"',"y":'"${MY}"'},"width":'"${MW}"',"height":'"${MH}"',"size":'${SZ}',"noise":'${NL}'}' > "${IF%.*}.json"

  # only post when/if
  if [ $(motion.config.post_pictures) = "on" ]; then
    # post JSON
    motion.mqtt.pub -q 2 -t "$(motion.config.group)/$(motion.config.device)/$CN/event/image" -f "${IF%.*}.json"
    # post JPEG
    motion.mqtt.pub -q 2 -t "$(motion.config.group)/$(motion.config.device)/$CN/image" -f "${IF}"
  fi
}

on_picture_save ${*}
