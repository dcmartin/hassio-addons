#!/bin/bash

PIDS=($(ps alxwww | egrep 'mosquitto_sub' | egrep -v 'grep' | awk '{ print $3 }'))
if [ ${#PIDS[@]} -gt 0 ]; then
   echo "Killing existing mosquitto_sub processes: ${PIDS[@]}" &> /dev/stderr
   for pid in ${PIDS[@]}; do kill -9 ${pid}; done
fi

if [ -s "HOST_NAME" ]; then HOST_NAME=$(cat "HOST_NAME"); else HOST_NAME=$(hostname); fi
if [ -s "MQTT_HOST" ]; then MQTT_HOST=$(cat "MQTT_HOST"); else MQTT_HOST='core-mosquitto'; fi
if [ -s "MQTT_PORT" ]; then MQTT_PORT=$(cat "MQTT_PORT"); else MQTT_PORT='1883'; fi
if [ -s "MQTT_USERNAME" ]; then MQTT_USERNAME=$(cat "MQTT_USERNAME"); else MQTT_USERNAME='username'; fi
if [ -s "MQTT_PASSWORD" ]; then MQTT_PASSWORD=$(cat "MQTT_PASSWORD"); else MQTT_PASSWORD='password'; fi

mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${HOST_NAME}/start" | jq -c '{"DEVICE":.}' &
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${HOST_NAME}/+/event/start" | jq -c '{"START":.}' &
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${HOST_NAME}/+/event/end" | jq -c '{"END":.|(.images=(.images|length)|.image=(.image!=null))}' &
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${HOST_NAME}/+/event/end/+" | jq -c '{"ANNOTATED":{"camera":.event.camera,"event":.event.id,"timestamp":.event.timestamp,"detected":.detected}}' &
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${HOST_NAME}/+/status/found" | jq -c '{"FOUND":.}' &
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t "+/${HOST_NAME}/+/status/lost" | jq -c '{"LOST":.}' &
