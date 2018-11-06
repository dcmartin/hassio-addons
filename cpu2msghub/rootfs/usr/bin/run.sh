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
JSON='{"host":"'"$(hostname)"'","arch":"'"$(arch)"'","date":'$(/bin/date +%s)
# time zone
VALUE=$(hass.config.get "timezone")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="GMT"; fi
hass.log.info "Setting TIMEZONE ${VALUE}" >&2
cp /usr/share/zoneinfo/${VALUE} /etc/localtime
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

##
## HORIZON 
##

JSON="${JSON}"',"horizon":{"pattern":'"${HORIZON_PATTERN}"

###
### TURN on/off listen only mode
###
VALUE=$(hass.config.get "listen")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="true"; fi
hass.log.debug "Listen mode: ${VALUE}"
LISTEN_MODE=${VALUE}

## HORIZON EXCHANGE

# URL
VALUE=$(hass.config.get "horizon.exchange")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.warning "No exchange URL"; VALUE="null"; fi
export HZN_EXCHANGE_URL="${VALUE}"
hass.log.debug "Setting HZN_EXCHANGE_URL to ${VALUE}" >&2
JSON="${JSON}"',"exchange":"'"${VALUE}"'"'
# USERNAME
VALUE=$(hass.config.get "horizon.username")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.warning "No exchange username"; VALUE="null"; fi
JSON="${JSON}"',"username":"'"${VALUE}"'"'
HZN_EXCHANGE_USER_AUTH="${VALUE}"
# PASSWORD
VALUE=$(hass.config.get "horizon.password")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.warning "No exchange password"; VALUE="null"; fi
JSON="${JSON}"',"password":"'"${VALUE}"'"'
export HZN_EXCHANGE_USER_AUTH="${HZN_EXCHANGE_USER_AUTH}:${VALUE}"
hass.log.trace "Setting HZN_EXCHANGE_USER_AUTH ${HZN_EXCHANGE_USER_AUTH}" >&2
# ORGANIZATION
VALUE=$(hass.config.get "horizon.organization")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.warning "No horizon organization"; VALUE="null"; fi
JSON="${JSON}"',"organization":"'"${VALUE}"'"'
# DEVICE
VALUE=$(hass.config.get "horizon.device")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE=$(ip addr | egrep -v NO-CARRIER | egrep -A 1 BROADCAST | egrep -v BROADCAST | sed "s/.*ether \([^ ]*\) .*/\1/g" | sed "s/://g" | head -1)
  VALUE="$(hostname)-${VALUE}"
fi
JSON="${JSON}"',"device":"'"${VALUE}"'"'
hass.log.debug "EXCHANGE_ID ${VALUE}" >&2
# TOKEN
VALUE=$(hass.config.get "horizon.token")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE==$(echo "${HZN_EXCHANGE_USER_AUTH}" | sed 's/.*://')
fi
JSON="${JSON}"',"token":"'"${VALUE}"'"'
hass.log.debug "EXCHANGE_TOKEN ${VALUE}" >&2

## DONE w/ horizon
JSON="${JSON}"'}'

##
## KAFKA OPTIONS
##

JSON="${JSON}"',"kafka":{"id":"'$(hass.config.get 'kafka.instance_id')'"'
# BROKERS_SASL
VALUE=$(jq -r '.kafka.kafka_brokers_sasl' "/data/options.json")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.kafka_brokers_sasl"; hass.die; fi
hass.log.debug "Kafka brokers: ${VALUE}"
JSON="${JSON}"',"brokers":'"${VALUE}"
# ADMIN_URL
VALUE=$(hass.config.get "kafka.kafka_admin_url")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.kafka_admin_url"; hass.die; fi
hass.log.debug "Kafka admin URL: ${VALUE}"
JSON="${JSON}"',"admin_url":"'"${VALUE}"'"'
# API_KEY
VALUE=$(hass.config.get "kafka.api_key")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.api_key"; hass.die; fi
hass.log.debug "Kafka API key: ${VALUE}"
JSON="${JSON}"',"api_key":"'"${VALUE}"'"'

## DONE w/ kafka
JSON="${JSON}"'}'

## DONE w/ JSON
JSON="${JSON}"'}'

hass.log.debug "CONFIGURATION:" $(echo "${JSON}" | jq -c '.')

###
### REVIEW
###

PATTERN_ORG=$(echo "$JSON" | jq -r '.horizon.pattern.org?')
PATTERN_ID=$(echo "$JSON" | jq -r '.horizon.pattern.id?')
PATTERN_URL=$(echo "$JSON" | jq -r '.horizon.pattern.url?')

KAFKA_BROKER_URL=$(echo "$JSON" | jq -j '.kafka.brokers[]?|.,","')
KAFKA_ADMIN_URL=$(echo "$JSON" | jq -r '.kafka.admin_url?')
KAFKA_API_KEY=$(echo "$JSON" | jq -r '.kafka.api_key?')

EXCHANGE_ID=$(echo "$JSON" | jq -r '.horizon.device?' )
EXCHANGE_TOKEN=$(echo "$JSON" | jq -r '.horizon.token?')
EXCHANGE_ORG=$(echo "$JSON" | jq -r '.horizon.organization?')

# KAFKA TOPIC
KAFKA_TOPIC=$(echo "${EXCHANGE_ORG}.${PATTERN_ORG}_${PATTERN_ID}" | sed 's/@/_/g')

## MQTT

