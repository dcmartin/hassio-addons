#!/bin/bash -x
if [ -s "HOST_NAME" ]; then 
  HOST_NAME=$(cat "HOST_NAME")
else 
  HOST_NAME=$(hostname)
fi

mosquitto_sub -h 192.168.1.80 -u username -P password -t "+/${HOST_NAME}/start" | jq -c '{"DEVICE":.}' &
mosquitto_sub -h 192.168.1.80 -u username -P password -t "+/${HOST_NAME}/+/event/start" | jq -c '{"START":.}' &
mosquitto_sub -h 192.168.1.80 -u username -P password -t "+/${HOST_NAME}/+/event/start" | jq -c '{"END":.}' &
mosquitto_sub -h 192.168.1.80 -u username -P password -t "+/${HOST_NAME}/+/event/end/+" | jq -c '{"ANNOTATED":{"camera":.event.camera,"event":.event.id,"timestamp":.event.timestamp,"detected":.detected}}' &
mosquitto_sub -h 192.168.1.80 -u username -P password -t "+/${HOST_NAME}/+/status/+" | jq -c '{"STATUS":.}' &
