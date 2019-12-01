#!/bin/bash

source /usr/bin/motion-tools.sh

###
### ftp_notifywait.sh
###

ftp_notifywait()
{
  motion.log.debug "${FUNCNAME[0]} ${*}"

  local cameras=$(motion.config.cameras)

  for name in $(echo "${cameras}" | jq -r '.[]|.name'); do
    local url=$(echo "${cameras}" | jq -r '.[]|select(.name=="'"${name}"'").url')

    if [[ $url =~ ftpd://* ]]; then
      local input=$(echo "$url" | sed "s|ftpd://||")

      mkdir -p "${input%.*}"
      cp -f /etc/motion/sample.jpg "${input}"
  
      # setup notifywait
      motion.log.debug "initiating do_ftp_notifywait.sh ${input%.*} ${input}"
      do_ftp_notifywait.sh "${input%.*}" "${input}" &

      # manually "find" camera
      motion.log.debug "running on_camera_found.sh ${name} $($dateconv -f '%Y %m %d %H %M %S' -i '%s' $(date '+%s'))"
      on_camera_found.sh ${name} $($dateconv -f '%Y %m %d %H %M %S' -i "%s" $(date '+%s'))
    fi
  done
}

###
### MAIN
###

motion.log.debug "START ${*}"
ftp_notifywait ${*}
motion.log.debug "FINISH ${*}"
