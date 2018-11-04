#!/usr/bin/with-contenv bash
# ==============================================================================
set -o nounset  # Exit script on use of an undefined variable
set -o pipefail # Return exit status of the last command in the pipe that failed
# set -o errtrace # Exit on error inside any functions or sub-shells
# set -o errexit  # Exit script when a command exits with non-zero status

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

## OPTIONS that need to be set

# URL
VALUE=$(hass.config.get "horizon.exchange")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No exchange URL"; hass.die; fi
export HZN_EXCHANGE_URL="${VALUE}"
hass.log.info "Setting HZN_EXCHANGE_URL to ${VALUE}" >&2
JSON="${JSON}"',"exchange":"'"${VALUE}"'"'
# USERNAME
VALUE=$(hass.config.get "horizon.username")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No exchange username"; hass.die; fi
JSON="${JSON}"',"username":"'"${VALUE}"'"'
HZN_EXCHANGE_USER_AUTH="${VALUE}"
# PASSWORD
VALUE=$(hass.config.get "horizon.password")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No exchange password"; hass.die; fi
JSON="${JSON}"',"password":"'"${VALUE}"'"'
export HZN_EXCHANGE_USER_AUTH="${HZN_EXCHANGE_USER_AUTH}:${VALUE}"
hass.log.trace "Setting HZN_EXCHANGE_USER_AUTH ${HZN_EXCHANGE_USER_AUTH}" >&2
# ORGANIZATION
VALUE=$(hass.config.get "horizon.organization")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No horizon organization"; hass.die; fi
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
hass.log.debug "DEVICE_TOKEN ${VALUE}" >&2

## DONE w/ horizon
JSON="${JSON}"'}'

##
## KAFKA OPTIONS
##

JSON="${JSON}"',"kafka":{"id":"'$(hass.config.get 'kafka.instance_id')'"'
# BROKERS_SASL
VALUE=$(jq -r '.kafka.kafka_brokers_sasl' "/data/options.json")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.kafka_brokers_sasl"; hass.die; fi
hass.log.trace "Kafka brokers: ${VALUE}"
JSON="${JSON}"',"brokers":'"${VALUE}"
# ADMIN_URL
VALUE=$(hass.config.get "kafka.kafka_admin_url")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.kafka_admin_url"; hass.die; fi
hass.log.debug "Kafka admin URL: ${VALUE}"
JSON="${JSON}"',"admin_url":"'"${VALUE}"'"'
# API_KEY
VALUE=$(hass.config.get "kafka.api_key")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.api_key"; hass.die; fi
hass.log.trace "Kafka API key: ${VALUE}"
JSON="${JSON}"',"api_key":"'"${VALUE}"'"}'

## DONE w/ JSON
JSON="${JSON}"'}'

hass.log.trace "${JSON}"

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

## KAFKA TOPIC
KAFKA_TOPIC="sdr-audio" # alternatively $(echo "${DEVICE_ORG}.${PATTERN_ORG}_${PATTERN_ID}" | sed 's/@/_/g')

###
### TURN on/off listen only mode
###
VALUE=$(hass.config.get "listen")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="false"; fi
hass.log.trace "Listen: ${VALUE}"
LISTEN_ONLY=${VALUE}

###
### TURN on/off MOCK SDR
###
VALUE=$(hass.config.get "mock")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="false"; fi
hass.log.trace "Mock: ${VALUE}"
MOCK_SDR=${VALUE}

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

## STT

hass.log.trace "Watson STT: " $(hass.config.get "watson_stt")
if [[ -z $(hass.config.get 'watson_stt') ]]; then
  hass.log.fatal "No Watson STT credentials; exiting"
  hass.die
fi
if [[ -n $(hass.config.get 'watson_stt.url') ]]; then
  WATSON_STT_URL=$(hass.config.get "watson_stt.url")
  hass.log.info "Watson STT URL: ${WATSON_STT_URL}"
else
  hass.log.fatal "No Watson STT URL; exiting"
  hass.die
