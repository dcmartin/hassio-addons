#!/bin/bash
echo "${0##*/} $$ -- BEGIN $*" $(date)

DEBUG=true
VERBOSE=true

if [ -z "${dateconv}" ]; then dateconv=$(command -v "dateconv"); fi
if [ -z "${dateconv}" ]; then dateconv=$(command -v "dateutils.dconv"); fi
if [ -z "${dateconv}" ]; then 
  if [ -n "${DEBUG}" ]; then mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"CMD":"'${0##*/}'","pid":"'$$'","error":"no date utilities; install dateutils"}'; fi
  exit
fi


# 
# %Y = year, %m = month, %d = date,
# %H = hour, %M = minute, %S = second,
# %v = event, %q = frame number, %t = thread (camera) number,
# %D = changed pixels, %N = noise level,
# %i and %J = width and height of motion area,
# %K and %L = X and Y coordinates of motion center
# %C = value defined by text_event
# %f = filename with full path
# %n = number indicating filetype
# Both %f and %n are only defined for on_picture_save, on_movie_start and on_movie_end
#
# on_picture_save /usr/local/bin/on_picture_save.sh %$ %v %f %n %K %L %i %J %D %N
#

# get arguments
CN="$1"
EN="$2"
IF="$3"
IT="$4"
MX="$5"
MY="$6"
MW="$7"
MH="$8"
SZ="$9"

## check args
if [ -z "${CN}" ]; then CN="error"; fi
if [ -z "${IF}" ]; then IF="/tmp/test.jpg"; fi
if [ -z "${IT}" ]; then IT=0; fi
if [ -z "${EN}" ]; then EN=0; fi
if [ -z "${MX}" ]; then MX=0; fi
if [ -z "${MY}" ]; then MY=0; fi
if [ -z "${MW}" ]; then MW=0; fi
if [ -z "${MH}" ]; then MH=0; fi
if [ -z "${SZ}" ]; then SZ=0; fi

# image identifier, timestamp, seqno
ID="${IF##*/}"
ID="${ID%.*}"
TS=$(echo "${ID}" | sed 's/\(.*\)-.*-.*/\1/')
SN=$(echo "${ID}" | sed 's/.*-..-\(.*\).*/\1/')

NOW=$($dateconv -i '%Y%m%d%H%M%S' -f "%s" "${TS}")
if [ -z "${NOW}" ]; then NOW=0; fi

if [ -n "${VERBOSE}" ]; then mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'${0##*/}'","pid":"'$$'","dir":"'${MOTION_TARGET_DIR}'","camera":"'$CN'","time":'$NOW'}'; fi

## create JSON
IJ="${IF%.*}".json

JSON=$(echo '{"device":"'${MOTION_DEVICE_NAME}'","camera":"'"${CN}"'","type":"jpeg","time":'"${NOW}"',"seqno":"'"${SN}"'","event":"'"${EN}"'","id":"'"${ID}"'","center":{"x":'"${MX}"',"y":'"${MY}"'},"width":'"${MW}"',"height":'"${MH}"',"size":'${SZ}'}')

TEST=$(echo "${JSON}" | jq '.')

if [ ! -z "${TEST}" ]; then
  echo "${TEST}" > "${IJ}"
  if [ -n "${VERBOSE}" ]; then mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"VERBOSE":"'${0##*/}'","pid":"'$$'","json":'"${TEST}"'}'; fi
else
  if [ -n "${DEBUG}" ]; then mosquitto_pub -h "${MOTION_MQTT_HOST}" -t "debug" -m '{"DEBUG":"'${0##*/}'","pid":"'$$'","invalid":"'"${JSON}"'"}'; fi
fi

## do MQTT
if [ -n "${MOTION_MQTT_HOST}" ] && [ -n "${MOTION_MQTT_PORT}" ]; then
  # POST JSON
  MQTT_TOPIC="motion/${MOTION_DEVICE_NAME}/${CN}"
  mosquitto_pub -i "${MOTION_DEVICE_NAME}" -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "${MQTT_TOPIC}" -f "${IJ}"
  if [ "${MOTION_POST_PICTURES}" == "on" ]; then
    # POST IMAGE 
    MQTT_TOPIC="motion/${MOTION_DEVICE_NAME}/${CN}/image"
    mosquitto_pub -r -i "${MOTION_DEVICE_NAME}" -h "${MOTION_MQTT_HOST}" -p "${MOTION_MQTT_PORT}" -t "${MQTT_TOPIC}" -f "${IF}"
  fi
fi

echo "${0##*/} $$ -- END $*" $(date) >& /dev/stderr
