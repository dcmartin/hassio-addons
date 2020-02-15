#!/bin/bash

PIDS=($(ps alxwww | egrep 'mosquitto_sub' | egrep -v 'grep' | awk '{ print $3 }'))
if [ ${#PIDS[@]} -gt 0 ]; then
   echo "Killing existing mosquitto_sub processes: ${PIDS[@]}" &> /dev/stderr
   for pid in ${PIDS[@]}; do kill -9 ${pid}; done
fi

# MOTION_CLIENT
if [ -s "MOTION_CLIENT" ] || [ ${MOTION_CLIENT:-null} != 'null' ]; then
  v=${MOTION_CLIENT:-$(cat MOTION_CLIENT)} && echo "** SPECIFIED: MOTION_CLIENT: ${v}" > /dev/stderr 
else
  v=$(hostname | tee MOTION_CLIENT) && echo "!! UNSPECIFIED: MOTION_CLIENT unset; default: ${v}" > /dev/stderr 
fi
MOTION_CLIENT=${MOTION_CLIENT:-${v}}

# MQTT_HOST
if [ -s "MQTT_HOST" ] || [ ${MQTT_HOST:-null} != 'null' ]; then
  v=${MQTT_HOST:-$(cat MQTT_HOST)} && echo "** SPECIFIED: MQTT_HOST: ${v}" > /dev/stderr 
else
  v='127.0.0.1' && echo "!! UNSPECIFIED: MQTT_HOST unset; default: ${v}" > /dev/stderr 
  v=$(read -p "?? INQUIRY: MQTT_HOST: [default: ${v}]: " && echo "${REPLY:-${v}}" | tee MQTT_HOST)
fi
MQTT_HOST=${MQTT_HOST:-${v}}

if [ -s "MQTT_PORT" ]; then MQTT_PORT=$(cat "MQTT_PORT"); else MQTT_PORT=${MQTT_PORT:-1883}; fi
if [ -s "MQTT_USERNAME" ]; then MQTT_USERNAME=$(cat "MQTT_USERNAME"); else MQTT_USERNAME=${MQTT_USERNAME:-username}; fi
if [ -s "MQTT_PASSWORD" ]; then MQTT_PASSWORD=$(cat "MQTT_PASSWORD"); else MQTT_PASSWORD=${MQTT_PASSWORD:-password}; fi

mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${MOTION_CLIENT}/start" | jq -c '{"DEVICE":.}' &
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${MOTION_CLIENT}/+/event/start" | jq -c '{"START":.}' &
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${MOTION_CLIENT}/+/event/end" | jq -c '{"END":.|(.images=(.images|length)|.image=(.image!=null))}' &
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${MOTION_CLIENT}/+/event/end/+" | jq -c '{"ANNOTATED":{"camera":.event.camera,"event":.event.id,"timestamp":.event.timestamp,"detected":.detected}}' &
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${MOTION_CLIENT}/+/status/found" | jq -c '{"FOUND":.}' &
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${MOTION_CLIENT}/+/status/lost" | jq -c '{"LOST":.}' &

mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${MOTION_CLIENT}/+/annotated" | jq -c '{"PUBLISHED":{"camera":.event.camera,"event":.event.id,"timestamp":.event.timestamp,"detected":.detected}}' &
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${MOTION_CLIENT}/+/detected" | jq -c '{"DETECTED":{"camera":.event.camera,"event":.event.id,"timestamp":.event.timestamp,"detected":.detected}}' &
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${MOTION_CLIENT}/+/detected_entity" | jq -c '{"DETECTED_ENTITY":{"camera":.event.camera,"event":.event.id,"timestamp":.event.timestamp,"detected":.detected}}' &