fi
if [[ -n $(hass.config.get 'watson_nlu.apikey') ]]; then
  WATSON_STT_USERNAME="apikey"
  hass.log.debug "Watson STT username: ${WATSON_STT_USERNAME}"
  WATSON_STT_PASSWORD=$(hass.config.get 'watson_stt.apikey')
  hass.log.trace "Watson STT password: ${WATSON_STT_PASSWORD}"
elif [[ -n $(hass.config.get 'watson_stt.username') && -n $(hass.config.get 'watson_stt.password') ]]; then
  WATSON_STT_USERNAME=$(hass.config.get 'watson_stt.username')
  hass.log.trace "Watson STT username: ${WATSON_STT_USERNAME}"
  WATSON_STT_PASSWORD=$(hass.config.get 'watson_stt.password')
  hass.log.trace "Watson STT password: ${WATSON_STT_PASSWORD}"
else
  hass.log.fatal "Watson STT no apikey or username and password; exiting"
  hass.die
fi

## NLU

hass.log.trace "Watson NLU: " $(hass.config.get "watson_nlu")
if [[ -z $(hass.config.get 'watson_nlu') ]]; then
  hass.log.fatal "No Watson NLU credentials; exiting"
  hass.die
fi
if [[ -n $(hass.config.get 'watson_nlu.url') ]]; then
  WATSON_NLU_URL=$(hass.config.get "watson_nlu.url")
  hass.log.info "Watson NLU URL: ${WATSON_NLU_URL}"
else
  hass.log.fatal "No Watson NLU URL specified; exiting"
  hass.die
fi
if [[ -n $(hass.config.get 'watson_nlu.apikey') ]]; then
  WATSON_NLU_USERNAME="apikey"
  hass.log.debug "Watson NLU username: ${WATSON_NLU_USERNAME}"
  WATSON_NLU_PASSWORD=$(hass.config.get "watson_nlu.apikey")
  hass.log.trace "Watson NLU password: ${WATSON_NLU_PASSWORD}"
elif [[ -n $(hass.config.get 'watson_nlu.username') && -n $(hass.config.get 'watson_nlu.password') ]]; then
  WATSON_NLU_USERNAME=$(hass.config.get "watson_nlu.username")
  hass.log.debug "Watson NLU username: ${WATSON_NLU_USERNAME}"
  WATSON_NLU_PASSWORD=$(hass.config.get "watson_nlu.password")
  hass.log.trace "Watson NLU password: ${WATSON_NLU_PASSWORD}"
else
  hass.log.fatal "Watson NLU no apikey or username and password; exiting"
  hass.die
fi

###
### CHECK KAKFA
###

# FIND TOPICS
TOPIC_NAMES=$(curl -sL -H "X-Auth-Token: $KAFKA_API_KEY" $KAFKA_ADMIN_URL/admin/topics | jq -j '.[]|.name," "')
if [ $? != 0 ]; then hass.log.fatal "Unable to retrieve Kafka topics; exiting"; hass.die; fi
hass.log.trace "Topics availble: ${TOPIC_NAMES}"
TOPIC_FOUND=""
for TN in ${TOPIC_NAMES}; do
  if [ ${TN} == "${KAFKA_TOPIC}" ]; then
    TOPIC_FOUND=true
  fi
done
if [ -z "${TOPIC_FOUND}" ]; then
  hass.log.info "Topic ${KAFKA_TOPIC} not found; exiting"
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

