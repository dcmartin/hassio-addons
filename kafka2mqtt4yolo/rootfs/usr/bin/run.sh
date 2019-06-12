#!/usr/bin/with-contenv bash
# ==============================================================================
# set -o nounset  # Exit script on use of an undefined variable
# set -o pipefail # Return exit status of the last command in the pipe that failed
# set -o errexit  # Exit script when a command exits with non-zero status
# set -o errtrace # Exit on error inside any functions or sub-shells

# shellcheck disable=SC1091
source /usr/lib/hassio-addons/base.sh

# should be from environment
DATA_DIR="/data"

kafka2mqtt_config()
{
  hass.log.trace "${FUNCNAME[0]}"

  # START ADDON_CONFIG
  ADDON_CONFIG='{"hostname":"'"$(hostname)"'","arch":"'"$(arch)"'","date":'$(date +%s)
  # time zone
  VALUE=$(hass.config.get "timezone")
  # Set the correct timezone
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="GMT"; fi
  hass.log.debug "Setting TIMEZONE ${VALUE}" >&2
  cp /usr/share/zoneinfo/${VALUE} /etc/localtime
  ADDON_CONFIG="${ADDON_CONFIG}"',"timezone":"'"${VALUE}"'"'

  ## KAFKA OPTIONS
  ADDON_CONFIG="${ADDON_CONFIG}"',"kafka":{'
  # TOPIC
  VALUE=$(hass.config.get "kafka.topic")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="yolo2msghub"; fi
  hass.log.debug "Kafka topic: ${VALUE}"
  # first; no comma
  ADDON_CONFIG="${ADDON_CONFIG}"'"topic":"'"${VALUE}"'"'
  # BROKERS
  VALUE=$(hass.config.get "kafka.broker")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.broker"; hass.die; fi
  hass.log.debug "Kafka broker: ${VALUE}"
  ADDON_CONFIG="${ADDON_CONFIG}"',"broker":"'"${VALUE}"'"'
  # APIKEY
  VALUE=$(hass.config.get "kafka.apikey")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then hass.log.fatal "No kafka.apikey"; hass.die; fi
  hass.log.debug "Kafka API key: ${VALUE}"
  ADDON_CONFIG="${ADDON_CONFIG}"',"apikey":"'"${VALUE}"'"'
  # DONE w/ kafka
  ADDON_CONFIG="${ADDON_CONFIG}"'}'

  ## MQTT OPTIONS
  ADDON_CONFIG="${ADDON_CONFIG}"',"mqtt":{'
  # topic
  VALUE=$(hass.config.get "mqtt.topic")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="yolo2msghub"; fi
  hass.log.debug "MQTT topic: ${VALUE}"
  # first, no comma
  ADDON_CONFIG="${ADDON_CONFIG}"'"topic":"'"${VALUE}"'"'
  # host
  VALUE=$(hass.config.get "mqtt.host")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="core-mosquitto"; fi
  hass.log.debug "MQTT host: ${VALUE}"
  ADDON_CONFIG="${ADDON_CONFIG}"',"host":"'"${VALUE}"'"'
  # port
  VALUE=$(hass.config.get "mqtt.port")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="1883"; fi
  hass.log.debug "MQTT port: ${VALUE}"
  ADDON_CONFIG="${ADDON_CONFIG}"',"port":'"${VALUE}"
  # username
  VALUE=$(hass.config.get "mqtt.username")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE=""; fi
  hass.log.debug "MQTT username: ${VALUE}"
  ADDON_CONFIG="${ADDON_CONFIG}"',"username":"'"${VALUE}"'"'
  # password
  VALUE=$(hass.config.get "mqtt.password")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE=""; fi
  hass.log.debug "MQTT password: ${VALUE}"
  ADDON_CONFIG="${ADDON_CONFIG}"',"password":"'"${VALUE}"'"'
  # DONE w/ mqtt
  ADDON_CONFIG="${ADDON_CONFIG}"'}'

  ## DONE w/ ADDON_CONFIG
  ADDON_CONFIG="${ADDON_CONFIG}"'}'

  ## configuration complete
  hass.log.trace "CONFIGURATION complete:" $(echo "${ADDON_CONFIG}" | jq -c '.')
  export ADDON_CONFIG_FILE="${DATA_DIR}/$(hostname)-config.json"
  # check it
  echo "${ADDON_CONFIG}" | jq '.' > "${ADDON_CONFIG_FILE}"
  if [ ! -s "${ADDON_CONFIG_FILE}" ]; then
    hass.log.fatal "Invalid addon configuration: ${ADDON_CONFIG}"
    hass.die
  else
    hass.log.info "Valid addon configuration: ${ADDON_CONFIG_FILE}"
  fi
}

