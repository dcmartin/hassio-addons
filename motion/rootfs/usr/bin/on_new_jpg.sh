#!/bin/bash

source /usr/bin/motion-tools.sh

motion.log.trace "START"

image="${1:-}"
output="${2:-}"

if [ ! -z "${image}" ] && [ ! -z "${output}" ]; then
  motion.log.trace "moving $image to $output"
  mv -f "$image" "$output"
fi

motion.log.trace "FINISH"
