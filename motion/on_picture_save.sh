#!/bin/bash
echo "${0##*/} $$ -- BEGIN $*" $(date) >& /dev/stderr

DEBUG=true
# VERBOSE=true

if [ -z "${dateconv}" ]; then dateconv=$(command -v "dateconv"); fi
if [ -z "${dateconv}" ]; then dateconv=$(command -v "dateutils.dconv"); fi
if [ -z "${dateconv}" ]; then 
  if [ -n "${DEBUG}" ]; then mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"CMD":"'${0##*/}'","pid":"'$$'","error":"no date utilities; install dateutils"}'; fi
  exit
fi

# get arguments
CN=$1
EN=$2
IF=$3
IT=$4
MX=$5
MY=$6
MW=$7
MH=$8

## check args
if [ =z "${CN}" ]; then CN="error"; fi
if [ =z "${ID}" ]; then ID="error"; fi
if [ =z "${EN}" ]; then EN=0; fi
if [ =z "${MX}" ]; then MX=0; fi
if [ =z "${MY}" ]; then MY=0; fi
if [ =z "${MW}" ]; then MW=0; fi
if [ =z "${MH}" ]; then MH=0; fi

# image identifier, timestamp, seqno
ID="${IF##*/}"
ID="${ID%.*}"
TS=$(echo "${ID}" | sed 's/\(.*\)-.*-.*/\1/')
SN=$(echo "${ID}" | sed 's/.*-..-\(.*\).*/\1/')

NOW=$($dateconv -i '%Y%m%d%H%M%S' -f "%s" "${TS}")

if [ -n "${VERBOSE}" ]; then mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'${0##*/}'","pid":"'$$'","dir":"'${MOTION_TARGET_DIR}'","camera":"'$CN'","time":'$NOW'}'; fi

## create JSON
IJ=$(mktemp)
echo '{"camera":"'"${CN}"'","type":"jpg","time":'"${NOW}"',"date":'$(date +%s)',"seqno":"'"${SN}"'","event":"'"${EN}"'","id":"'"${ID}"'","center":{"x":'"${MX}"',"y":'"${MY}"'},"width":'"${MW}"',"height":'"${MH}"'}' > "${IJ}"

## do MQTT
if [ -n "${MOTION_MQTT_HOST}" ] && [ -n "${MOTION_MQTT_PORT}" ]; then
  # POST JSON
  MQTT_TOPIC="motion/${MOTION_DEVICE_NAME}/${CN}"
  mosquitto_pub -i "${MOTION_DEVICE_NAME}" -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "${MQTT_TOPIC}" -f "${IJ}"
  # POST IMAGE 
  MQTT_TOPIC="motion/${MOTION_DEVICE_NAME}/${CN}/image"
  mosquitto_pub -i "${MOTION_DEVICE_NAME}" -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "${MQTT_TOPIC}" -f "${IF}"
fi

echo "${0##*/} $$ -- END $*" $(date) >& /dev/stderr
