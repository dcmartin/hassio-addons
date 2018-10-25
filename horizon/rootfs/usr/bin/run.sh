#!/usr/bin/with-contenv bash
# ==============================================================================
set -o errexit  # Exit script when a command exits with non-zero status
set -o errtrace # Exit on error inside any functions or sub-shells
set -o nounset  # Exit script on use of an undefined variable
set -o pipefail # Return exit status of the last command in the pipe that failed

# shellcheck disable=SC1091
source /usr/lib/hassio-addons/base.sh

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
main() {

hass.log.trace "${FUNCNAME[0]}"

# START JSON
JSON='{"host":"'"$(hostname)"'","arch":"'"${ARCH}"'","date":'$(/bin/date +%s)

# time zone
VALUE=$(hass.config.get "timezone")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="GMT"; fi
hass.log.info "Setting TIMEZONE ${VALUE}"
cp /usr/share/zoneinfo/${VALUE} /etc/localtime
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

##
## HORIZON 
##

JSON="${JSON}"',"horizon":{"pattern":'"${HZN_PATTERN}"

## OPTIONS that need to be set

# URL
VALUE=$(hass.config.get "horizon.exchange")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal  "No exchange URL"; exit; fi
export HZN_EXCHANGE_URL="${VALUE}"
hass.log.info "Setting HZN_EXCHANGE_URL to ${VALUE}" >&2
JSON="${JSON}"',"exchange":"'"${VALUE}"'"'
# USERNAME
VALUE=$(hass.config.get "horizon.username")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal  "No exchange username"; exit; fi
JSON="${JSON}"',"username":"'"${VALUE}"'"'
# PASSWORD
VALUE=$(hass.config.get "horizon.password")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal  "No exchange password"; exit; fi
JSON="${JSON}"',"password":"'"${VALUE}"'"'
export HZN_EXCHANGE_USER_AUTH="${HZN_EXCHANGE_USER_AUTH}:${VALUE}"
hass.log.info "Setting HZN_EXCHANGE_USER_AUTH ${HZN_EXCHANGE_USER_AUTH}" >&2

# ORGANIZATION
VALUE=$(hass.config.get "horizon.organization")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal  "No horizon organization"; exit; fi
JSON="${JSON}"',"organization":"'"${VALUE}"'"'
# DEVICE
VALUE=$(hass.config.get "horizon.device")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE=$(ip addr | egrep -v NO-CARRIER | egrep -A 1 BROADCAST | egrep -v BROADCAST | sed "s/.*ether \([^ ]*\) .*/\1/g" | sed "s/://g" | head -1)
  VALUE="$(hostname)-${VALUE}"
fi
JSON="${JSON}"',"device":"'"${VALUE}"'"'
hass.log.info  "DEVICE_ID ${VALUE}" >&2
# TOKEN
VALUE=$(hass.config.get "horizon.token")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE==$(echo "${HZN_EXCHANGE_USER_AUTH}" | sed 's/.*://')
fi
JSON="${JSON}"',"token":"'"${VALUE}"'"'
hass.log.info "DEVICE_TOKEN ${VALUE}" >&2

## DONE w/ horizon
JSON="${JSON}"'}'

##
## KAFKA OPTIONS
##

JSON="${JSON}"',"kafka":{"id":"'$(hass.config.get 'kafka.instance_id')'"'
# BROKERS_SASL
VALUE=$(hass.config.get 'kafka.kafka_brokers_sasl')
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka kafka_brokers_sasl"; exit; fi
hass.log.info "Kafka brokers: ${VALUE}"
JSON="${JSON}"',"brokers":'"${VALUE}"
# ADMIN_URL
VALUE=$(hass.config.get 'kafka.kafka_admin_url')
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka kafka_admin_url"; exit; fi
hass.log.info "Kafka admin URL: ${VALUE}"
JSON="${JSON}"',"admin_url":"'"${VALUE}"'"'
# API_KEY
VALUE=$(hass.config.get 'kafka.api_key')
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka api_key"; exit; fi
hass.log.info "Kafka API key: ${VALUE}"
JSON="${JSON}"',"api_key":"'"${VALUE}"'"}'

## DONE w/ kakfa
JSON="${JSON}"'}'

hass.log.info "${JSON}"

###
### REVIEW
###

HZN_PATTERN_ORG=$(echo "$JSON" | jq -r 'horizon.pattern.org?')
HZN_PATTERN_ID=$(echo "$JSON" | jq -r 'horizon.pattern.id?')
HZN_PATTERN_URL=$(echo "$JSON" | jq -r 'horizon.pattern.url?')

KAFKA_BROKER_URL=$(echo "$JSON" | jq -j '.kafka.brokers[]?|.,","')
KAFKA_ADMIN_URL=$(echo "$JSON" | jq -r 'kafka.admin_url?')
KAFKA_API_KEY=$(echo "$JSON" | jq -r 'kafka.api_key?')

DEVICE_ID=$(echo "$JSON" | jq -r 'horizon.device?' )
DEVICE_TOKEN=$(echo "$JSON" | jq -r 'horizon.token?')
DEVICE_ORG=$(echo "$JSON" | jq -r 'horizon.organization?')

hass.log.info "+++ INFO: HORIZON device ${DEVICE_ID} in ${HZN_ORG_ID} using pattern ${HZN_PATTERN_ORG}/${HZN_PATTERN_ID} @ ${HZN_PATTERN_URL}"

###
### CHECK KAKFA
###

KAFKA_TOPIC=$(echo "${DEVICE_ORG}.${HZN_PATTERN_ORG}_${HZN_PATTERN_ID}" | sed 's/@/_/g')

# FIND TOPICS
TOPIC_NAMES=$(curl -fsSL -H "X-Auth-Token: $KAFKA_API_KEY" $KAFKA_ADMIN_URL/admin/topics | jq -j '.[]|.name," "')
for TN in ${TOPIC_NAMES}; do
  if [ ${TN} == "${KAFKA_TOPIC}" ]; then
    FOUND=true
  fi
done
if [ -z ${FOUND} ]; then
  # attempt to create a new topic
  curl -fsSL -H "X-Auth-Token: $KAFKA_API_KEY" -d "{ \"name\": \"$KAFKA_TOPIC\", \"partitions\": 2 }" $KAFKA_ADMIN_URL/admin/topics
else
  hass.log.info "+++ INFO: Topic found: ${KAFKA_TOPIC}"
fi

HZN=$(command -v hzn)
if [ ! -z "${HZN}" ]; then
  hass.log.fatal "Failure to install horizon CLI"
  exit
fi

### REGISTER DEVICE WITH PATTERN

NODE_LIST=$(hzn node list)
if [ -n "${NODE_LIST}" ]; then
  DEVICE_REG=$(echo "${NODE_LIST}" | jq '.id?=="'"${DEVICE_ID}"'"')
fi
if [ "${DEVICE_REG}" == "true" ]; then
    hass.log.info "### ALREADY REGISTERED as ${DEVICE_ID} organization ${DEVICE_ORG}"
else
  INPUT="${KAFKA_TOPIC}.json"
  if [ -s "${INPUT}" ]; then
    hass.log.info "*** WARN: Existing services registration file found: ${INPUT}; deleting"
    rm -f "${INPUT}"
  fi
  echo '{' >> "${INPUT}"
  echo '  "services": [' >> "${INPUT}"
  echo '    {' >> "${INPUT}"
  echo '      "org": "'"${PATTERN_ORG}"'",' >> "${INPUT}"
  echo '      "url": "'"${PATTERN_URL}"'",' >> "${INPUT}"
  echo '      "versionRange": "[0.0.0,INFINITY)",' >> "${INPUT}"
  echo '      "variables": {' >> "${INPUT}"
  echo '        "MSGHUB_API_KEY": "'"${KAFKA_API_KEY}"'"' >> "${INPUT}"
  echo '      }' >> "${INPUT}"
  echo '    }' >> "${INPUT}"
  echo '  ]' >> "${INPUT}"
  echo '}' >> "${INPUT}"

  hass.log.info "### REGISTERING device ${DEVICE_ID} organization ${DEVICE_ORG}) with pattern ${PATTERN_ORG}/${PATTERN_ID} using input " $(jq -c '.' "${INPUT}")
  hzn register -n "${DEVICE_ID}:${DEVICE_TOKEN}" "${DEVICE_ORG}" "${PATTERN_ORG}/${PATTERN_ID}" -f "${INPUT}"
fi

###
### POST REGISTRATION WAITING
###

while [[ $(hzn node list | jq '.id?=="'"${DEVICE_ID}"'"') == false ]]; do hass.log.info "--- WAIT: On registration (60)" $(date); sleep 60; done
hass.log.info "+++ INFO: Registration complete" $(date)

while [[ $(hzn node list | jq '.connectivity."firmware.bluehorizon.network"?==true') == false ]]; do hass.log.info "--- WAIT: On firmware (60)" $(date); sleep 60; done
hass.log.info "+++ INFO: Firmware complete" $(date)

while [[ $(hzn node list | jq '.connectivity."images.bluehorizon.network"?==true') == false ]]; do hass.log.info "--- WAIT: On images (60)" $(date); sleep 60; done
hass.log.info "+++ INFO: Images complete" $(date)

while [[ $(hzn node list | jq '.configstate.state?=="configured"') == false ]]; do hass.log.info "--- WAIT: On configstate (60)" $(date); sleep 60; done
hass.log.info "+++ INFO: Configuration complete" $(date)

while [[ $(hzn node list | jq '.pattern?=="'"${PATTERN_ORG}/${PATTERN_ID}"'"') == false ]]; do hass.log.info "--- WAIT: On pattern (60)" $(date); sleep 60; done
hass.log.info "+++ INFO: Pattern complete" $(date)

while [[ $(hzn node list | jq '.configstate.last_update_time?!=null') == false ]]; do hass.log.info "--- WAIT: On update (60)" $(date); sleep 60; done
hass.log.info "+++ INFO: Update received" $(date)
  
hass.log.info "SUCCESS at $(date) for $(hzn node list | jq -c '.id')"

###
### KAFKACAT
###

while [[ $(hzn node list | jq '.token_valid?!=true') == false ]]; do 
  # wait on kafkacat death and re-start as long as token is valid
  hass.log.info '+++ INFO: Waiting on kafkacat -u -C -q -o end -f "%s\n" -b '$KAFKA_BROKER_URL' -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username='${KAFKA_API_KEY:0:16}'" -X "sasl.password='${KAFKA_API_KEY:16}'" -t "'$KAFKA_TOPIC'" | jq .'
  kafkacat -u -C -q -o end -f "%s\n" -b $KAFKA_BROKER_URL -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username=${KAFKA_API_KEY:0:16}" -X "sasl.password=${KAFKA_API_KEY:16}" -t "$KAFKA_TOPIC" | mosquitto_pub -l -h "core-mosquitto" -t "kafka/${KAFKA_TOPIC}"
done

}

main "$@"

