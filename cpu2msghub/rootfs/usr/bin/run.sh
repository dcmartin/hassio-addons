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

hass.log.debug "Using architecture: ${ARCH}"

###
### A HOST at DATE on ARCH
###

# START JSON
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

JSON="${JSON}"',"horizon":{"pattern":'"${HORIZON_PATTERN}"

## OPTIONS that need to be set

# URL
VALUE=$(hass.config.get "horizon.exchange")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No exchange URL"; exit; fi
export HZN_EXCHANGE_URL="${VALUE}"
hass.log.debug "Setting HZN_EXCHANGE_URL to ${VALUE}" >&2
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
hass.log.debug "Setting HZN_EXCHANGE_USER_AUTH ${HZN_EXCHANGE_USER_AUTH}" >&2

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
hass.log.debug "DEVICE_ID ${VALUE}" >&2
# TOKEN
VALUE=$(hass.config.get "horizon.token")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE==$(echo "${HZN_EXCHANGE_USER_AUTH}" | sed 's/.*://')
fi
JSON="${JSON}"',"token":"'"${VALUE}"'"'
hass.log.debug "DEVICE_TOKEN ${VALUE}" >&2

## DONE w/ horizon
JSON="${JSON}"'}'

##
## KAFKA OPTIONS
##

if [[ $(hass.config.has_value 'kafka') == false ]]; then
  hass.log.fatal "No Kafka credentials"
  exit
fi

JSON="${JSON}"',"kafka":{"id":"'$(hass.config.get 'kafka.instance_id')'"'
# BROKERS_SASL
VALUE=$(jq -r '.kafka.kafka_brokers_sasl' "/data/options.json")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.kafka_brokers_sasl"; exit; fi
hass.log.debug "Kafka brokers: ${VALUE}"
JSON="${JSON}"',"brokers":'"${VALUE}"
# ADMIN_URL
VALUE=$(hass.config.get "kafka.kafka_admin_url")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.kafka_admin_url"; exit; fi
hass.log.debug "Kafka admin URL: ${VALUE}"
JSON="${JSON}"',"admin_url":"'"${VALUE}"'"'
# API_KEY
VALUE=$(hass.config.get "kafka.api_key")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.api_key"; exit; fi
hass.log.debug "Kafka API key: ${VALUE}"
JSON="${JSON}"',"api_key":"'"${VALUE}"'"}'

## DONE w/ JSON
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

hass.log.debug "HORIZON device ${DEVICE_ID} in ${DEVICE_ORG} using pattern ${PATTERN_ORG}/${PATTERN_ID} @ ${PATTERN_URL}"

###
### CHECK KAKFA
###

KAFKA_TOPIC=$(echo "${DEVICE_ORG}.${PATTERN_ORG}_${PATTERN_ID}" | sed 's/@/_/g')

# FIND TOPICS
TOPIC_NAMES=$(curl -sL -H "X-Auth-Token: $KAFKA_API_KEY" $KAFKA_ADMIN_URL/admin/topics | jq -j '.[]|.name," "')
if [ $? != 0 ]; then hass.log.fatal "Unable to retrieve Kafka topics; exiting"; exit; fi
hass.log.debug "Topics availble: ${TOPIC_NAMES}"
TOPIC_FOUND=""
for TN in ${TOPIC_NAMES}; do
  if [ ${TN} == "${KAFKA_TOPIC}" ]; then
    TOPIC_FOUND=true
  fi
done
if [ -z "${TOPIC_FOUND}" ]; then
  hass.log.info "Topic ${KAFKA_TOPIC} not found; exiting"
  exit
  hass.log.debug "Creating topic ${KAFKA_TOPIC} at ${KAFKA_ADMIN_URL} using /admin/topics"
  curl -sL -H "X-Auth-Token: $KAFKA_API_KEY" -d "{ \"name\": \"$KAFKA_TOPIC\", \"partitions\": 2 }" $KAFKA_ADMIN_URL/admin/topics
  if [ $? != 0 ]; then hass.log.fatal "Unable to create Kafka topic ${KAFKA_TOPIC}; exiting"; exit; fi
else
  hass.log.debug "Topic found: ${KAFKA_TOPIC}"
fi

HZN=$(command -v hzn)
if [ -z "${HZN}" ]; then
  hass.log.fatal "Failure to install horizon CLI"
  exit
fi

###
### CONFIGURE HORIZON
###

# check for outstanding agreements
AGREEMENTS=$(hzn agreement list)
COUNT=$(echo "${AGREEMENTS}" | jq '.?|length')
hass.log.debug "Found ${COUNT} agreements"
WORKLOAD_FOUND=""
if [[ ${COUNT} > 0 ]]; then
  WORKLOADS=$(echo "${AGREEMENTS}" | jq -r '.[]|.workload_to_run.url')
  for WL in ${WORKLOADS}; do
    if [ "${WL}" == "${PATTERN_URL}" ]; then
      WORKLOAD_FOUND=true
    fi
  done
