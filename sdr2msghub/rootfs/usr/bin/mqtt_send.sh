#!/bin/bash

if [ -z "${ADDON_CONFIG_FILE:-}" ] || [ ! -s "${ADDON_CONFIG_FILE:-}" ]; then
  echo "$0 $$ -- ERROR: cannot find addon configuration file: ${ADDON_CONFIG_FILE:-}" &> /dev/stderr
  exit 1
fi

# find configuration
MQTT_HOST=$(jq -r ".mqtt.host" "${ADDON_CONFIG_FILE}")
MQTT_PORT=$(jq -r ".mqtt.port" "${ADDON_CONFIG_FILE}")
MQTT_TOPIC=$(jq -r ".mqtt.topic" "${ADDON_CONFIG_FILE}")

# set options
MQTT="--quiet -l -i $(hostname) -h ${MQTT_HOST} -p ${MQTT_PORT} -t ${MQTT_TOPIC}"

# check credentials
MQTT_USERNAME=$(jq -r ".mqtt.username" "${ADDON_CONFIG_FILE}")
MQTT_PASSWORD=$(jq -r ".mqtt.password" "${ADDON_CONFIG_FILE}")
if [ -n "${MQTT_USERNAME}" ] && [ -n "${MQTT_PASSWORD}" ]; then
  MQTT="${MQTT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD}"
fi

mosquitto_pub ${MQTT} >> "${HOME}/mqtt.log" &> /dev/stderr

exit 0