mqtt_pub()
{
  hass.log.trace "${FUNCNAME[0]}"

  if [ -z "${MQTT_DEVICE:-}" ]; then MQTT_DEVICE=$(hostname) && hass.log.warning "MQTT_DEVICE unspecified; using hostname: ${MQTT_DEVICE}"; fi
  ARGS=${*}
  if [ ! -z "${ARGS}" ]; then
    hass.log.trace "got arguments: ${ARGS}"
    if [ ! -z "${MQTT_USERNAME}" ]; then
      ARGS='-u '"${MQTT_USERNAME}"' '"${ARGS}"
      hass.log.trace "set username: ${ARGS}"
    fi
    if [ ! -z "${MQTT_PASSWORD}" ]; then
      ARGS='-P '"${MQTT_PASSWORD}"' '"${ARGS}"
      hass.log.trace "set password: ${ARGS}"
    fi
    hass.log.debug "publishing as ${MQTT_DEVICE} to ${MQTT_HOST} port ${MQTT_PORT} using arguments: ${ARGS}"
    mosquitto_pub -i "${MQTT_DEVICE}" -h "${MQTT_HOST}" -p "${MQTT_PORT}" ${ARGS}
  else
    hass.log.warning "nothing to send"
  fi
}

kafka2mqtt_process_yolo2msghub()
{
  hass.log.trace "${FUNCNAME[0]}"

  NOW=$(date +%s)
  DEVICES="${*}"
  BUFFER=$(cat)

  if [ ! -z "${BUFFER}" ]; then
    PAYLOAD=$(mktemp)
    echo "${BUFFER}"  > ${PAYLOAD}

    BYTES=$(wc -c ${PAYLOAD} | awk '{ print $1 }')
    TOTAL_BYTES=$((TOTAL_BYTES+BYTES))
    ELAPSED=$((NOW-BEGIN))

    if [ ${ELAPSED} -ne 0 ]; then BPS=$(echo "${TOTAL_BYTES} / ${ELAPSED}" | bc -l); else BPS=1; fi
    hass.log.debug "### DATA $0 $$ -- received at: $(date +%T); bytes: ${BYTES}; total bytes: ${TOTAL_BYTES}; bytes/sec: ${BPS}"

    # get payload specifics
    ID=$(jq -r '.hzn.device_id' ${PAYLOAD})
    ENTITY=$(jq -r '.yolo2msghub.yolo.detected[]?.entity' ${PAYLOAD})
    DATE=$(jq -r '.date' ${PAYLOAD})
    STARTED=$((NOW-DATE))

    # HZN
    if [ $(jq '.hzn?!=null' ${PAYLOAD}) = true ]; then HZN=$(jq '.hzn' ${PAYLOAD}) HZN_STATUS=$(echo "${HZN}" | jq -c '.'); fi
    HZN_STATUS=${HZN_STATUS:-null}
    # WAN
    if [ $(jq '.wan?!=null' ${PAYLOAD}) = true ]; then WAN=$(jq '.wan' ${PAYLOAD}) WAN_DOWNLOAD=$(echo "${WAN}" | jq -r '.speedtest.download'); fi
    WAN_DOWNLOAD=${WAN_DOWNLOAD:-0}
    # CPU
    if [ $(jq '.cpu?!=null' ${PAYLOAD}) = true ]; then CPU=$(jq '.cpu' ${PAYLOAD}) CPU_PERCENT=$(echo "${CPU}" | jq -r '.percent'); fi
    CPU_PERCENT=${CPU_PERCENT:-0}
    # HAL
    if [ $(jq '.hal?!=null' ${PAYLOAD}) = true ]; then HAL=$(jq '.hal' ${PAYLOAD}) HAL_PRODUCT=$(echo "${HAL}" | jq -r '.lshw.product'); fi
    HAL_PRODUCT="${HAL_PRODUCT:-unknown}"

    hass.log.debug "device: ${ID}; hzn: ${HZN_STATUS}; entity: ${ENTITY:-}; started: ${STARTED}; download: ${WAN_DOWNLOAD}; percent: ${CPU_PERCENT}; product: ${HAL_PRODUCT}"

    # have we seen this before
    if [ ! -z "${ID:-}" ] && [ ! -z "${DEVICES:-}" ] && [ "${DEVICES}" != '[]' ]; then
      THIS=$(echo "${DEVICES}" | jq '.[]|select(.id=="'${ID}'")')
    else
      THIS='null'
    fi

    if [ -z "${THIS}" ] || [ "${THIS}" = 'null' ]; then
      NODE_ENTITY_COUNT=0
      NODE_SEEN_COUNT=0
      NODE_MOCK_COUNT=0
      NODE_FIRST_SEEN=0
      NODE_LAST_SEEN=0
      NODE_AVERAGE=0
      THIS='{"id":"'${ID:-}'","entity":"'${ENTITY}'","date":'${DATE}',"started":'${STARTED}',"count":'${NODE_ENTITY_COUNT}',"mock":'${NODE_MOCK_COUNT}',"seen":'${NODE_SEEN_COUNT}',"first":'${NODE_FIRST_SEEN}',"last":'${NODE_LAST_SEEN}',"average":'${NODE_AVERAGE:-0}',"download":'${WAN_DOWNLOAD:-0}',"percent":'${CPU_PERCENT:-0}',"product":"'${HAL_PRODUCT:-unknown}'"}'
    else
      NODE_ENTITY_COUNT=$(echo "${THIS}" | jq '.count') || NODE_ENTITY_COUNT=0
      NODE_MOCK_COUNT=$(echo "${THIS}" | jq '.mock') || NODE_MOCK_COUNT=0
      NODE_SEEN_COUNT=$(echo "${THIS}" | jq '.seen') || NODE_SEEN_COUNT=0
      NODE_FIRST_SEEN=$(echo "${THIS}" | jq '.first') || NODE_FIRST_SEEN=0
      NODE_LAST_SEEN=$(echo "${THIS}" | jq '.last') || NODE_LAST_SEEN=0
      NODE_AVERAGE=$(echo "${THIS}" | jq '.average') || NODE_AVERAGE=0
    fi

    # test payload
    if [ $(jq '.yolo2msghub.yolo!=null' ${PAYLOAD}) = true ]; then
      WHEN=$(jq -r '.yolo2msghub.yolo.date' ${PAYLOAD})
      if [ $(jq -r '.yolo2msghub.yolo.mock' ${PAYLOAD}) = 'null' ]; then
	hass.log.trace "${ID}: non-mock"
	if [ ${WHEN:-0} -gt ${NODE_LAST_SEEN} ]; then
	  hass.log.trace "${ID}: new payload"

	  # send copy of payload
	  hass.log.debug "sending payload to topic ${MQTT_TOPIC}/payload"
	  mqtt_pub -t "${MQTT_TOPIC}/image" -f ${PAYLOAD}

	  SEEN=$(jq -r '.yolo2msghub.yolo.count' ${PAYLOAD})
	  if [ ${SEEN} -gt 0 ]; then

	    # retrieve image and convert from BASE64 to JPEG; publish image
	    TEMP=$(mktemp)
	    jq -r '.yolo2msghub.yolo.image' ${PAYLOAD} | base64 --decode > ${TEMP}
	    hass.log.debug "sending image to topic ${MQTT_TOPIC}/image"
	    mqtt_pub -t "${MQTT_TOPIC}/image" -f ${TEMP}
	    rm -f ${TEMP}

	    # increment total entities seen
	    NODE_SEEN_COUNT=$((NODE_SEEN_COUNT+SEEN))
	    # track when
	    NODE_LAST_SEEN=${WHEN:-0}
	    AGO=$((NOW-NODE_LAST_SEEN))
	    hass.log.info "### DATA $0 $$ -- ${ID}; ago: ${AGO:-0}; ${ENTITY} seen: ${SEEN}"
	    # calculate interval
	    if [ "${NODE_FIRST_SEEN:-0}" -eq 0 ]; then NODE_FIRST_SEEN=${NODE_LAST_SEEN}; fi
	    INTERVAL=$((NODE_LAST_SEEN-NODE_FIRST_SEEN))
	    if [ ${INTERVAL} -eq 0 ]; then 
	      NODE_FIRST_SEEN=${WHEN:-0}
	      INTERVAL=0
	      NODE_AVERAGE=1.0
	    else
	      NODE_AVERAGE=$(echo "${NODE_SEEN_COUNT}/${INTERVAL}" | bc -l)
	    fi
	    THIS=$(echo "${THIS}" | jq '.date='${NOW}'|.interval='${INTERVAL:-0}'|.ago='${AGO:-0}'|.seen='${NODE_SEEN_COUNT:-0}'|.last='${NODE_LAST_SEEN:-0}'|.first='${NODE_FIRST_SEEN:-0}'|.average='${NODE_AVERAGE:-0})
	  else
	    hass.log.trace "${ID} at ${WHEN:-0}; did not see: ${ENTITY:-null}"
	  fi
	else
	  hass.log.trace "old payload"
	fi
      else
	hass.log.warning "${ID} at ${WHEN:-0}: mock" $(jq -c '.yolo2msghub.yolo.detected' ${PAYLOAD})
	NODE_MOCK_COUNT=$((NODE_MOCK_COUNT+1)) && THIS=$(echo "${THIS}" | jq '.mock='${NODE_MOCK_COUNT})
      fi
    else
      hass.log.warning "${ID} at ${WHEN:-0}: no yolo output"
    fi

    # remove payload
    rm -f ${PAYLOAD}

    NODE_ENTITY_COUNT=$((NODE_ENTITY_COUNT+1))
    THIS=$(echo "${THIS}" | jq '.count='${NODE_ENTITY_COUNT})
  else
    hass.log.trace  "received null payload:" $(date +%T)
    THIS=
  fi
  echo "${THIS:-}"
}

