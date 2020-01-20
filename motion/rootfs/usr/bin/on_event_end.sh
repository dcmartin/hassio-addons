#!/bin/bash

source /usr/bin/motion-tools.sh

###
### functions
###

motion.util.dateconv()
{ 
  motion.log.trace "${funcname[0]} ${*}"
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
    motion.log.debug "success; convert ${*}; result: ${result}"
  else
    motion.log.error "failure; convert ${*}"
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
  motion.log.trace "${funcname[0]} ${*}"

  local cn="${1}"
  local ts="${2}"
  local en="${3}"
  local dir="$(motion.config.target_dir)/${cn}"
  local result=''

  motion.log.debug "directory: ${dir}"
  local jsons=($(find "$dir" -name "??????????????-${en}.json" -print))

  local njson=${#jsons[@]}
  motion.log.debug "found ${njson} metadata files"

  if [ ${njson} -eq 0 ]; then
    motion.log.error "no metadata"
  else
    local lastjson="${jsons[$((njson-1))]}"

    motion.log.debug "last metadata file: ${lastjson}"

    if [ ! -z "${lastjson:-}" ] && [ -s "${lastjson:-}" ]; then
      motion.log.debug "found metadata; file: ${lastjson}"
      result=${lastjson}
    else
      motion.log.error "missing metadata; file: ${lastjson}"
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
  motion.log.trace "${funcname[0]}" "${*}"

  local lj=${1}
  local gp=$(jq -r '.group' "${lj}")
  local dv=$(jq -r '.device' "${lj}")
  local cn=$(jq -r '.camera' "${lj}")
  local en=$(jq -r '.event' "${lj}")
  local start=$(jq -r '.start' "${lj}")
  local metadata="$(jq -c '.' ${lj})"
  local result

  if [ ! -z "${lj:-}" ] && [ -s "${lj:-}" ]; then
    local dir="${lj%/*}"
    local jpgs=($(find "${dir}" -name "[0-9][0-9]*-${en}-[0-9][0-9]*.jpg" -print | sort))
    local njpg=${#jpgs[@]}

    motion.log.debug "event: ${en}; image count: ${njpg}"

    local jpegs=''
    local images=''
    local end=0
    if [ "${njpg:-0}" -gt 0 ]; then
      i=$((njpg-1)); while [ ${i} -ge 0 ]; do
        local jpg=${jpgs[${i}]}
        local json="${jpg%.*}.json"

        if [ ! -z "${jpg:-}" ] && [ -s "${json}" ]; then
          local image="$(jq -c '.' ${json})"
          local id=$(echo "${image:-null}" | jq -r '.id')
          local this=$(echo "${image:-null}" | jq -r '.date')
          local ago=$((this - start))

          motion.log.trace "id: ${id}; date: ${this}; ago: ${ago}"

          if [ ${ago} -lt 0 ]; then start=${this}; fi
          if [ ${this} -gt ${end} ]; then end=${this}; fi
          # concatenate
          if [ -z "${images:-}" ]; then images="${image}"; else images="${image},${images}"; fi
          jpegs=(${id} ${jpegs[@]})
        else
          motion.log.warn "missing metadata for image: ${jpeg}"
        fi
        i=$((i-1))
      done
      metadata=$(echo "${metadata}" | jq -c '.start='${start}'|.end='${end}'|.elapsed='$((end - start)))
      # update event metadata
      if [ ! -z "${images}" ]; then images='['"${images}"']'; else images='null'; fi
      metadata=$(echo "${metadata}" | jq -c '.images='"${images}")
      motion.log.info "SUCCESS: event: ${en}; file: ${lj}"
      result="${metadata}"
    else
      motion.log.error "FAILURE: no event images"
    fi
  else
    motion.log.error "FAILURE: no event metadata file: ${lj:-}"
  fi
  echo "${result:-}"
}

motion_event_images_average()
{
  local jpegs="${*}"
  local average=$(mktemp)
  local result

  if [ ${#jpegs[@]} -gt 1 ]; then
    # calculate average from images
    convert ${jpegs} -average ${average} &> /dev/null
    if [ -s "${average}" ]; then
      result="${average}"
    else
      motion.log.error "no average calculated"
    fi
  elif [ ${#jpegs[@]} -eq 1 ]; then
    motion.log.warn "using single image as average"
    cp ${jpegs[0]} ${average}
    result="${average}"
  else
    motion.log.error "no images"
  fi

  echo "${result:-}"
}

motion_event_images_differ()
{
  motion.log.trace "${funcname[0]} ${*}"

  local tmpdir=$(mktemp -d)
  local jpegs=(${*})
  local njpeg=${#jpegs[@]}
  local diffs=()
  local fuzz=20
  local most

  local avgdiff=0
  local changed=()
  local avgsize=0
  local maxsize=0
  local biggest=()
  local totaldiff=0
  local totalsize=0
  local ps=()

  if [ ${njpeg} -gt 1 ]; then
    local first=${jpegs[0]}
    local i=1
    local maxdiff=0

    while [ ${i} -lt ${njpeg} ]; do 
      local jpeg=${jpegs[${i}]}
      local file="${jpeg##*/}"
      local diff="${tmpdir}/${file%.*}-mask.jpg"
      local p=$(compare -metric fuzz -fuzz "${fuzz}%" "${jpeg}" "${first}" -compose src -highlight-color white -lowlight-color black "${diff}" 2>&1 | awk '{ print $1 }')

      totaldiff=$((totaldiff+p))
      if [ ${diff} -gt ${maxdiff:-0} ]; then maxdiff=${diff}; most=${jpeg}; fi
      diffs=(${diffs[@]} ${diff})
      i=$((i+1))
    done
    avgdiff=$((totaldiff/njpeg))
  else
    motion.log.warn "Insufficient images to compare"
  fi
  echo "${diffs[@]}"
}

motion_event_images_process()
{
  motion.log.trace "${funcname[0]} ${*}"

  local metadata="${*}"
  local result
  local images=$(echo "${metadata:-null}" | jq -c '.images')
  local nimage=$(echo "${images:-null}" | jq '.|length')
  local ids=($(echo "${images:-null}" | jq -r '.[].id'))
  local jpegs=()
  local i=0
  local result
  local first=$(echo "${images:-null}" | jq -c '.[0]')
  local last=$(echo "${images:-null}" | jq -c '.[-1]')
  local least=$(echo "${images:-null}" | jq -c '.|sort_by(.size)[0]')
  local most=$(echo "${images:-null}" | jq -c '.|sort_by(.size)[-1]')
  local center=$(echo "${images:-null}" | jq -c '.['$((nimage/2))']')
  local cn=$(echo "${metadata}" | jq -r '.camera')
  local dir="$(motion.config.target_dir)/${cn}"

  while [ ${i} -lt ${#ids[@]} ]; do
    local id=${ids[${i}]}
    local jpeg=${dir}/${id}.jpg

    if [ -s "${jpeg}" ]; then
      jpegs=(${jpegs[@]} ${jpeg})
    else
      motion.log.error "FAILURE: no image file; id: ${id}"
    fi
    i=$((i+1))
  done

  # calculate average image
  local image_avg=$(motion_event_images_average ${jpegs})
  if [ ! -z "${image_avg}" ] && [ ! -s "${image_avg}" ]; then
    motion.log.error "FAILURE: no average image; metadata: ${metadata}"
  else
    motion.log.debug "SUCCESS: average calculated; file: ${image_avg}"
    metadata=$(echo "${metadata}" | jq -c '.average="'${image_avg}'"')
  fi


  # return updated metadata
  echo "${metadata:-}"
}

motion_event_process()
{
  motion.log.trace "${funcname[0]} ${*}"

  local metadata="${*}"
  local output=$(motion_event_images_process "${metadata}")

  if [ ! -z "${output}" ]; then
    metadata=$(echo "${metadata}" | jq -c '.output='${output:-null})
  else
    motion.log.error "FAILURE: average; metadata: ${metadata}"
    rm -f "${average}"
  fi
  echo "${metadata:-null}"
}

motion_event_end()
{
  motion.log.trace "${funcname[0]} ${*}"

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
  local result=''

  if [ ! -z "${json:-}" ]; then
    local metadata=$(motion_event_images "${json}")
    local njpeg=$(echo "${metadata:-null}" | jq -r '.images|length')

    if [ ${njpeg} -gt 0 ]; then
      local now=$(date +%s)
      local start=$(echo "${metadata}" | jq -r '.start')
      local ago=$((now - start))

      metadata=$(motion_event_process "${metadata}")
      if [ "${metadata:-null}" != 'null' ]; then
        now=$(date +%s)
        ago=$((now - start))
        local timestamp=$(date -u +%FT%TZ)
        
        # update metadata timestamp
        metadata=$(echo "${metadata}" | jq -c '.timestamp="'${timestamp}'"')
        result="${metadata}"
        motion.log.info "COMPLETE: process: event: ${en}; camera: ${cn}; timestamp: ${timestamp}"
      else
        motion.log.error "FAILURE: no images processed; camera: ${cn}; event: ${en}"
      fi
    else
      motion.log.error "FAILURE: no images; camera: ${cn}; event: ${en}; metadata: ${metadata}"
    fi
  else
    motion.log.error "FAILURE: no metadata; camera: ${cn}; timestamp: ${ts}; event: ${en}"
  fi
  echo "${result:-null}"
}

#
# on_event_end.sh %$ %v %y %m %d %h %m %s
#
# %$ - camera name
# %v - event number. an event is a series of motion detections happening with less than 'gap' seconds between them. 
# %y - the year as a decimal number including the century. 
# %m - the month as a decimal number (range 01 to 12). 
# %d - the day of the month as a decimal number (range 01 to 31).
# %h - the hour as a decimal number using a 24-hour clock (range 00 to 23)
# %m - the minute as a decimal number (range 00 to 59).
# %s - the second as a decimal number (range 00 to 61). 
#

on_event_end()
{
  motion.log.trace "${funcname[0]}" "${*}"

  # close i/o
  # exec 0>&- # close stdin
  # exec 1>&- # close stdout
  # exec 2>&- # close stderr

  motion.log.notice $(motion_event_end ${*} | jq -c '.')

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
