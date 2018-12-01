#!/usr/bin/with-contenv bash
# ==============================================================================
set -o nounset  # Exit script on use of an undefined variable
set -o pipefail # Return exit status of the last command in the pipe that failed
# set -o errexit  # Exit script when a command exits with non-zero status
# set -o errtrace # Exit on error inside any functions or sub-shells

# shellcheck disable=SC1091
source /usr/lib/hassio-addons/base.sh

CONFIG_PATH="/data/options.json"

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
main() {
  hass.log.trace "${FUNCNAME[0]}"

  ###
  ### A HOST at DATE on ARCH
  ###

  # START ADDON_CONFIG
  ADDON_CONFIG='{"hostname":"'"$(hostname)"'","arch":"'"$(arch)"'","date":'$(/bin/date +%s)

  # TIMEZONE
  VALUE=$(hass.config.get "timezone")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="GMT"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"timezone":"'"${VALUE}"'"'
  cp /usr/share/zoneinfo/${VALUE} /etc/localtime

  # LATITUDE
  VALUE=$(hass.config.get "latitude")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="0"; hass.log.warning "Using default latitude: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"latitude":"'"${VALUE}"'"'
  # LONGITUDE
  VALUE=$(hass.config.get "longitude")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="0"; hass.log.warning "Using default longitude: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"longitude":"'"${VALUE}"'"'
  # ELEVATION
  VALUE=$(hass.config.get "elevation")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="0"; hass.log.warning "Using default elevation: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"elevation":'"${VALUE}"
  # UNIT SYSTEM
  VALUE=$(hass.config.get "unit_system")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="imperial"; hass.log.warning "Using default unit_system: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"unit_system":"'"${VALUE}"'"'
  # HOST IPADDR
  VALUE=$(hostname -I | awk '{ print $1 }')
  ADDON_CONFIG="${ADDON_CONFIG}"',"host_ipaddr":"'"${VALUE}"'"'

  hass.log.trace "CONFIGURATION: ${ADDON_CONFIG}"

  ## HORIZON
  VALUE=$(hass.config.get "horizon.org")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No horizon organization"; hass.die; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"horizon":{"org":"'"${VALUE}"'"'
  # APIKEY
  VALUE=$(hass.config.get "horizon.apikey")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No horizon apikey"; hass.die; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"apikey":"'"${VALUE}"'"'
  # URL
  VALUE=$(hass.config.get "horizon.url")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No horizon url"; hass.die; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"url":"'"${VALUE}"'"'
  # ORG
  VALUE=$(hass.config.get "horizon.device")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No horizon device"; hass.die; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"device":"'"${VALUE}"'"'
  ## DONE w/ HORIZON
  ADDON_CONFIG="${ADDON_CONFIG}"'}'

  hass.log.trace "CONFIGURATION: ${ADDON_CONFIG}"

  # HOST
  VALUE=$(hass.config.get "mqtt.host")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="core-mosquitto"; hass.log.warning "Using default MQTT host: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"mqtt":{"host":"'"${VALUE}"'"'
  # PORT
  VALUE=$(hass.config.get "mqtt.port")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="1883"; hass.log.warning "Using default MQTT port: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"port":'"${VALUE}"
  # USERNAME
  VALUE=$(hass.config.get "mqtt.username")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE=""; hass.log.warning "Using default MQTT username: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"username":"'"${VALUE}"'"'
  # PASSWORD
  VALUE=$(hass.config.get "mqtt.password")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE=""; hass.log.warning "Using default MQTT password: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"password":"'"${VALUE}"'"'
  ## DONE w/ MQTT
  ADDON_CONFIG="${ADDON_CONFIG}"'}'

  hass.log.trace "CONFIGURATION: ${ADDON_CONFIG}"

  ## DONE w/ ADDON_CONFIG
  ADDON_CONFIG="${ADDON_CONFIG}"'}'

  hass.log.debug "CONFIGURATION:" $(echo "${ADDON_CONFIG}" | jq -c '.')

  ## REVIEW
  HORIZON_ORGANIZATION=$(echo "${ADDON_CONFIG}" | jq -r '.horizon.org')
  HORIZON_DEVICE_DB=$(echo "${HORIZON_ORGANIZATION}" | sed 's/@/-AT-/g')
  HORIZON_DEVICE_NAME=$(echo "${ADDON_CONFIG}" | jq -r '.horizon.device')

  export ADDON_CONFIG_FILE="${CONFIG_PATH%/*}/${HORIZON_DEVICE_NAME}.json"
  echo "${ADDON_CONFIG}" | jq '.' > "${ADDON_CONFIG_FILE}"
  if [ ! -s "${ADDON_CONFIG_FILE}" ]; then
    hass.log.fatal "Invalid addon configuration: ${ADDON_CONFIG}"
    hass.die
  fi
  # report success
  hass.log.info "Configuration for ${HORIZON_DEVICE_NAME} at ${ADDON_CONFIG_FILE}" $(jq -c '.' "${ADDON_CONFIG_FILE}") >&2

  ##
  ## CLOUDANT
  ##

  # URL
  VALUE=$(hass.config.get "cloudant.url")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No cloudant url"; hass.die; fi
  URL="${VALUE}"
  # USERNAME
  VALUE=$(hass.config.get "cloudant.username")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No cloudant username"; hass.die; fi
  USERNAME="${VALUE}"
  # PASSWORD
  VALUE=$(hass.config.get "cloudant.password")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No cloudant password"; hass.die; fi
  PASSWORD="${VALUE}"

  # test database access
  hass.log.debug "Testing CLOUDANT with ${USERNAME}:${PASSWORD} at ${URL}"
  OK=$(curl -s -q -f -L "${URL}" -u "${USERNAME}":"${PASSWORD}" | jq -r '.couchdb')
  if [[ "${OK}" == "null" || -z "${OK}" ]]; then
    hass.log.fatal "Cloudant failed at ${URL} with ${USERNAME} and ${PASSWORD}; exiting"
    hass.die
  fi
  hass.log.debug "CLOUDANT found at ${URL}"
  # base URL
  CLOUDANT_URL="${URL%:*}"'://'"${USERNAME}"':'"${PASSWORD}"'@'"${USERNAME}"."${URL#*.}"
  hass.log.debug "Using CLOUDANT_URL: ${CLOUDANT_URL}"
  # find database (or create)
  URL="${CLOUDANT_URL}/${HORIZON_DEVICE_DB}"
  hass.log.debug "Looking for DB at ${URL}"
  DB=$(curl -s -q -f -L "${URL}" | jq -r '.db_name')
  if [ "${DB}" != "${HORIZON_DEVICE_DB}" ]; then
    hass.log.debug "Creating Cloudant database ${HORIZON_DEVICE_DB}"
    OK=$(curl -s -q -f -L -X PUT "${URL}" | jq '.ok')
    if [ "${OK}" != "true" ]; then
      hass.log.fatal "Could not create Cloudant DB ${HORIZON_DEVICE_DB}" >&2
      hass.die
    fi 
  fi
  hass.log.info "Cloudant DB ${HORIZON_DEVICE_DB} exists"
  URL="${URL}/${HORIZON_DEVICE_NAME}"
  hass.log.debug "Looking for previous revision at ${URL}"
  REV=$(curl -s -q -f -L "${URL}" | jq -r '._rev')
  if [ "${REV}" != "null" ] && [ ! -z "${REV}" ]; then
    hass.log.debug "Prior record exists ${REV}"
    URL="${URL}?rev=${REV}"
  fi
  hass.log.debug "Updating configuration ${ADDON_CONFIG_FILE} at ${URL}"
  OK=$(curl -s -q -f -L "${URL}" -X PUT -d "@${ADDON_CONFIG_FILE}" | jq '.ok')
  if [ "${OK}" != "true" ]; then
    hass.log.fatal "Failed to update ${URL}" $(jq -c '.' "${ADDON_CONFIG_FILE}")
    hass.die
  fi
  hass.log.debug "Updated ${URL} with " $(jq -c '.' "${ADDON_CONFIG_FILE}")

  ##
  ## CONFIGURATION
  ##

  MQTT_HOST=$(jq -r '.mqtt.host' "${ADDON_CONFIG_FILE}")
  MQTT_PORT=$(jq -r '.mqtt.port' "${ADDON_CONFIG_FILE}")
  MQTT_USERNAME=$(jq -r '.mqtt.username' "${ADDON_CONFIG_FILE}")
  MQTT_PASSWORD=$(jq -r '.mqtt.password' "${ADDON_CONFIG_FILE}")

  HORIZON_APIKEY=$(jq -r '.horizon.apikey' "${ADDON_CONFIG_FILE}")
  UNIT_SYSTEM=$(jq -r '.unit_system' "${ADDON_CONFIG_FILE}")
  TIMEZONE=$(jq -r '.timezone' "${ADDON_CONFIG_FILE}")
  HOST_IPADDR=$(jq -r '.host_ipaddr' "${ADDON_CONFIG_FILE}")
  LONGITUDE=$(jq -r '.longitude' "${ADDON_CONFIG_FILE}")
  LATITUDE=$(jq -r '.latitude' "${ADDON_CONFIG_FILE}")
  ELEVATION=$(jq -r '.elevation' "${ADDON_CONFIG_FILE}")

  ## SECRETS
  cat /root/config/secrets.yaml \
    | sed 's/%%MQTT_USERNAME%%/'"${MQTT_USERNAME}"'/g' \
    | sed 's/%%MQTT_PASSWORD%%/'"${MQTT_PASSWORD}"'/g' \
    | sed 's/%%HZN_EXCHANGE_ORG%%/'"${HORIZON_ORGANIZATION}"'/g' \
    | sed 's/%%HZN_EXCHANGE_URL%%/'"${HZN_EXCHANGE_URL}"'/g' \
    | sed 's/%%HZN_EXCHANGE_API_KEY%%/'"${HORIZON_APIKEY}"'/g' \
    > /data/secrets.yaml

  ## CONFIGURATION
  cat /root/config/configuration.yaml \
    | sed 's/%%HZN_DEVICE_NAME%%/'"${HORIZON_DEVICE_NAME}"'/g' \
    | sed 's/%%HZN_DEVICE_LATITUDE%%/'"${LATITUDE}"'/g' \
    | sed 's/%%HZN_DEVICE_LONGITUDE%%/'"${LONGITUDE}"'/g' \
    | sed 's/%%HZN_DEVICE_ELEVATION%%/'"${ELEVATION}"'/g' \
    | sed 's/%%MQTT_HOST%%/'"${MQTT_HOST}"'/g' \
    | sed 's/%%MQTT_PORT%%/'"${MQTT_PORT}"'/g' \
    | sed 's/%%UNIT_SYSTEM%%/'"${UNIT_SYSTEM}"'/g' \
    | sed 's/%%TIMEZONE%%/'"${TIMEZONE}"'/g' \
    | sed 's/%%HOST_IPADDR%%/'"${HOST_IPADDR}"'/g' \
    > /data/configuration.yaml

  ## AUTOMATIONS, GROUPS
  cp -f /root/config/automations.yaml /data/
  cp -f /root/config/groups.yaml /data/

  ##
  ## MQTT PUBLISH
  ##
  hass.log.info "Publishing configuration to ${MQTT_HOST} topic ${HORIZON_ORGANIZATION}/${HORIZON_DEVICE_NAME}/start"
  mosquitto_pub -r -q 2 -h "${MQTT_HOST}" -p "${MQTT_PORT}" -t "${HORIZON_ORGANIZATION}/${HORIZON_DEVICE_NAME}/start" -f "${ADDON_CONFIG_FILE}"

  # command line environment
  export HZN_EXCHANGE_URL=$(jq -r '.horizon.url' "${ADDON_CONFIG_FILE}")
  export HZN_EXCHANGE_USER_AUTH=$(jq -j '.horizon.org,"/iamapikey:",.horizon.apikey' "${ADDON_CONFIG_FILE}")

  # check for outstanding agreements
  AGREEMENTS=$(hzn agreement list)
  NODE=$(hzn node list)

  ##
  ## restart homeassistant
  ##

  if [[ -n ${HASSIO_TOKEN:-} ]]; then
    HASSIO_HOST = "hassio/homeassistant"
    hass.log.info "Reloading core configuration for $HASSIO_HOST ... "
    curl -s -q -f -L -H "X-HA-ACCESS: ${HASSIO_TOKEN}" -X POST -H "Content-Type: application/json" "http://${HASSIO_HOST}/api/services/homeassistant/reload_core_config"
  else
    hass.log.warning "Did not issue reload; HASSIO_TOKEN unspecified"
  fi

}

main "$@"