kafka2mqtt_poll()
{
  hass.log.trace "${FUNCNAME[0]}"

  hass.log.debug "listening: ${KAFKA_TOPIC}; ${KAFKA_APIKEY}; ${KAFKA_BROKER_URL}"

  # globals
  DEVICES=
  TOTAL_BYTES=0
  BEGIN=$(date +%s)

  TEMP=$(mktemp)
  kafkacat -E -u -C -q -o end -f "%s\n" -b "${KAFKA_BROKER_URL}" \
    -X "security.protocol=sasl_ssl" \
    -X "sasl.mechanisms=PLAIN" \
    -X "sasl.username=${KAFKA_APIKEY:0:16}" \
    -X "sasl.password=${KAFKA_APIKEY:16}" \
    -t "${KAFKA_TOPIC}" | while read -r; do

      THIS=$(echo "${REPLY}" | kafka2mqtt_process_yolo2msghub "${DEVICES}")

      # check for null payload
      if [ ! -z "${THIS}" ]; then
        # check for existing devices
        if [ ! -z "${DEVICES}" ]; then
          ID=$(echo "${THIS}" | jq -r '.id')
          THAT=$(echo "${DEVICES}" | jq '.[]|select(.id=="'${ID}'")')
          if [ ! -z "${THAT}" ]; then
	    hass.log.debug "updating device ${ID}"
            DEVICES=$(echo "${DEVICES}" | jq '(.[]|select(.id=="'${ID}'"))|='"${THIS}")
          else
	    hass.log.debug "adding device ${ID}"
            DEVICES=$(echo "${DEVICES}" | jq '.+=['"${THIS}"']')
          fi
        else
	  hass.log.debug "no existing devices"
          DEVICES='['"${THIS}"']'
        fi 

        # send JSON update
        echo "${DEVICES}" | jq -c '{"'${KAFKA_TOPIC}'":{"date":"'$(date +%s)'","timestamp":"'$(date -u +%FT%TZ)'","activity":.|sort_by(.date)}}' > ${TEMP}
        # send summary data
        mqtt_pub -t ${MQTT_TOPIC} -f ${TEMP}
      fi
  done
}
  
###
### MAIN
###

# configure
kafka2mqtt_config

# get config
KAFKA_TOPIC=$(jq -r '.kafka.topic' "${ADDON_CONFIG_FILE}")
KAFKA_BROKER_URL=$(jq -r '.kafka.broker' "${ADDON_CONFIG_FILE}")
KAFKA_APIKEY=$(jq -r '.kafka.apikey' "${ADDON_CONFIG_FILE}")
MQTT_TOPIC=$(jq -r '.mqtt.topic' "${ADDON_CONFIG_FILE}")
MQTT_HOST=$(jq -r '.mqtt.host' "${ADDON_CONFIG_FILE}")
MQTT_PORT=$(jq -r '.mqtt.port' "${ADDON_CONFIG_FILE}")
MQTT_USERNAME=$(jq -r '.mqtt.username' "${ADDON_CONFIG_FILE}")
MQTT_PASSWORD=$(jq -r '.mqtt.password' "${ADDON_CONFIG_FILE}")

# forever poll
while true; do
  # run
  kafka2mqtt_poll
done
