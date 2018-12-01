#!/usr/bin/with-contenv bash
# ==============================================================================
set -o nounset  # Exit script on use of an undefined variable
set -o pipefail # Return exit status of the last command in the pipe that failed
# set -o errexit  # Exit script when a command exits with non-zero status
# set -o errtrace # Exit on error inside any functions or sub-shells

# shellcheck disable=SC1091
source /usr/lib/hassio-addons/base.sh

CONFIG_PATH="/data/options.json"
HORIZON_CONFIG_DB="hzn-config"

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
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then VALUE="GMT"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"timezone":"'"${VALUE}"'"'
  # set timezone
  cp /usr/share/zoneinfo/${VALUE} /etc/localtime

  # LATITUDE
  VALUE=$(hass.config.get "latitude")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then VALUE="0"; hass.log.warning "Using default latitude: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"latitude":'"${VALUE}"
  # LONGITUDE
  VALUE=$(hass.config.get "longitude")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then VALUE="0"; hass.log.warning "Using default longitude: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"longitude":'"${VALUE}"
  # ELEVATION
  VALUE=$(hass.config.get "elevation")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then VALUE="0"; hass.log.warning "Using default elevation: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"elevation":'"${VALUE}"
  # UNIT SYSTEM
  VALUE=$(hass.config.get "unit_system")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then VALUE="imperial"; hass.log.warning "Using default unit_system: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"unit_system":"'"${VALUE}"'"'
  # REFRESH
  VALUE=$(hass.config.get "refresh")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then VALUE="900"; hass.log.warning "Using default refresh: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"refresh":'"${VALUE}"
  # HOST IPADDR
  VALUE=$(hostname -I | awk '{ print $1 }')
  ADDON_CONFIG="${ADDON_CONFIG}"',"host_ipaddr":"'"${VALUE}"'"'

  ## HORIZON
  VALUE=$(hass.config.get "horizon.org")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then hass.log.fatal "No horizon organization"; hass.die; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"horizon":{"org":"'"${VALUE}"'"'
  # APIKEY
  VALUE=$(hass.config.get "horizon.apikey")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then hass.log.fatal "No horizon apikey"; hass.die; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"apikey":"'"${VALUE}"'"'
  # URL
  VALUE=$(hass.config.get "horizon.url")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then hass.log.fatal "No horizon url"; hass.die; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"url":"'"${VALUE}"'"'
  # DEVICE
  VALUE=$(hass.config.get "horizon.device")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then hass.log.fatal "No horizon device"; hass.die; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"device":"'"${VALUE}"'"'
  # CONFIG
  VALUE=$(hass.config.get "horizon.config")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then hass.log.warning "No horizon configuration"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"config":"'"${VALUE}"'"'
  ## DONE w/ HORIZON
  ADDON_CONFIG="${ADDON_CONFIG}"'}'

  # HOST
  VALUE=$(hass.config.get "mqtt.host")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then VALUE="core-mosquitto"; hass.log.warning "Using default MQTT host: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"mqtt":{"host":"'"${VALUE}"'"'
  # PORT
  VALUE=$(hass.config.get "mqtt.port")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then VALUE="1883"; hass.log.warning "Using default MQTT port: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"port":'"${VALUE}"
  # USERNAME
  VALUE=$(hass.config.get "mqtt.username")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then VALUE=""; hass.log.warning "Using default MQTT username: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"username":"'"${VALUE}"'"'
  # PASSWORD
  VALUE=$(hass.config.get "mqtt.password")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then VALUE=""; hass.log.warning "Using default MQTT password: ${VALUE}"; fi
  ADDON_CONFIG="${ADDON_CONFIG}"',"password":"'"${VALUE}"'"'
  ## DONE w/ MQTT
  ADDON_CONFIG="${ADDON_CONFIG}"'}'

  ## DONE w/ ADDON_CONFIG
  ADDON_CONFIG="${ADDON_CONFIG}"'}'
  hass.log.debug "CONFIGURATION:" $(echo "${ADDON_CONFIG}" | jq -c '.')

  ## ADDON CONFIGURATION
  HORIZON_ORGANIZATION=$(echo "${ADDON_CONFIG}" | jq -r '.horizon.org')
  HORIZON_DEVICE_DB=$(echo "${HORIZON_ORGANIZATION}" | sed 's/@.*//')
  HORIZON_DEVICE_NAME=$(echo "${ADDON_CONFIG}" | jq -r '.horizon.device')
  HORIZON_CONFIG_NAME=$(echo "${ADDON_CONFIG}" | jq -r '.horizon.config')
  ADDON_CONFIG_FILE="${CONFIG_PATH%/*}/${HORIZON_DEVICE_NAME}.json"
  # check it
  echo "${ADDON_CONFIG}" | jq '.' > "${ADDON_CONFIG_FILE}"
  if [ ! -s "${ADDON_CONFIG_FILE}" ]; then
    hass.log.fatal "Invalid addon configuration: ${ADDON_CONFIG}"
    hass.die
  else
    hass.log.fatal "Valid addon configuration: ${ADDON_CONFIG_FILE}"
  fi

  ##
  ## HORIZON CHECK
  ##

  # command line environment
  export HZN_EXCHANGE_URL=$(jq -r '.horizon.url' "${ADDON_CONFIG_FILE}")
  export HZN_EXCHANGE_USER_AUTH=$(jq -j '.horizon.org,"/iamapikey:",.horizon.apikey' "${ADDON_CONFIG_FILE}")
  # agreements
  AGREEMENTS=$(hzn agreement list)
  hass.log.info "Horizon agreements: " $(echo "${AGREEMENTS}" | jq -c '.')
  # node
  NODE=$(hzn node list)
  hass.log.info "Horizon node list: " $(echo "${NODE}" | jq -c '.')
  # update configuration
  jq '.agreements='"${AGREEMENTS}"'|.node='"${NODE}" "${ADDON_CONFIG_FILE}" > "${ADDON_CONFIG_FILE}.$$"; mv -f "${ADDON_CONFIG_FILE}.$$" "${ADDON_CONFIG_FILE}"

  # report success
  hass.log.info "Configuration for ${HORIZON_DEVICE_NAME} at ${ADDON_CONFIG_FILE}" $(jq -c '.' "${ADDON_CONFIG_FILE}") >&2

  ##
  ## CLOUDANT
  ##

  # URL
  VALUE=$(hass.config.get "cloudant.url")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then hass.log.fatal "No cloudant url"; hass.die; fi
  URL="${VALUE}"
  # USERNAME
  VALUE=$(hass.config.get "cloudant.username")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then hass.log.fatal "No cloudant username"; hass.die; fi
  USERNAME="${VALUE}"
  # PASSWORD
  VALUE=$(hass.config.get "cloudant.password")
  if [[ -z "${VALUE}" || "${VALUE}" == "null" ]]; then hass.log.fatal "No cloudant password"; hass.die; fi
  PASSWORD="${VALUE}"
  # test database access
  hass.log.debug "Testing CLOUDANT with ${USERNAME}:${PASSWORD} at ${URL}"
  OK=$(curl -sL "${URL}" -u "${USERNAME}":"${PASSWORD}" | jq -r '.couchdb')
  if [[ "${OK}" == "null" || -z "${OK}" ]]; then
    hass.log.fatal "Cloudant failed at ${URL} with ${USERNAME} and ${PASSWORD}; exiting"
    hass.die
  fi
  hass.log.debug "CLOUDANT found at ${URL}"

  ## BASE URL
  CLOUDANT_URL="${URL%:*}"'://'"${USERNAME}"':'"${PASSWORD}"'@'"${USERNAME}"."${URL#*.}"
  hass.log.debug "Using CLOUDANT_URL: ${CLOUDANT_URL}"

  ## CONFIGURATION DATABASE
  # find configuration database (or create)
  URL="${CLOUDANT_URL}/${HORIZON_CONFIG_DB}"
  hass.log.debug "Looking for configuration database ${HORIZON_CONFIG_DB} at ${URL}"
  DB=$(curl -sL "${URL}" | jq -r '.db_name')
  if [[ "${DB}" != "${HORIZON_CONFIG_DB}" ]]; then
    hass.log.debug "Creating configuration database ${HORIZON_CONFIG_DB}"
    OK=$(curl -sL -X PUT "${URL}" | jq '.ok')
    if [[ "${OK}" != "true" ]]; then
      hass.log.fatal "Could not create configuration database ${HORIZON_CONFIG_DB}" >&2
      hass.die
    fi 
  fi
  hass.log.info "Configuration database: ${HORIZON_CONFIG_DB}"

  # find configuration entry
  URL="${CLOUDANT_URL}/${HORIZON_CONFIG_DB}/${HORIZON_CONFIG_NAME}"
  hass.log.debug "Looking for configurtion ${HORIZON_CONFIG_NAME} at ${URL}"
  VALUE=$(curl -sL "${URL}")
  hass.log.trace "Received: ${VALUE}"
  FOUND=$(echo "${VALUE}" | jq '._id=="'${HORIZON_CONFIG_NAME}'"') 
  hass.log.trace "Match: ${FOUND}"
  if [[ "${FOUND}" == "true" ]]; then
    HORIZON_CONFIG="${VALUE}"
  else
    hass.log.fatal "Found no configuration ${HORIZON_CONFIG_NAME}"
    hass.die
  fi
  hass.log.debug "Found configuration ${HORIZON_CONFIG_NAME} with ${HORIZON_CONFIG}"
  # make file
  HORIZON_CONFIG_FILE="${CONFIG_PATH%/*}/${HORIZON_CONFIG_NAME}.json"
  echo "${HORIZON_CONFIG}" | jq '.' > "${HORIZON_CONFIG_FILE}"
  if [[ ! -s "${HORIZON_CONFIG_FILE}" ]]; then
    hass.log.fatal "Invalid addon configuration: ${HORIZON_CONFIG}"
    hass.die
  fi
  hass.log.info "Configuration file: ${HORIZON_CONFIG_FILE}"

  ## DEVICE DATABASE
  # find/create device database (or create)
  URL="${CLOUDANT_URL}/${HORIZON_DEVICE_DB}"
  hass.log.debug "Looking for device database ${HORIZON_DEVICE_DB} at ${URL}"
  DB=$(curl -sL "${URL}" | jq -r '.db_name')
  if [[ "${DB}" != "${HORIZON_DEVICE_DB}" ]]; then
    hass.log.debug "Creating device database ${HORIZON_DEVICE_DB}"
    OK=$(curl -sL -X PUT "${URL}" | jq '.ok')
    if [[ "${OK}" != "true" ]]; then
      hass.log.fatal "Could not create device database ${HORIZON_DEVICE_DB}" >&2
      hass.die
    fi 
  fi
  hass.log.info "Device database ${HORIZON_DEVICE_DB} exists"
  # update/create device
  URL="${CLOUDANT_URL}/${HORIZON_DEVICE_DB}/${HORIZON_DEVICE_NAME}"
  hass.log.debug "Looking for device ${HORIZON_DEVICE_NAME} at ${URL}"
  REV=$(curl -sL "${URL}" | jq -r '._rev')
  if [[ "${REV}" != "null" && ! -z "${REV}" ]]; then
    hass.log.debug "Prior device with revision ${REV}"
    URL="${URL}?rev=${REV}"
  fi
  # create/update device 
  hass.log.debug "Updating device ${HORIZON_DEVICE_NAME} with ${ADDON_CONFIG_FILE} at ${URL}"
  OK=$(curl -sL "${URL}" -X PUT -d "@${ADDON_CONFIG_FILE}" | jq '.ok')
  if [[ "${OK}" != "true" ]]; then
    hass.log.fatal "Failed to update device ${HORIZON_DEVICE_NAME} at ${URL}"
    hass.die
  fi
  hass.log.debug "Updated device ${HORIZON_DEVICE_NAME} at ${URL} with " $(jq -c '.' "${ADDON_CONFIG_FILE}")

  ##
  ## YAML
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

  TEMPLATE_DIR="/var/config"
  CONFIG_DIR="/data" # "/config"

  if [[ -d ""${TEMPLATE_DIR}"" ]]; then
    hass.log.trace "Found template directory ${TEMPLATE_DIR}"
    # AUTOMATIONS, GROUPS
    for YAML in automations groups; do
      if [[ -s "${TEMPLATE_DIR}/${YAML}.yaml" ]]; then
        hass.log.trace "Copying ${TEMPLATE_DIR}/${YAML}.yaml into ${CONFIG_DIR}/${YAML}.yaml"
	cp -f "${TEMPLATE_DIR}"/${YAML}.yaml "${CONFIG_DIR}"
        hass.log.trace "Permissions on ${CONFIG_DIR}/${YAML}.yaml are:" $(ls -al "${CONFIG_DIR}/${YAML}.yaml")
      else
	hass.log.debug "Found no ${TEMPLATE_DIR}/${YAML}.yaml"
      fi
    done
    # SECRETS
    YAML="secrets"; if [[ -s "${TEMPLATE_DIR}/${YAML}.yaml" ]]; then
      hass.log.trace "Copying ${TEMPLATE_DIR}/${YAML}.yaml into ${CONFIG_DIR}/${YAML}.yaml"
      cp -f "${TEMPLATE_DIR}"/${YAML}.yaml "${CONFIG_DIR}"
      hass.log.trace "Permissions on ${CONFIG_DIR}/${YAML}.yaml are:" $(ls -al "${CONFIG_DIR}/${YAML}.yaml")
      hass.log.trace "Editting ${CONFIG_DIR}/${YAML}.yaml"
      sed -i \
        -e "s|%%MQTT_USERNAME%%|${MQTT_USERNAME}|g" \
        -e "s|%%MQTT_PASSWORD%%|${MQTT_PASSWORD}|g" \
        -e "s|%%HZN_EXCHANGE_ORG%%|${HORIZON_ORGANIZATION}|g" \
        -e "s|%%HZN_EXCHANGE_URL%%|${HZN_EXCHANGE_URL}|g" \
        -e "s|%%HZN_EXCHANGE_API_KEY%%|${HORIZON_APIKEY}|g" \
        "${CONFIG_DIR}/${YAML}.yaml"
      hass.log.trace "Modified ${CONFIG_DIR}/${YAML}.yaml"
    else
      hass.log.debug "Found no ${TEMPLATE_DIR}/${YAML}.yaml"
    fi
    ## CONFIGURATION
    YAML="configuration"; if [[ -s "${TEMPLATE_DIR}/${YAML}.yaml" ]]; then
      hass.log.trace "Copying ${TEMPLATE_DIR}/${YAML}.yaml into ${CONFIG_DIR}/${YAML}.yaml"
      cp -f "${TEMPLATE_DIR}"/${YAML}.yaml "${CONFIG_DIR}"
      hass.log.trace "Permissions on ${CONFIG_DIR}/${YAML}.yaml are:" $(ls -al "${CONFIG_DIR}/${YAML}.yaml")
      hass.log.trace "Editting ${CONFIG_DIR}/${YAML}.yaml"
      sed -i \
	-e "s|%%HZN_DEVICE_NAME%%|${HORIZON_DEVICE_NAME}|g" \
	-e "s|%%HZN_DEVICE_LATITUDE%%|${LATITUDE}|g" \
	-e "s|%%HZN_DEVICE_LONGITUDE%%|${LONGITUDE}|g" \
	-e "s|%%HZN_DEVICE_ELEVATION%%|${ELEVATION}|g" \
	-e "s|%%MQTT_HOST%%|${MQTT_HOST}|g" \
	-e "s|%%MQTT_PORT%%|${MQTT_PORT}|g" \
	-e "s|%%UNIT_SYSTEM%%|${UNIT_SYSTEM}|g" \
	-e "s|%%TIMEZONE%%|${TIMEZONE}|g" \
	-e "s|%%HOST_IPADDR%%|${HOST_IPADDR}|g" \
        "${CONFIG_DIR}/${YAML}.yaml"
      hass.log.trace "Modified ${CONFIG_DIR}/${YAML}.yaml"
    else
      hass.log.debug "Found no ${TEMPLATE_DIR}/${YAML}.yaml"
    fi 
  else
    hass.log.debug "Found no ${TEMPLATE_DIR}"
  fi

  ##
  ## MQTT PUBLISH
  ##
  hass.log.info "MQTT publish ${ADDON_CONFIG_FILE} to ${MQTT_HOST} topic ${HORIZON_ORGANIZATION}/${HORIZON_DEVICE_NAME}/start"
  mosquitto_pub -r -q 2 -h "${MQTT_HOST}" -p "${MQTT_PORT}" -t "${HORIZON_ORGANIZATION}/${HORIZON_DEVICE_NAME}/start" -f "${ADDON_CONFIG_FILE}"

  ##
  ## RESTART HOMEASSISTANT
  ##
  if [[ -n ${HASSIO_TOKEN:-} ]]; then
    HASSIO_HOST="hassio/homeassistant"
    hass.log.info "Reloading core configuration for ${HASSIO_HOST}"
    curl -sL -H "X-HA-ACCESS: ${HASSIO_TOKEN}" -X POST -H "Content-Type: application/json" "http://${HASSIO_HOST}/api/services/homeassistant/reload_core_config"
  else
    hass.log.warning "Did not issue reload; HASSIO_TOKEN unspecified"
  fi

  ##
  ## INIT-DEVICES
  ##

  REFRESH=$(jq -r '.refresh' "${ADDON_CONFIG_FILE}")
  HOST_LAN=$(jq -r '.host_ipaddr' "${ADDON_CONFIG_FILE}" | sed 's|\(.*\)\.[0-9]*|\1.0/24|')
  SCRIPT="init-devices.sh"
  SCRIPT_URL="https://raw.githubusercontent.com/dcmartin/open-horizon/master/setup/${SCRIPT}"
  BINDIR="/usr/bin"
  EXECPATH="${BINDIR}/${SCRIPT}"
  curl -sL "${SCRIPT_URL}" -o "${EXECPATH}"
  chmod 755 "${EXECPATH}"
  LOG_FILE="${CONFIG_PATH%/*}/${SCRIPT}.$(date +%s).log"

  # check for configuration file
  if [[ ! -s "${HORIZON_CONFIG_FILE}" ]]; then
    hass.log.fatal "Configuration file not found: ${HORIZON_CONFIG_FILE}"
    hass.die
  fi
  # check for executable
  if [[ ! -s "${EXECPATH}" ]]; then
    hass.log.fatal "Executable file not found: ${EXECPATH}"
    hass.die
  else
    hass.log.debug "Executable permissions:" $(ls -al "${EXECPATH}")
  fi

  while [[ NODE=$(hzn node list) ]]; do
    hass.log.debug "Node state: " $(echo "${NODE}" | jq '.configstate.state') "; workloads:" $(hzn agreement list | jq -r '.[]|.workload_to_run.url')

    ## EVALUATE
    hass.log.info $(date) "${EXECPATH} on ${HORIZON_CONFIG_FILE} for ${HOST_LAN}; logging to ${LOG_FILE}"
    bash -- "${EXECPATH}" "${HORIZON_CONFIG_FILE}" "${HOST_LAN}" &> "${LOG_FILE}"

    # update/create configuration
    URL="${CLOUDANT_URL}/${HORIZON_CONFIG_DB}/${HORIZON_CONFIG_NAME}"
    hass.log.debug "Looking for configuration ${HORIZON_CONFIG_NAME} at ${URL}"
    REV=$(curl -sL "${URL}" | jq -r '._rev')
    if [[ "${REV}" != "null" && ! -z "${REV}" ]]; then
      hass.log.debug "Prior configuration with revision ${REV}"
      URL="${URL}?rev=${REV}"
    fi
    # create/update device 
    hass.log.debug "Updating configuration ${HORIZON_CONFIG_NAME} with ${HORIZON_CONFIG_FILE} at ${URL}"
    OK=$(curl -sL "${URL}" -X PUT -d "@${HORIZON_CONFIG_FILE}" | jq '.ok')
    if [[ "${OK}" != "true" ]]; then
      hass.log.warning "Failed to update configuration ${HORIZON_CONFIG_NAME} at ${URL}"
    else
      hass.log.info "Updated configuration ${HORIZON_CONFIG_NAME}"
    fi

    ## SLEEP
    hass.log.debug "Sleeping ${REFRESH}"
    sleep ${REFRESH}
  done

}

main "$@"