fi

if [[ $COUNT > 0 && $(hzn node list | jq '.id?=="'"${DEVICE_ID}"'"') == false ]]; then
  hass.log.info "Existing agreeement with another device identifier; unregistering"
  hzn unregister -f
  while [[ $(hzn node list | jq '.configstate.state?=="unconfigured"') == false ]]; do hass.log.debug "Waiting for unregistration to complete (10)"; sleep 10; done
  # hass.log.debug "Waiting for unregistration to complete; sleeping (30)"
  # sleep 30
  COUNT=0
  AGREEMENTS=""
  WORKLOAD_FOUND=""
  hass.log.debug "Reseting agreements, count, and workloads"
fi

# if agreement not found, register device with pattern
if [[ ${COUNT} == 0 && -z ${WORKLOAD_FOUND} ]]; then
  INPUT="${KAFKA_TOPIC}.json"

  echo '{"services": [{"org": "'"${PATTERN_ORG}"'","url": "'"${PATTERN_URL}"'","versionRange": "[0.0.0,INFINITY)","variables": {' >> "${INPUT}"
  echo '"MSGHUB_API_KEY": "'"${KAFKA_API_KEY}"'"' >> "${INPUT}"
  echo '}}]}' >> "${INPUT}"

  hass.log.debug "Registering device ${DEVICE_ID} organization ${DEVICE_ORG} with pattern ${PATTERN_ORG}/${PATTERN_ID} using input " $(jq -c '.' "${INPUT}")

  # register
  hzn register -n "${DEVICE_ID}:${DEVICE_TOKEN}" "${DEVICE_ORG}" "${PATTERN_ORG}/${PATTERN_ID}" -f "${INPUT}"
  # wait for registration
  while [[ $(hzn node list | jq '.id?=="'"${DEVICE_ID}"'"') == false ]]; do hass.log.debug "Waiting on registration (60)"; sleep 60; done
  hass.log.debug "Registration complete for ${DEVICE_ORG}/${DEVICE_ID}"
  # wait for agreement
  while [[ $(hzn agreement list | jq '.?==[]') == true ]]; do hass.log.info "Waiting on agreement (10)"; sleep 10; done
  hass.log.debug "Agreement complete for ${PATTERN_URL}"
elif [ -n ${WORKLOAD_FOUND} ]; then
  hass.log.debug "Found pattern in existing agreement: ${PATTERN_URL}"
elif [[ ${COUNT} > 0 ]]; then
  hass.log.fatal "Existing non-matching pattern agreement found; exiting: ${AGREEMENTS}"
  exit
else
  hass.log.fatal "Invalid state; exiting"
  exit
fi

hass.log.info "Device ${DEVICE_ID} in ${DEVICE_ORG} registered for pattern ${PATTERN_ID} from ${PATTERN_ORG}"

###
### ADD ON LOGIC
###

# configuration for MQTT transfer
MQTT_HOST=$(hass.config.get "mqtt.host")
MQTT_PORT=$(hass.config.get "mqtt.port")
MQTT_USERNAME=$(hass.config.get "mqtt.username")
MQTT_PASSWORD=$(hass.config.get "mqtt.password")
MQTT_TOPIC="kafka/${KAFKA_TOPIC}"
# specify MQTT command
MQTT="mosquitto_pub -l -h ${MQTT_HOST} -p ${MQTT_PORT} -t ${MQTT_TOPIC}"
if [[ -n "${MQTT_USERNAME}" && -n "${MQTT_PASSWORD}" ]]; then
  MQTT="${MQTT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD}"
fi

# configuration for JQ tranformation
JQ='{"name":.nodeID,"altitude":.gps.alt,"longitude":.gps.lon,"latitude":.gps.lat,"cpu":.cpu}'

# wait on kafkacat death and re-start as long as token is valid
while [[ $(hzn agreement list | jq -r '.[]|.workload_to_run.url') == "${PATTERN_URL}" ]]; do
  hass.log.info "Starting main loop; routing ${KAFKA_TOPIC} to ${MQTT_TOPIC} at host ${MQTT_HOST} on port ${MQTT_PORT}"

  kafkacat -u -C -q -o end -f "%s\n" -b $KAFKA_BROKER_URL -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username=${KAFKA_API_KEY:0:16}" -X "sasl.password=${KAFKA_API_KEY:16}" -t "$KAFKA_TOPIC" \
    | while read -r; do
      echo "${REPLY}" \
        | jq --unbuffered -c "${JQ}" \
        | jq --unbuffered -c ".date="$(date '+%s') \
        | ${MQTT}
      done

  hass.log.debug "Unexpected failure of kafkacat"
done

hass.log.fatal "Workload no longer valid"

}

main "$@"
