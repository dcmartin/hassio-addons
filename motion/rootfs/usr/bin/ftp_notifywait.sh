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
    local type=$(echo "${cameras}" | jq -r '.[]|select(.name=="'"${name}"'").type')

    if [ "${type}" == 'ftpd' ]; then
      local dir=$(echo "${cameras}" | jq -r '.[]|select(.name=="'"${name}"'").share_dir')
      local input="${dir}.jpg"

      # prepare destination
      motion.log.debug "cleaning directory: ${input%.*}"
      rm -fr "${input%.*}"

      # create destination
      motion.log.debug "making directory: ${input%.*}"
      mkdir -p "${input%.*}"

      # make initial target
      motion.log.debug "copying sample to ${input}"
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
