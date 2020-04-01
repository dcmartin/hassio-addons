#!/bin/bash
DIR=${DIR:-/config/www/images}
if [ -d "${DIR}" ]; then
  if [ ! -z "${1:-}" ]; then
    file=${1}
    if [ ! -z "${2:-}" ]; then
      file=${1}-${2}
    fi
    file="${DIR}/motion_${file}.gif"
    if [ -s ${file} ]; then
      cat ${file}
    fi
  fi
fi
