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

if [ -s /etc/motion/motion.json ]; then
  cat /etc/motion/motion.json
else
  echo 'null'
fi
