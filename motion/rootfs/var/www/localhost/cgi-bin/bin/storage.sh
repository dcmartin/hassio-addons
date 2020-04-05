#!/bin/bash

###
### THIS SCRIPT LISTS NODES FOR THE ORGANIZATION
###
### CONSUMES THE FOLLOWING ENVIRONMENT VARIABLES:
###
### + MOTION_APACHE_HTDOCS
###

storage()
{
  local dir=${1:-${MOTION_APACHE_HTDOCS:-/var/www/localhost/htdocs}/cameras}
  local result

  if [ -d "${dir}" ]; then
    result=$(df -k ${dir} | tail -1 | awk '{ printf("{\"blocks\":%d,\"used\":%d,\"available\":%d}\n",$2,$3,$4) }' | jq '.directory="'${dir}'"')
    local output
    local cameras=$(jq -r '.cameras[].name' /etc/motion/motion.json)

    for camera in ${cameras}; do 
      local out=$(du -sk /var/www/localhost/htdocs/cameras/${camera} | awk 'function bn(fn,a,n){n=split(fn,a,"/"); return a[n]} { printf("{\"blocks\":%d,\"directory\":\"%s\"}", $1, bn($2)) }')
      if [ -z "${output:-}" ]; then output='['; else output="${output},"; fi
      output="${output}${out}"
    done
    if [ "${output:-}" ]; then output="${output}]"; else output='null'; fi
    result=$(echo "${result}" | jq '.cameras='"${output}")
  fi
  echo "${result:-null}"
}

###
### main
###

storage ${*}
