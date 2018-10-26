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

# Specify the hardware architecture of this Edge Node

ARCH=$(arch)
if [ -z "${ARCH}" ]; then
  hass.log.fatal "No architecture detected; exiting"
  exit
fi

if [ "${ARCH}" == "aarch64" ]; then
  ARCH="arm64"
elif [ "${ARCH}" == "x86_64" ]; then
  ARCH="amd64"
elif [ "${ARCH}" == "armv71" ]; then
  ARCH="arm"
else
  hass.log.fatal "Cannot automagically identify architecture (${ARCH}); options are: arm, arm64, amd64, ppc64el"
  exit
fi

hass.log.info "Using architecture: ${ARCH}"

###
### A HOST at DATE on ARCH
###

JSON='{"host":"'"$(hostname)"'","arch":"'"${ARCH}"'","date":'$(/bin/date +%s)
# time zone
VALUE=$(hass.config.get "timezone")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="GMT"; fi
hass.log.debug "Setting TIMEZONE ${VALUE}" >&2
cp /usr/share/zoneinfo/${VALUE} /etc/localtime
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

##
## HORIZON 
##

# START JSON

JSON="${JSON}"',"horizon":{"pattern":'"${HORIZON_PATTERN}"

## OPTIONS that need to be set

# URL
VALUE=$(hass.config.get "horizon.exchange")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No exchange URL"; exit; fi
export HZN_EXCHANGE_URL="${VALUE}"
hass.log.info "Setting HZN_EXCHANGE_URL to ${VALUE}" >&2
JSON="${JSON}"',"exchange":"'"${VALUE}"'"'
# USERNAME
VALUE=$(hass.config.get "horizon.username")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No exchange username"; exit; fi
JSON="${JSON}"',"username":"'"${VALUE}"'"'
HZN_EXCHANGE_USER_AUTH="${VALUE}"
# PASSWORD
VALUE=$(hass.config.get "horizon.password")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No exchange password"; exit; fi
JSON="${JSON}"',"password":"'"${VALUE}"'"'
export HZN_EXCHANGE_USER_AUTH="${HZN_EXCHANGE_USER_AUTH}:${VALUE}"
hass.log.info "Setting HZN_EXCHANGE_USER_AUTH ${HZN_EXCHANGE_USER_AUTH}" >&2

# ORGANIZATION
VALUE=$(hass.config.get "horizon.organization")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No horizon organization"; exit; fi
JSON="${JSON}"',"organization":"'"${VALUE}"'"'
# DEVICE
VALUE=$(hass.config.get "horizon.device")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE=$(ip addr | egrep -v NO-CARRIER | egrep -A 1 BROADCAST | egrep -v BROADCAST | sed "s/.*ether \([^ ]*\) .*/\1/g" | sed "s/://g" | head -1)
  VALUE="$(hostname)-${VALUE}"
fi
JSON="${JSON}"',"device":"'"${VALUE}"'"'
hass.log.info "DEVICE_ID ${VALUE}" >&2
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

JSON="${JSON}"',"kafka":{"id":"'$(jq -r '.kafka.instance_id' "/data/options.json")'"'
# BROKERS_SASL
VALUE=$(jq -r '.kafka.kafka_brokers_sasl' "/data/options.json")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.kafka_brokers_sasl"; exit; fi
hass.log.info "Kafka brokers: ${VALUE}"
JSON="${JSON}"',"brokers":'"${VALUE}"
# ADMIN_URL
VALUE=$(hass.config.get "kafka.kafka_admin_url")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.kafka_admin_url"; exit; fi
hass.log.info "Kafka admin URL: ${VALUE}"
JSON="${JSON}"',"admin_url":"'"${VALUE}"'"'
# API_KEY
VALUE=$(hass.config.get "kafka.api_key")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.api_key"; exit; fi
hass.log.info "Kafka API key: ${VALUE}"
JSON="${JSON}"',"api_key":"'"${VALUE}"'"}'

## DONE w/ kakfa
JSON="${JSON}"'}'

hass.log.debug "${JSON}"

###
### REVIEW
###

PATTERN_ORG=$(echo "$JSON" | jq -r '.horizon.pattern.org?')
PATTERN_ID=$(echo "$JSON" | jq -r '.horizon.pattern.id?')
PATTERN_URL=$(echo "$JSON" | jq -r '.horizon.pattern.url?')

KAFKA_BROKER_URL=$(echo "$JSON" | jq -j '.kafka.brokers[]?|.,","')
KAFKA_ADMIN_URL=$(echo "$JSON" | jq -r '.kafka.admin_url?')
KAFKA_API_KEY=$(echo "$JSON" | jq -r '.kafka.api_key?')

DEVICE_ID=$(echo "$JSON" | jq -r '.horizon.device?' )
DEVICE_TOKEN=$(echo "$JSON" | jq -r '.horizon.token?')
DEVICE_ORG=$(echo "$JSON" | jq -r '.horizon.organization?')

hass.log.info "HORIZON device ${DEVICE_ID} in ${DEVICE_ORG} using pattern ${PATTERN_ORG}/${PATTERN_ID} @ ${PATTERN_URL}"

###
### CHECK KAKFA
###

KAFKA_TOPIC=$(echo "${DEVICE_ORG}.${PATTERN_ORG}_${PATTERN_ID}" | sed 's/@/_/g')