# test if horizon is installed
HZN=$(command -v hzn)
if [[ -n "${HZN}" && "${LISTEN_ONLY}" != "true" ]]; then
  # check for outstanding agreements
  AGREEMENTS=$(hzn agreement list)
  COUNT=$(echo "${AGREEMENTS}" | jq '.?|length')
  hass.log.trace "Found ${COUNT} agreements"
  WORKLOAD_FOUND=""
  if [[ ${COUNT} > 0 ]]; then
    WORKLOADS=$(echo "${AGREEMENTS}" | jq -r '.[]|.workload_to_run.url')
    for WL in ${WORKLOADS}; do
      if [ "${WL}" == "${PATTERN_URL}" ]; then
	WORKLOAD_FOUND=true
      fi
    done
  fi
  # if a variety of conditions are true; start-over
  if [[ $COUNT > 0 && $(hzn node list | jq '.id?=="'"${DEVICE_ID}"'"') == true && $(hzn node list | jq '.configstate.state?=="configured"') == true ]]; then
    hass.log.info "Existing agreement with this device in a configured state"
  else
    hass.log.debug "Existing agreement with another device identifier or current node unconfigured or configuring; unregistering..."
    hzn unregister -f
    while [[ $(hzn node list | jq '.configstate.state?=="unconfigured"') == false ]]; do hass.log.debug "Waiting for unregistration to complete (10)"; sleep 10; done
    # hass.log.debug "Waiting for unregistration to complete; sleeping (30)"
    # sleep 30
    COUNT=0
    AGREEMENTS=""
    WORKLOAD_FOUND=""
    hass.log.trace "Reset agreements, count, and workloads"
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
    hass.log.info "Found pattern in existing agreement: ${PATTERN_URL}"
  elif [[ ${COUNT} > 0 ]]; then
    hass.log.fatal "Existing non-matching pattern agreement found; exiting: ${AGREEMENTS}"
    hass.die
  else
    hass.log.fatal "Invalid state; exiting"
    hass.die
  fi
  hass.log.info "Device ${DEVICE_ID} in ${DEVICE_ORG} registered for pattern ${PATTERN_ID} from ${PATTERN_ORG}"
else
  hass.log.info "Horizon not installed or running in listen-only: ${LISTEN_ONLY}"
fi

###
### ADD ON LOGIC
###

# JQ tranformation
JQ='{"date":.ts,"name":.devID,"frequency":.freq,"value":.expectedValue,"longitude":.lon,"latitude":.lat,"content-type":.contentType,"content-transfer-encoding":"BASE64","bytes":.audio|length,"audio":.audio}'

hass.log.info "Listening for topic ${KAFKA_TOPIC}, processing with STT and NLU and posting to ${MQTT_TOPIC} at host ${MQTT_HOST} on port ${MQTT_PORT}..."

  # wait on kafkacat death
  kafkacat -u -C -q -o end -f "%s\n" -b $KAFKA_BROKER_URL -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username=${KAFKA_API_KEY:0:16}" -X "sasl.password=${KAFKA_API_KEY:16}" -t "$KAFKA_TOPIC" | jq -c --unbuffered "${JQ}" | while read -r; do
    if [ -n "${REPLY}" ]; then
      hass.log.info "RECEIVED: " $(echo "${REPLY}" | jq -c '.audio="redacted"')
      PAYLOAD="${REPLY}"
      AUDIO=$(echo "${PAYLOAD}" | jq -r '.audio')
      if [ -z "${AUDIO}" ]; then
        hass.log.debug "No audio in payload ${PAYLOAD}; not processing STT or NLU"
      elif [[ $(echo "${PAYLOAD}" | jq -r '.frequency') != 0 ]]; then
	hass.log.trace "Received message with non-zero frequency; requesting STT from ${WATSON_STT_URL}"
	STT=$(echo "${AUDIO}" | base64 --decode | curl -sL --data-binary @- -u "${WATSON_STT_USERNAME}:${WATSON_STT_PASSWORD}" -H "Content-Type: audio/mp3" "${WATSON_STT_URL}")
	if [[ $? == 0 && -n "${STT}" ]]; then
	  hass.log.trace "Received STT response:" $(echo "${STT}" | jq -c '.')
	  NR=$(echo "${STT}" | jq '.results?|length')
	  hass.log.trace "STT produced ${NR} results"
	  if [[ ${NR} > 0 ]]; then

if [[ ${NR} > 1 ]]; then
	    # perform NLU on unified transcript
	    TRANSCRIPT=$(echo "${STT}" | jq -j '.results[].alternatives[].transcript')
            hass.log.debug "Unified transcript: ${TRANSCRIPT}"
	    N=$(echo '{"text":"'"${TRANSCRIPT}"'","features":{"sentiment":{},"keywords":{}}}' | curl -sL -d @- -u "${WATSON_NLU_USERNAME}:${WATSON_NLU_PASSWORD}" -H "Content-Type: application/json" "${WATSON_NLU_URL}")
	    if [[ $? != 0 || -z "${N}" || $(echo "${N}" | jq '.error?!=null') == "true" ]]; then
	      hass.log.debug "NLU request failed on unified transcript; setting NLU to null; return: " $(echo "${N}" | jq -c '.')
	      STT=$(echo "${STT}" | jq -c '.nlu=null')
	    else
	      hass.log.debug "NLU for unified transcript:" $(echo "${N}" | jq -c '.')
	      STT=$(echo "${STT}" | jq -c '.nlu='"${N}")
	    fi
