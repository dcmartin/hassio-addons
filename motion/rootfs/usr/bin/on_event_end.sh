#!/bin/bash

source /usr/bin/motion-tools.sh

###
### FUNCTIONS
###

motion.util.dateconv()
{ 
  motion.log.debug "${FUNCNAME[0]} ${*}"
  local dateconv=''

  if [ -e /usr/bin/dateutils.dconv ]; then
    dateconv=/usr/bin/dateutils.dconv
  elif [ -e /usr/bin/dateconv ]; then
    dateconv=/usr/bin/dateconv
  elif [ -e /usr/local/bin/dateconv ]; then
    dateconv=/usr/local/bin/dateconv
  fi
  
  motion.log.debug "dateconv: ${dateconv}"

  if [ ! -z "${dateconv:-}" ]; then
    result=$(${dateconv} ${*})
    motion.log.debug "Success; convert ${*}; result: ${result}"
  else
    motion.log.error "Failure; convert ${*}"
  fi
  echo "${result:-}"
}

# {
#   "group": "motion",
#   "device": "nano-1",
#   "camera": "local",
#   "event": "01",
#   "start": 1576601014
# }

motion_event_json()
{
  motion.log.debug "${FUNCNAME[0]} ${*}"

  local cn="${1}"
  local ts="${2}"
  local en="${3}"
  local dir="$(motion.config.target_dir)/${cn}"
  local result=''

  motion.log.debug "directory: ${dir}"
  local jsons=($(echo "$dir"/??????????????"-${en}".json))

  local njson=${#jsons[@]}
  motion.log.debug "Found ${njson} metadata files"

  if [ ${njson} -eq 0 ]; then
    motion.log.error "NO metadata"
  else
    local lastjson="${jsons[$((njson-1))]}"

    motion.log.debug "Last metadata file: ${lastjson}"

    if [ ! -z "${lastjson:-}" ] && [ -s "${lastjson:-}" ]; then
      motion.log.debug "FOUND metadata; file: ${lastjson}"
      result=${lastjson}
    else
      motion.log.error "MISSING metadata; file: ${lastjson}"
    fi
  fi
  echo "${result:-}"
}

# {
#   "device": "nano-1",
#   "camera": "local",
#   "type": "jpeg",
#   "date": 1576600148,
#   "seqno": "01",
#   "event": "01",
#   "id": "20191217162908-01-01",
#   "center": {
#     "x": 281,
#     "y": 124
#   },
#   "width": 158,
#   "height": 180,
#   "size": 23830,
#   "noise": 173
# }

motion_event_images()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  local lj=${1}
  local gp=$(jq -r '.group' "${lj}")
  local dv=$(jq -r '.device' "${lj}")
  local cn=$(jq -r '.camera' "${lj}")
  local en=$(jq -r '.event' "${lj}")
  local start=$(jq -r '.start' "${lj}")
  local result

  motion.log.debug "Finding images from event metadata:" $(jq -c '.' ${lj})

  if [ ! -z "${lj:-}" ] && [ -s "${lj:-}" ]; then
    local dir="${lj%/*}"
    motion.log.debug "Searching directory: ${dir}"

    local jpgs=($(find "${dir}" -name "[0-9][0-9]*-${en}-[0-9][0-9]*.jpg" -print | sort))
    local njpg=${#jpgs[@]}
    motion.log.debug "Found ${njpg} images; jpgs: ${jpgs[@]}"

    local jpegs=()
    local end=0
    if [ "${njpg:-0}" -gt 0 ]; then
      i=$((njpg-1)); while [ ${i} -ge 0 ]; do
        local jpg=${jpgs[${i}]}

        if [ ! -z "${jpg:-}" ] && [ -s "${jpg%.*}.json" ]; then
          local json="${jpg%.*}.json"
          motion.log.debug "Found metadata; contents:" $(jq -c '.' ${json})

          local id=$(jq -r '.id' "${json}")
          local this=$(jq -r '.date' "${json}")
          local ago=$((this - start))
          motion.log.debug" id: ${id}; date: ${this}; ago: ${ago}; file: ${json}"

          if [ ${ago} -lt 0 ]; then start=${this}; fi
          if [ ${this} -gt ${end} ]; then end=${this}; fi

          jpegs=(${id} ${jpegs[@]})
        else
          motion.log.warn "Did not find metadata for image: ${jpeg}"
        fi
        i=$((i-1))
      done
      jq '.start='${start}'.end='${end}'|.elapsed='$((end - start)) ${lj} > ${lj}.$$ && mv -f ${lj}.$$ ${lj}
      result="${jpegs[@]}"
    else
      motion.log.warn "NO images"
    fi
  else
    motion.log.error "NO event metadata file: ${lj:-}"
  fi
  echo "${result:-}"
}

motion_event_end()
{
  motion.log.debug "${FUNCNAME[0]} ${*}"

  local cn="${1}"
  local en="${2}"
  local yr="${3}"
  local mo="${4}"
  local dy="${5}"
  local hr="${6}"
  local mn="${7}"
  local sc="${8}"
  local ts="${yr}${mo}${dy}${hr}${mn}${sc}"

  local json=$(motion_event_json "${cn}" "${ts}" "${en}")

  if [ ! -z "${json:-}" ]; then

    local jpegs=($(motion_event_images "${json}"))
    local njpeg=${#jpegs[@]}
    if [ ${njpeg} -gt 0 ]; then
      motion.log.debug "FOUND images; count: ${njpeg}"
    else
      motion.log.error "NO images; camera: ${cn}; timestamp: ${ts}; event: ${en}; json: ${json}"
    fi
  else
    motion.log.error "NO metadata; camera: ${cn}; timestamp: ${ts}; event: ${en}"
  fi
  echo "${result:-false}"
}

#
# on_event_end.sh %$ %v %Y %m %d %H %M %S
#
# %$ - camera name
# %v - Event number. An event is a series of motion detections happening with less than 'gap' seconds between them. 
# %Y - The year as a decimal number including the century. 
# %m - The month as a decimal number (range 01 to 12). 
# %d - The day of the month as a decimal number (range 01 to 31).
# %H - The hour as a decimal number using a 24-hour clock (range 00 to 23)
# %M - The minute as a decimal number (range 00 to 59).
# %S - The second as a decimal number (range 00 to 61). 
#

on_event_end()
{
  motion.log.debug "${FUNCNAME[0]}" "${*}"

  # close I/O
  # exec 0>&- # close stdin
  # exec 1>&- # close stdout
  # exec 2>&- # close stderr

  motion_event_end ${*}

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
    MOTION_FRAME_SELECT='key' \
    && \
    /usr/bin/on_event_end.tcsh ${*}
}

motion.log.debug "START"

on_event_end ${*}

motion.log.debug "FINISH"
