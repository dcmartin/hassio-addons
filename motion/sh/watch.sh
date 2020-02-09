#!/bin/bash
mosquitto_sub -h 192.168.1.80 -u username -P password -t '+/pi3-3/start' | jq -c '{"DEVICE":.}' &
mosquitto_sub -h 192.168.1.80 -u username -P password -t '+/pi3-3/+/event/start' | jq -c '{"START":.}' &
mosquitto_sub -h 192.168.1.80 -u username -P password -t '+/pi3-3/+/event/start' | jq -c '{"END":.}' &
mosquitto_sub -h 192.168.1.80 -u username -P password -t '+/pi3-3/+/event/end/+' | jq -c '{"ANNOTATED":{"camera":.event.camera,"event":.event.id,"timestamp":.event.timestamp,"detected":.detected}}' &
mosquitto_sub -h 192.168.1.80 -u username -P password -t '+/pi3-3/+/status/+' | jq -c '{"STATUS":.}' &