else
	      hass.log.trace "Single result; no unified transcript"
	      STT=$(echo "${STT}" | jq -c '.nlu=null')
fi

	    # perform NLU on each result alternative
	    R=0; while [ ${R} -lt ${NR} ]; do
	      NA=$(echo "${STT}" | jq -r '.results['${R}'].alternatives|length')
	      hass.log.trace "STT result ${R} with ${NA} alternatives"
	      A=0; while [ ${A} -lt ${NA} ]; do
		C=$(echo "${STT}" | jq -r '.results['${R}'].alternatives['${A}'].confidence')
		T=$(echo "${STT}" | jq -r '.results['${R}'].alternatives['${A}'].transcript')
		hass.log.trace "Alternative ${A}: Confidence ${C}; transcript: ${T}"
		N=$(echo '{"text":"'"${T}"'","features":{"sentiment":{},"keywords":{}}}' | curl -sL -d @- -u "${WATSON_NLU_USERNAME}:${WATSON_NLU_PASSWORD}" -H "Content-Type: application/json" "${WATSON_NLU_URL}")
		if [[ $? != 0 || -z "${N}" || $(echo "${N}" | jq '.error?!=null') == "true" ]]; then
		  hass.log.debug "NLU request failed on transcript ${T}; setting NLU to null; return: " $(echo "${N}" | jq -c '.')
		  STT=$(echo "${STT}" | jq -c '.results['${R}'].alternatives['${A}'].nlu=null')
		else
		  hass.log.trace "NLU for result ${R}; alternative ${A}: " $(echo "${N}" | jq -c '.')
		  STT=$(echo "${STT}" | jq -c '.results['${R}'].alternatives['${A}'].nlu='"${N}")
		fi
		hass.log.trace "Incrementing to next alternative"
		A=$((A+1))
	      done
	      hass.log.trace "Incrementing to next result"
	      R=$((R+1))
	    done  

	    hass.log.trace "Done with ${NR} STT results"
	  else
            hass.log.debug "STT returned zero results: " $(echo "${STT}" | jq -c '.')
          fi
        else
	  STT='{"results":[{"alternatives":[{"confidence":0.0,"transcript":"*** FAIL ***"}],"final":null}],"result_index":0}'
	  hass.log.debug "STT request failed; set STT to ${STT}"
	fi
      else
	hass.log.trace "Mock SDR detected; frequency is zero!"
	STT='{"results":[{"alternatives":[{"confidence":0.0,"transcript":"*** MOCK ***"}],"final":null}],"result_index":-1}'
	PAYLOAD=$(echo "${PAYLOAD}" | jq '.audio=""|.bytes=0')
	hass.log.trace "Set bytes to zero; removed audio; STT set to ${STT}"
      fi
      hass.log.trace "Using STT results: " $(echo "${STT}" | jq -c '.')
      PAYLOAD=$(echo "${PAYLOAD}" | jq -c '.stt='"${STT}")
    else
      hass.log.warning "Null message received; continuing"
      continue
    fi
    if [[ $(echo "${PAYLOAD}" | jq -r '.bytes') > 0 || ${MOCK_SDR} == "true" ]]; then
      hass.log.info "POSTING: " $(echo "${PAYLOAD}" | jq -c '.audio="redacted"')
      echo "${PAYLOAD}" | ${MQTT} -l -t "${MQTT_TOPIC}"
    else
      hass.log.info "IGNORED: zero bytes audio; MOCK_SDR is ${MOCK_SDR}"
    fi
  done
  hass.log.debug "Unexpected failure of kafkacat"

}

main "$@"

