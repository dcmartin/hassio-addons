#!/bin/bash

###
## FUNCTIONS
###

## configuration
config()
{
  local VALUE
  local JSON='{"config_path":"'"${CONFIG_PATH}"'","ipaddr":"'$(hostname -i)'","hostname":"'"$(hostname)"'","arch":"'$(arch)'","date":'$(date -u +%s)

  ## time zone
  VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
    VALUE="GMT"
    bashio::log.warn "timezone unspecified; defaulting to ${VALUE}"
  fi
  if [ -s "/usr/share/zoneinfo/${VALUE:-null}" ]; then
    cp /usr/share/zoneinfo/${VALUE} /etc/localtime
    echo "${VALUE}" > /etc/timezone
    bashio::log.info "TIMEZONE: ${VALUE}"
  else
    bashio::log.error "No known timezone: ${VALUE}"
  fi
  JSON="${JSON}"',"timezone":"'"${VALUE}"'"'
  # unit_system
  VALUE=$(jq -r '.unit_system' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="imperial"; fi
  bashio::log.info "Set unit_system to ${VALUE}"
  JSON="${JSON}"',"unit_system":"'"${VALUE}"'"'
  # latitude
  VALUE=$(jq -r '.latitude' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
  bashio::log.info "Set latitude to ${VALUE}"
  JSON="${JSON}"',"latitude":'"${VALUE}"
  # longitude
  VALUE=$(jq -r '.longitude' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
  bashio::log.info "Set longitude to ${VALUE}"
  JSON="${JSON}"',"longitude":'"${VALUE}"
  # elevation
  VALUE=$(jq -r '.elevation' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
  bashio::log.info "Set elevation to ${VALUE}"
  JSON="${JSON}"',"elevation":'"${VALUE}"
  
  ## MQTT
  # host
  VALUE=$(jq -r ".mqtt.host" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="mqtt"; fi
  bashio::log.info "Using MQTT at ${VALUE}"
  MQTT='{"host":"'"${VALUE}"'"'
  # username
  VALUE=$(jq -r ".mqtt.username" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
  bashio::log.info "Using MQTT username: ${VALUE}"
  MQTT="${MQTT}"',"username":"'"${VALUE}"'"'
  # password
  VALUE=$(jq -r ".mqtt.password" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
  bashio::log.info "Using MQTT password: ${VALUE}"
  MQTT="${MQTT}"',"password":"'"${VALUE}"'"'
  # port
  VALUE=$(jq -r ".mqtt.port" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
  bashio::log.info "Using MQTT port: ${VALUE}"
  MQTT="${MQTT}"',"port":'"${VALUE}"'}'
  
  ## finish
  JSON="${JSON}"',"mqtt":'"${MQTT}"'}'

  echo "${JSON:-null}"
}

## start
start_ambianic()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  python3 -m peerjs.ext.http-proxy &
  python3 -m ambianic
}

###
## PRE-FLIGHT
###

AMBIANIC_PATH=$(command -v motion)
if [ ! -d "${AMBIANIC_PATH}" ]; then
  bashio::log.error "Ambianic not installed; path: ${AMBIANIC_PATH}"
  exit 1
fi

###
## MAIN
###

bashio::log.notice "STARTING AMBIANIC: $(config)"

start_ambianic

