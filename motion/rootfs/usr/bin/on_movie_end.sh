#!/bin/bash

source ${USRBIN:-/usr/bin}/motion-tools.sh

#
# on_movie_end.sh %$ %v %f %n %{fps} %Y %m %d %H %M %S
#
# %$ - camera name
# %v - Event number
# %f - file name
# %n - file type; 8 for MP4; 16 for MP4 mask
# %{fps} - frames per second
# %Y - The year as a decimal number including the century. 
# %m - The month as a decimal number (range 01 to 12). 
# %d - The day of the month as a decimal number (range 01 to 31).
# %H - The hour as a decimal number using a 24-hour clock (range 00 to 23)
# %M - The minute as a decimal number (range 00 to 59).
# %S - The second as a decimal number (range 00 to 61). 
#

on_movie_end()
{
  motion.log.debug ${FUNCNAME[0]} ${*}

  local CN="${1}"
  local EN="${2}"
  local FN="${3}"
  local FT="${4}"
  local FPS="${5}"
  local YR="${6}"
  local YR="${7}"
  local MO="${8}"
  local DY="${9}"
  local HR="${10}"
  local MN="${11}"
  local SC="${12}"
  local TS="${YR}${MO}${DY}${HR}${MN}${SC}"
  local timestamp=$(date -u +%FT%TZ)

  local jsonfile
  local dir="$(motion.config.target_dir)/${CN}"
  local name="??????????????-${EN}.json"
  local jsons=($(find "$dir" -name "${name}" -print))

  if [ ${#jsons[@]} -gt 0 ]; then
    local njson=${#jsons[@]}

    jsonfile="${jsons[$((njson-1))]}"
  else
    motion.log.warn "${FUNCNAME[0]} No JSON found; directory: ${dir}"
  fi

  if [ "${jsonfile:-null}" != 'null' ] && [ -s "${jsonfile:-}" ]; then
    local update='{"file":"'${FN}'","type":'${FT}',"fps":'${FPS}',"event":"'${EN}'","timestamp":"'${timestamp}'"}'

    case ${FT} in
      8)
       motion.log.debug "${FUNCNAME[0]} MP4 movie; type: ${FT}"
       update='{"movie":'"${update}"'}'
       ;;
      16)
       motion.log.debug "${FUNCNAME[0]} MP4 mask; type: ${FT}"
       update='{"mask":'"${update}"'}'
       ;;
      *)
       motion.log.warn "${FUNCNAME[0]} unknown movie; type: ${FT}"
       update='{"video_'${FT}'":'"${update}"'}'
       ;;
    esac

    jq '.+='"${update}" ${jsonfile} > ${jsonfile}.$$ && mv -f ${jsonfile}.$$ ${jsonfile} && result="${jsonfile}"
  else
    motion.log.error "${FUNCNAME[0]} not found or invalid JSON file: ${jsonfile}"
  fi
}

###
### main
###

on_movie_end ${*}
