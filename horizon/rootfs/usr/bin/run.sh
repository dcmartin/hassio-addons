#!/usr/bin/with-contenv bash
# ==============================================================================
set -o nounset  # Exit script on use of an undefined variable
set -o pipefail # Return exit status of the last command in the pipe that failed
# set -o errexit  # Exit script when a command exits with non-zero status
# set -o errtrace # Exit on error inside any functions or sub-shells

# shellcheck disable=SC1091
source /usr/lib/hassio-addons/base.sh

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
main() {
  hass.log.trace "${FUNCNAME[0]}"

  ###
  ### A HOST at DATE on ARCH
  ###

  # START JSON
  JSON='{"hostname":"'"$(hostname)"'","arch":"'"$(arch)"'","date":'$(/bin/date +%s)
  # time zone
  VALUE=$(hass.config.get "timezone")
  # Set the correct timezone
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="GMT"; fi
  hass.log.info "Setting TIMEZONE ${VALUE}" >&2
  cp /usr/share/zoneinfo/${VALUE} /etc/localtime
  JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

  ###
  ### HORIZON 
  ###

  # credentials
  VALUE=$(hass.config.get "exchange.url")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No exchange url"; hass.die; fi
  export HZN_EXCHANGE_URL="${VALUE}"
  VALUE=$(hass.config.get "exchange.username")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No exchange username"; hass.die; fi
  HZN_EXCHANGE_USER_AUTH="${VALUE}"
  VALUE=$(hass.config.get "exchange.password")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No exchange password"; hass.die; fi
  export HZN_EXCHANGE_USER_AUTH="${HZN_EXCHANGE_USER_AUTH}:${VALUE}"

  ## EXCHANGE

  # URL
  JSON="${JSON}"',"exchange":{"url":"'"${HZN_EXCHANGE_URL}"'"'
  # ORGANIZATION
  VALUE=$(hass.config.get "exchange.organization")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No horizon organization"; hass.die; fi
  JSON="${JSON}"',"organization":"'"${VALUE}"'"'
  # DEVICE
  VALUE=$(hass.config.get "horizon.device")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
    VALUE=($(hostname -I | sed 's/\.//g'))
    VALUE="$(hostname)-${VALUE}"
  fi
  JSON="${JSON}"',"device":"'"${VALUE}"'"'
  # TOKEN
  VALUE=$(hass.config.get "horizon.token")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
    VALUE=$(echo "${HZN_EXCHANGE_USER_AUTH}" | sed 's/.*://')
  fi
  JSON="${JSON}"',"token":"'"${VALUE}"'"'
  ## done w/ exchange
  JSON="${JSON}"'}'

  ## PATTERN

  # ID
  VALUE=$(hass.config.get "pattern.id")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No pattern id"; hass.die; fi
  JSON="${JSON}"',"pattern":{"id":"'"${VALUE}"'"'
  VALUE=$(hass.config.get "pattern.org")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No pattern org"; hass.die; fi
  JSON="${JSON}"',"organization":"'"${VALUE}"'"'
  VALUE=$(hass.config.get "pattern.url")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No pattern org"; hass.die; fi
  JSON="${JSON}"',"url":"'"${VALUE}"'"'
  # variables special case
  VALUE=$(jq -r '.pattern.variables' "${CONFIG_PATH}")
  JSON="${JSON}"',"variables":'"${VALUE}"
  JSON="${JSON}"'}'

  ## DONE w/ JSON
  JSON="${JSON}"'}'

  hass.log.debug "CONFIGURATION:" $(echo "${JSON}" | jq -c '.')

  ###
  ### REVIEW
  ###

  PATTERN_ORG=$(echo "${JSON}" | jq -r '.pattern.org?')
  PATTERN_ID=$(echo "${JSON}" | jq -r '.pattern.id?')
  PATTERN_URL=$(echo "${JSON}" | jq -r '.pattern.url?')
  PATTERN_VARS=$(echo "${JSON}" | jq -r '.pattern.variables?')
  EXCHANGE_ID=$(echo "$JSON" | jq -r '.exchange.device?' )
  EXCHANGE_TOKEN=$(echo "$JSON" | jq -r '.exchange.token?')
  EXCHANGE_ORG=$(echo "$JSON" | jq -r '.exchange.organization?')

  # check for outstanding agreements
  AGREEMENTS=$(hzn agreement list)
  COUNT=$(echo "${AGREEMENTS}" | jq '.?|length')
  hass.log.debug "Found ${COUNT} agreements"
  PATTERN_FOUND=""
  if [[ ${COUNT} > 0 ]]; then
    WORKLOADS=$(echo "${AGREEMENTS}" | jq -r '.[]|.workload_to_run.url')
    for WL in ${WORKLOADS}; do
      if [ "${WL}" == "${PATTERN_URL}" ]; then
	PATTERN_FOUND=true
      fi
    done
  fi

  # get node status from horizon
  NODE=$(hzn node list)
  EXCHANGE_FOUND=$(echo "${NODE}" | jq '.id?=="'"${EXCHANGE_ID}"'"')
  EXCHANGE_CONFIGURED=$(echo "${NODE}" | jq '.configstate.state?=="configured"')
  EXCHANGE_UNCONFIGURED=$(echo "${NODE}" | jq '.configstate.state?=="unconfigured"')

  # test conditions
  if [[ ${PATTERN_FOUND} == true && ${EXCHANGE_FOUND} == true && ${EXCHANGE_CONFIGURED} == true ]]; then
    hass.log.info "Device ${EXCHANGE_ID} found with pattern ${PATTERN_URL} in a configured state; skipping registration"
  else
    # unregister if currently registered
    if [[ ${EXCHANGE_UNCONFIGURED} != true ]]; then
      hass.log.debug "Device ${EXCHANGE_ID} not configured for pattern ${PATTERN_URL}; unregistering..."
      hzn unregister -f
      while [[ $(hzn node list | jq '.configstate.state?=="unconfigured"') == false ]]; do hass.log.debug "Waiting for unregistration to complete (10)"; sleep 10; done
      COUNT=0
      AGREEMENTS=""
      PATTERN_FOUND=""
      hass.log.debug "Reseting agreements, count, and workloads"
    fi

    # perform registration
    INPUT=$(mktemp)
    echo '{"services": [{"org": "'"${PATTERN_ORG}"'","url": "'"${PATTERN_URL}"'","versionRange": "[0.0.0,INFINITY)","variables": {' >> "${INPUT}"
    PVS=$(echo "${PATTERN_VARS}" | jq -r '.[].env')
    for PV in ${PVS}; do
      VALUE=$(echo "${PATTERN_VARS}" | jq -r '.[]|select(.env="'"${PV}"'").value')
      echo '"'"${PV}"':"'"${VALUE}"'"' >> "${INPUT}"
      hass.log.trace'{"env":"'"${PV}"'","value":"'"${VALUE}"'"}'
    done
    echo '}}]}' >> "${INPUT}"

    hass.log.debug "Registering device ${EXCHANGE_ID} organization ${EXCHANGE_ORG} with pattern ${PATTERN_ORG}/${PATTERN_ID} using input " $(jq -c '.' "${INPUT}")

    # register
    hzn register -n "${EXCHANGE_ID}:${EXCHANGE_TOKEN}" "${EXCHANGE_ORG}" "${PATTERN_ORG}/${PATTERN_ID}" -f "${INPUT}"
    # wait for registration
    while [[ $(hzn node list | jq '.id?=="'"${EXCHANGE_ID}"'"') == false ]]; do hass.log.debug "Waiting on registration (60)"; sleep 60; done
    hass.log.debug "Registration complete for ${EXCHANGE_ORG}/${EXCHANGE_ID}"
    # wait for agreement
    while [[ $(hzn agreement list | jq '.?==[]') == true ]]; do hass.log.info "Waiting on agreement (10)"; sleep 10; done
    hass.log.debug "Agreement complete for ${PATTERN_URL}"
  fi

  # wait on termination
  while [[ NODE=$(hzn node list) \
    && EXCHANGE_FOUND=$(echo "${NODE}" | jq '.id?=="'"${EXCHANGE_ID}"'"') \
    && EXCHANGE_CONFIGURED=$(echo "${NODE}" | jq '.configstate.state?=="configured"') \
    && AGREEMENTS=$(hzn agreement list) ]]; do

    # check if all still okay
    PATTERN_FOUND=""
    WORKLOADS=$(echo "${AGREEMENTS}" | jq -r '.[]|.workload_to_run.url')
    for WL in ${WORKLOADS}; do
      if [ "${WL}" == "${PATTERN_URL}" ]; then
        PATTERN_FOUND=true
      fi
    done
    if [ -n ${PATTERN_FOUND} ]; then
      hass.log.info $(date) "${EXCHANGE_ID} pattern ${PATTERN_URL}; sleeping 30 ..."
      sleep 30
    else
      hass.log.info $(date) "NO PATTERN: NODE" $(echo "$NODE" | jq -c '.') "AGREEMENTS" $(echo "$AGREEMENTS" | jq -c '.')
      hass.die
    fi
  done
  hass.log.fatal "FAILURE: NODE" $(echo "$NODE" | jq -c '.') "AGREEMENTS" $(echo "$AGREEMENTS" | jq -c '.')
  hass.die
}

main "$@"
