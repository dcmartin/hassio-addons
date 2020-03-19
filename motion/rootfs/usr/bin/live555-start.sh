#!/bin/bash

cmd='live555ProxyServer'
if [ -z "$(command ${cmd})" ]; then
  echo "Cannot find ${cmd}" &> /dev/stderr
  exit 1
fi

${cmd} rtsp://192.168.93.2/live
