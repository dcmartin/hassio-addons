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

# KAFKA_TOPIC=$(echo "${DEVICE_ORG}.${PATTERN_ORG}_${PATTERN_ID}" | sed 's/@/_/g')
KAFKA_TOPIC="sdr-audio"

# FIND TOPICS
TOPIC_NAMES=$(curl -fsSL -H "X-Auth-Token: $KAFKA_API_KEY" $KAFKA_ADMIN_URL/admin/topics | jq -j '.[]|.name," "')
hass.log.debug "Topics availble: ${TOPIC_NAMES}"
for TN in ${TOPIC_NAMES}; do
  if [ ${TN} == "${KAFKA_TOPIC}" ]; then
    FOUND=true
  fi
done
if [ -z ${FOUND} ]; then
  # attempt to create a new topic
  curl -fsSL -H "X-Auth-Token: $KAFKA_API_KEY" -d "{ \"name\": \"$KAFKA_TOPIC\", \"partitions\": 2 }" $KAFKA_ADMIN_URL/admin/topics
else
  hass.log.debug "Topic found: ${KAFKA_TOPIC}"
fi

HZN=$(command -v hzn)
if [ -z "${HZN}" ]; then
  hass.log.fatal "Failure to install horizon CLI"
  exit
fi

### REGISTER DEVICE WITH PATTERN

# get information about this node
NODE_LIST=$(hzn node list)
if [ -n "${NODE_LIST}" ]; then
  DEVICE_REG=$(echo "${NODE_LIST}" | jq '.id?=="'"${DEVICE_ID}"'"')
else
  DEVICE_REG="false"
fi

if [ "${DEVICE_REG}" == "true" ]; then
  hass.log.warning "${DEVICE_ORG}/${DEVICE_ID} is registered"
fi

if [[ $(hzn agreement list | jq -r '.[]|.workload_to_run.url') != "${PATTERN_URL}" ]]; then
  INPUT="${KAFKA_TOPIC}.json"
  rm -f "${INPUT}"

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

  hass.log.debug "Registering device ${DEVICE_ID} organization ${DEVICE_ORG} with pattern ${PATTERN_ORG}/${PATTERN_ID} using input " $(jq -c '.' "${INPUT}")

  hzn register -n "${DEVICE_ID}:${DEVICE_TOKEN}" "${DEVICE_ORG}" "${PATTERN_ORG}/${PATTERN_ID}" -f "${INPUT}"

  # wait for registration
  while [[ $(hzn node list | jq '.id?=="'"${DEVICE_ID}"'"') == false ]]; do hass.log.debug "--- WAIT: On registration (60)"; sleep 60; done

  hass.log.debug "Registration complete for ${DEVICE_ORG}/${DEVICE_ID}"

  ## WAIT ON AGREEMENT
  while [[ $(hzn agreement list | jq '.?==[]') == true ]]; do hass.log.info "--- WAIT: On agreement (10)"; sleep 10; done

  hass.log.debug "Agreement complete for ${PATTERN_URL}"
else
  hass.log.debug "Workload to run is ${PATTERN_URL}"
fi

hass.log.info "Registered ${DEVICE_ORG}/${DEVICE_ID} for ${PATTERN_ORG}/${PATTERN_ID}" 

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
MQTT="mosquitto_pub -h ${MQTT_HOST} -p ${MQTT_PORT}"
if [[ -n "${MQTT_USERNAME}" && -n "${MQTT_PASSWORD}" ]]; then
  MQTT="${MQTT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD}"
fi

if [[ $(hass.config.has_value 'watson_stt') == false ]]; then
  hass.log.fatal "No Watson STT credentials"
  exit
fi

WATSON_STT_URL=$(hass.config.get "watson_stt.url")
WATSON_STT_USERNAME=$(hass.config.get "watson_stt.username")
WATSON_STT_PASSWORD=$(hass.config.get "watson_stt.password")

hass.log.debug "Watson STT: ${WATSON_STT_URL}"

if [[ $(hass.config.has_value 'watson_nlu') == false ]]; then
  hass.log.fatal "No Watson NLU credentials"
  exit
fi

WATSON_NLU_URL=$(hass.config.get "watson_nlu.url")
WATSON_NLU_USERNAME=$(hass.config.get "watson_nlu.username")
WATSON_NLU_PASSWORD=$(hass.config.get "watson_nlu.password")

hass.log.debug "Watson NLU: ${WATSON_NLU_URL}"

# JQ tranformation
JQ='{"date":.ts,"name":.devID,"frequency":.freq,"value":.expectedValue,"longitude":.lon,"latitude":.lat,"content-type":.contentType,"content-transfer-encoding":"BASE64","bytes":.audio|length,"audio":.audio}'

# wait on kafkacat death and re-start as long as token is valid
while [[ $(hzn agreement list | jq -r '.[]|.workload_to_run.url') == "${PATTERN_URL}" ]]; do
  hass.log.info "Starting main loop; listening for topic ${KAFKA_TOPIC}, processing with STT and NLU and posting to ${MQTT_TOPIC} at host ${MQTT_HOST} on port ${MQTT_PORT}"

  kafkacat -u -C -q -o end -f "%s\n" -b $KAFKA_BROKER_URL -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username=${KAFKA_API_KEY:0:16}" -X "sasl.password=${KAFKA_API_KEY:16}" -t "$KAFKA_TOPIC" | jq -c --unbuffered "${JQ}" | while read -r; do
    hass.log.debug "Got reply " $(echo "${REPLY}" | jq -c '.audio="redacted"')
    PAYLOAD="${REPLY}"
    STT=$(echo "${PAYLOAD}" | jq --unbuffered -r '.audio' | base64 --decode | curl -fsSL --data-binary @- -u "${WATSON_STT_USERNAME}:${WATSON_STT_PASSWORD}" -H "Content-Type: audio/mp3" "${WATSON_STT_URL}")
    if [ -n "${STT}" ]; then
      hass.log.debug "Got STT " $(echo "${STT}" | jq -c '.')
      PAYLOAD=$(echo "${PAYLOAD}" | jq -c '.stt='"${STT}")
      NLU=$(echo "${STT}" | jq --unbuffered '{"text":.results?|sort_by(.alternatives[].confidence)[-1].alternatives[].transcript,"features":{"sentiment":{},"keywords":{}}}' | curl -fsSL -d @- -u "${WATSON_NLU_USERNAME}:${WATSON_NLU_PASSWORD}" -H "Content-Type: application/json" "${WATSON_NLU_URL}")
    fi
    if [ -n "${NLU}" ]; then
      hass.log.debug "Got NLU " $(echo "${NLU}" | jq -c '.')
      PAYLOAD=$(echo "${PAYLOAD}" | jq -c '.nlu='"${NLU}")
    fi
    if [ -n "${PAYLOAD}" ]; then
      hass.log.debug "Posting PAYLOAD " $(echo "${PAYLOAD}" | jq -c '.audio="redacted"')
      echo "${PAYLOAD}" | ${MQTT} -l -t "${MQTT_TOPIC}"
    fi
  done
  hass.log.debug "Unexpected failure of kafkacat"
done

hass.log.fatal "Workload no longer valid"

}

main "$@"