# FIND TOPICS
TOPIC_NAMES=$(curl -fsSL -H "X-Auth-Token: $KAFKA_API_KEY" $KAFKA_ADMIN_URL/admin/topics | jq -j '.[]|.name," "')
hass.log.info "Topics availble: ${TOPIC_NAMES}"
for TN in ${TOPIC_NAMES}; do
  if [ ${TN} == "${KAFKA_TOPIC}" ]; then
    FOUND=true
  fi
done
if [ -z ${FOUND} ]; then
  # attempt to create a new topic
  curl -fsSL -H "X-Auth-Token: $KAFKA_API_KEY" -d "{ \"name\": \"$KAFKA_TOPIC\", \"partitions\": 2 }" $KAFKA_ADMIN_URL/admin/topics
else
  hass.log.info "Topic found: ${KAFKA_TOPIC}"
fi

HZN=$(command -v hzn)
if [ -z "${HZN}" ]; then
  hass.log.fatal "Failure to install horizon CLI"
  exit
fi

### REGISTER DEVICE WITH PATTERN

NODE_LIST=$(hzn node list)
if [ -n "${NODE_LIST}" ]; then
  DEVICE_REG=$(echo "${NODE_LIST}" | jq '.id?=="'"${DEVICE_ID}"'"')
fi
if [ "${DEVICE_REG}" == "true" ]; then
  hass.log.notice "ALREADY REGISTERED as ${DEVICE_ID} organization ${DEVICE_ORG}" $(echo "${NODE_LIST}" | jq -c '.')
else
  INPUT="${KAFKA_TOPIC}.json"
  if [ -s "${INPUT}" ]; then
    hass.log.warning "Existing services registration file found: ${INPUT}; deleting"
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

  hass.log.info "REGISTERING device ${DEVICE_ID} organization ${DEVICE_ORG} with pattern ${PATTERN_ORG}/${PATTERN_ID} using input " $(jq -c '.' "${INPUT}")
  hzn register -n "${DEVICE_ID}:${DEVICE_TOKEN}" "${DEVICE_ORG}" "${PATTERN_ORG}/${PATTERN_ID}" -f "${INPUT}"

  while [[ $(hzn node list | jq '.id?=="'"${DEVICE_ID}"'"') == false ]]; do hass.log.info "--- WAIT: On registration (60)"; sleep 60; done
  hass.log.info "Registration complete" $(date)
  while [[ $(hzn node list | jq '.pattern?=="'"${PATTERN_ORG}/${PATTERN_ID}"'"') == false ]]; do hass.log.info "--- WAIT: On pattern (60)"; sleep 60; done
  hass.log.info "Pattern complete" $(date)

fi

#
# SAMPLE AGREEEMENT
# [
#   {
#     "name": "Policy for service-cpu merged with Policy for service-gps merged with cpu2msghub_github.com-open-horizon-examples-wiki-service-cpu2msghub_IBM_amd64",
#     "current_agreement_id": "7079621a2e80f579b4a29b654f781783b1339f7f8e65947afd7575b8dc5aef01",
#     "consumer_id": "IBM/stg-edge-cluster.us-south.containers.appdomain.cloud",
#     "agreement_creation_time": "2018-10-26 08:57:13 -0700 PDT",
#     "agreement_accepted_time": "2018-10-26 08:57:22 -0700 PDT",
#     "agreement_finalized_time": "2018-10-26 08:57:26 -0700 PDT",
#     "agreement_execution_start_time": "2018-10-26 08:57:37 -0700 PDT",
#     "agreement_data_received_time": "",
#     "agreement_protocol": "Basic",
#     "workload_to_run": {
#       "url": "https://github.com/open-horizon/examples/wiki/service-cpu2msghub",
#       "org": "IBM",
#       "version": "1.2.5",
#       "arch": "amd64"
#     }
#   }
# ]

## WAIT ON AGREEMENT
while [[ $(hzn agreement list | jq '.?==[]') == true ]]; do hass.log.info "--- WAIT: On agreement (10)"; sleep 10; done

###
### KAFKACAT
###

MQTT_HOST="192.168.1.40"
MQTT_PORT=1883

HAL=$(hzn agreement list | jq -r '.[]|.workload_to_run.url')
if [ $HAL == "${PATTERN_URL}" ]; then
  hass.log.info "Agreement pattern ${PATTERN_URL}" $(date)
  # wait on kafkacat death and re-start as long as token is valid
  hass.log.info "Routing KAFKA to MQTT topic kafka/${KAFKA_TOPIC} at host ${MQTT_HOST} on port ${MQTT_PORT}"
  echo 'kafkacat -u -C -q -o end -f "%s\n" -b '$KAFKA_BROKER_URL' -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username='${KAFKA_API_KEY:0:16}'" -X "sasl.password='${KAFKA_API_KEY:16}'" -t "'$KAFKA_TOPIC'"'
  kafkacat -u -C -q -o end -f "%s\n" -b $KAFKA_BROKER_URL -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username=${KAFKA_API_KEY:0:16}" -X "sasl.password=${KAFKA_API_KEY:16}" -t "$KAFKA_TOPIC" | mosquitto_pub -l -h "${MQTT_HOST}" -p ${MQTT_PORT} -t "kafka/${KAFKA_TOPIC}"
else
  hass.log.fatal "Unable to find agreement for ${PATTERN_URL}"
  exit
fi

}

main "$@"