VALUE=$(hass.config.get "mqtt.host")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="core-mosquitto"; fi
hass.log.debug "MQTT host: ${VALUE}"
MQTT_HOST=${VALUE}

VALUE=$(hass.config.get "mqtt.port")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="1883"; fi
hass.log.debug "MQTT port: ${VALUE}"
MQTT_PORT=${VALUE}

VALUE=$(hass.config.get "mqtt.topic")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="kafka/${KAFKA_TOPIC}"; fi
hass.log.debug "MQTT topic: ${VALUE}"
MQTT_TOPIC=${VALUE}

# set command
MQTT="mosquitto_pub -h ${MQTT_HOST} -p ${MQTT_PORT}"
# test if username and password supplied
if [[ $(hass.config.exists "mqtt.username") && $(hass.config.exists "mqtt.password") ]]; then
  # update command
  MQTT="${MQTT} -u $(hass.config.get 'mqtt.username') -P (hass.config.get 'mqtt.password')"
fi

###
### CHECK KAFKA
###

# FIND TOPICS
TOPIC_NAMES=$(curl -sL -H "X-Auth-Token: $KAFKA_API_KEY" $KAFKA_ADMIN_URL/admin/topics | jq -j '.[]|.name," "')
if [ $? != 0 ]; then hass.log.fatal "Unable to retrieve Kafka topics; exiting"; hass.die; fi
hass.log.debug "Topics availble: ${TOPIC_NAMES}"
TOPIC_FOUND=""
for TN in ${TOPIC_NAMES}; do
  if [ ${TN} == "${KAFKA_TOPIC}" ]; then
    TOPIC_FOUND=true
  fi
done
if [ -z "${TOPIC_FOUND}" ]; then
  hass.log.fatal "Topic ${KAFKA_TOPIC} not found; exiting"
  hass.die
  hass.log.debug "Creating topic ${KAFKA_TOPIC} at ${KAFKA_ADMIN_URL} using /admin/topics"
  curl -sL -H "X-Auth-Token: $KAFKA_API_KEY" -d "{ \"name\": \"$KAFKA_TOPIC\", \"partitions\": 2 }" $KAFKA_ADMIN_URL/admin/topics
  if [ $? != 0 ]; then hass.log.fatal "Unable to create Kafka topic ${KAFKA_TOPIC}; exiting"; hass.die; fi
else
  hass.log.info "Topic found: ${KAFKA_TOPIC}"
fi

###
### CONFIGURE HORIZON
###

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

# if a variety of conditions are true; start-over
if [[ ${LISTEN_MODE} == "only" ]]; then
  hass.log.info "Listen only mode; not starting Open Horizon"
elif [[ ${PATTERN_FOUND} == true && ${EXCHANGE_FOUND} == true && ${EXCHANGE_CONFIGURED} == true ]]; then
  hass.log.info "Device ${EXCHANGE_ID} found with pattern ${PATTERN_URL} in a configured state; skipping registration"
else
  # unregister if currently registered
  if [[ ${EXCHANGE_UNCONFIGURED} != true ]]; then
    hass.log.debug "Device ${EXCHANGE_ID} found with pattern ${PATTERN_URL}, but not configured; unregistering..."
    hzn unregister -f
    while [[ $(hzn node list | jq '.configstate.state?=="unconfigured"') == false ]]; do hass.log.debug "Waiting for unregistration to complete (10)"; sleep 10; done
    COUNT=0
    AGREEMENTS=""
    PATTERN_FOUND=""
    hass.log.debug "Reseting agreements, count, and workloads"
  fi

  # perform registration
  INPUT="${KAFKA_TOPIC}.json"

  echo '{"services": [{"org": "'"${PATTERN_ORG}"'","url": "'"${PATTERN_URL}"'","versionRange": "[0.0.0,INFINITY)","variables": {' >> "${INPUT}"
  echo '"MSGHUB_API_KEY": "'"${KAFKA_API_KEY}"'"' >> "${INPUT}"
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

hass.log.info "Device ${EXCHANGE_ID} in ${EXCHANGE_ORG} registered for pattern ${PATTERN_ID} from ${PATTERN_ORG}"

###
### ADD ON LOGIC
###

# configuration for JQ tranformation
JQ='{"name":.nodeID,"altitude":.gps.alt,"longitude":.gps.lon,"latitude":.gps.lat,"cpu":.cpu}'

# run forever
while [[ "${LISTEN_MODE}" != "false" ]]; do
  hass.log.info "Starting listen loop; routing ${KAFKA_TOPIC} to ${MQTT_TOPIC} at host ${MQTT_HOST} on port ${MQTT_PORT}"

  kafkacat -u -C -q -o end -f "%s\n" -b $KAFKA_BROKER_URL -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username=${KAFKA_API_KEY:0:16}" -X "sasl.password=${KAFKA_API_KEY:16}" -t "$KAFKA_TOPIC" | jq --unbuffered -c "${JQ}" | while read -r; do
    if [ -n "${REPLY}" ]; then
      hass.log.trace "RECEIVED: " $(echo "${REPLY}" | jq -c '.')
      PAYLOAD="${REPLY}"
    else
      hass.log.warning "Null message received; continuing"
      continue
    fi
    hass.log.debug "POSTING: " $(echo "${PAYLOAD}" | jq -c '.')
    echo "${PAYLOAD}" | jq --unbuffered -c ".date="$(date '+%s') | ${MQTT} -t -t "${MQTT_TOPIC}"
  done
  hass.log.warning "Unexpected failure of kafkacat"
done

}

main "$@"
