#!/bin/bash
echo "${0##*/} $$ -- BEGIN $*" $(date) >& /dev/stderr

DEBUG=true
VERBOSE=true

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

# image identifier
ID="${IF##*/}"
ID="${ID%.*}"
TS=$(echo "${ID}" | sed 's/\(.*\)-.*-.*/\1/')
TS=$(dateutils.dconv -i '%Y%m%d%H%M%S' -f "%s" "${TS}")
SN=$(echo "${ID}" | sed 's/.*-..-\(.*\).*/\1/')
IJ=$(mktemp)

## create JSON
echo '{"camera":"'"${CN}"'","type":"jpg","time":'"${TS}"',"date":'$(date +%s)',"seqno":"'"${SN}"'","event":"'"${EN}"'","id":"'"${ID}"'","center":{"x":'"${MX}"',"y":'"${MY}"'},"width":'"${MW}"',"height":'"${MH}"'}' > "${IJ}"

## do MQTT
if [ -n "${MOTION_MQTT_HOST}" ] && [ -n "${MOTION_MQTT_PORT}" ]; then
  # POST JSON
  MQTT_TOPIC="motion/${MOTION_DEVICE_NAME}/${CN}"
  if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- MQTT post to ${MQTT_TOPIC}" >& /dev/stderr; fi
  mosquitto_pub -i "${MOTION_DEVICE_NAME}" -h "${MOTION_MQTT_HOST}" -t "${MQTT_TOPIC}" -f "${IJ}"
  # POST IMAGE 
  MQTT_TOPIC="motion/${MOTION_DEVICE_NAME}/${CN}/image"
  if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- MQTT post to ${MQTT_TOPIC}" >& /dev/stderr; fi
  mosquitto_pub -i "${MOTION_DEVICE_NAME}" -h "${MOTION_MQTT_HOST}" -t "${MQTT_TOPIC}" -f "${IF}"
fi

echo "${0##*/} $$ -- END $*" $(date) >& /dev/stderr
