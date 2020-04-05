#!/bin/bash
  
###
### THIS SCRIPT LISTS NODES FOR THE ORGANIZATION
###
### CONSUMES THE FOLLOWING ENVIRONMENT VARIABLES:
###
### + MOTION_APACHE_HTDOCS
###

cleanup()
{
  local camera=${1}
  local days=${2}
  local dir=${MOTION_APACHE_HTDOCS:-/var/www/localhost/htdocs}/cameras
  local result

  if [ "${camera:-null}" != 'null' ]; then
    if [ "${camera}" != '+' ]; then
      cameras=(${camera})
    else
      cameras=($(jq -r '.cameras[].name' /etc/motion/motion.json))
    fi
    if [ ${#cameras[@]} -gt 0 ]; then
      for camera in ${cameras[@]}; do
        rm -fr ${dir}/${camera}/
        mkdir -p ${dir}/${camera}/
      done
    fi
  fi
  echo ${result:-null}
}

###
### main
###

cleanup ${*}
