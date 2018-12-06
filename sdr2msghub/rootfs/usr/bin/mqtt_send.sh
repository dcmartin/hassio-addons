#!/bin/bash

if [ -z "${ADDON_CONFIG_FILE:-}" ] || [ ! -s "${ADDON_CONFIG_FILE:-}" ]; then
  echo "$0 $$ -- ERROR: cannot find addon configuration file: ${ADDON_CONFIG_FILE:-}" &> /dev/stderr
  exit 1
fi

# identity of node
MQTT_IDENTITY=$(jq -r ".horizon.device" "${ADDON_CONFIG_FILE}")
if [ -z "${MQTT_IDENTITY}" ]; then
  MQTT_IDENTITY=$(hostname)
fi

# find configuration
MQTT_HOST=$(jq -r ".mqtt.host" "${ADDON_CONFIG_FILE}")
MQTT_PORT=$(jq -r ".mqtt.port" "${ADDON_CONFIG_FILE}")
MQTT_TOPIC=$(jq -r ".mqtt.topic" "${ADDON_CONFIG_FILE}")

# set options
MQTT='-i "'${MQTT_IDENTITY}'" -h "'${MQTT_HOST}'" -p '${MQTT_PORT}' -t "'${MQTT_TOPIC}'"'

# check credentials
MQTT_USERNAME=$(jq -r ".mqtt.username" "${ADDON_CONFIG_FILE}")
MQTT_PASSWORD=$(jq -r ".mqtt.password" "${ADDON_CONFIG_FILE}")
if [ -n "${MQTT_USERNAME}" ] && [ -n "${MQTT_PASSWORD}" ]; then
  MQTT="${MQTT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD}"
fi

OUT='{"host":"'${MQTT_HOST}'","port":'${MQTT_PORT}',"topic":"'${MQTT_TOPIC}'","username":"'${MQTT_USERNAME}'","password":"'${MQTT_PASSWORD}'","identity":"'${MQTT_IDENTITY}'"}'

if read -r; then
  if [ -n "${REPLY}" ]; then
    mosquitto_pub ${MQTT} -m "${REPLY}" &> /dev/stderr
    SIZE=$(echo "${REPLY}" | wc -c | awk '{ print $1 }')
  else
    SIZE=0
  fi
else
  SIZE=-1
fi

echo "${OUT}" | jq '.size='${SIZE}

exit 0
