#!/bin/bash

###
### THIS SCRIPT LISTS NODES FOR THE ORGANIZATION
###
### CONSUMES THE FOLLOWING ENVIRONMENT VARIABLES:
###
### + MQTT_HOST
### + MQTT_USERNAME
### + MQTT_PASSWORD
###

if [ -s /data/options.json ]; then
  cat /data/options.json
else
  echo 'null'
fi
