#!/bin/bash

echo $(date) "$0 $*" >&2

if [ ! -s "${CONFIG_PATH}" ]; then
  echo "Cannot find options ${CONFIG_PATH}; exiting" >&2
  exit
fi

# Specify the hardware architecture of this Edge Node

ARCH=$(arch)
if [ -z "${ARCH}" ]; then
  echo "!!! ERROR: No architecture detected; exiting"
  exit
fi

if [ "${ARCH}" == "aarch64" ]; then
  ARCH="arm64"
elif [ "${ARCH}" == "x86_64" ]; then
  IBM_CLI_SUPPORTED=true
  ARCH="amd64"
elif [ "${ARCH}" == "armv71" ]; then
  IBM_CLI_SUPPORTED=true
  ARCH="arm"
else
  echo "Cannot automagically identify architecture (${ARCH}); options are: arm, arm64, amd64, ppc64el"
  exit
fi

echo "+++ INFO: Using architecture: ${ARCH}"

###
### A HOST at DATE on ARCH
###

JSON='{"host":"'"$(hostname)"'","arch":"'"${ARCH}"'","date":'$(/bin/date +%s)
# time zone
VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="GMT"; fi
echo "Setting TIMEZONE ${VALUE}" >&2
cp /usr/share/zoneinfo/${VALUE} /etc/localtime
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

##
## HORIZON 
##

# START JSON

JSON="${JSON}"',"horizon":{"pattern":'"${HZN_PATTERN}"

## OPTIONS that need to be set

# URL
VALUE=$(jq -r ".horizon.exchange" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No exchange URL"; exit; fi
export HZN_EXCHANGE_URL="${VALUE}"
echo "Setting HZN_EXCHANGE_URL to ${VALUE}" >&2
JSON="${JSON}"',"exchange":"'"${VALUE}"'"'
# USERNAME
VALUE=$(jq -r ".horizon.username" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No exchange username"; exit; fi
JSON="${JSON}"',"username":"'"${VALUE}"'"'
# PASSWORD
VALUE=$(jq -r ".horizon.password" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No exchange password"; exit; fi
JSON="${JSON}"',"password":"'"${VALUE}"'"'
export HZN_EXCHANGE_USER_AUTH="${HZN_EXCHANGE_USER_AUTH}:${VALUE}"
echo "Setting HZN_EXCHANGE_USER_AUTH ${HZN_EXCHANGE_USER_AUTH}" >&2

# ORGANIZATION
VALUE=$(jq -r ".horizon.organization" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No horizon organization"; exit; fi
JSON="${JSON}"',"organization":"'"${VALUE}"'"'
# DEVICE
VALUE=$(jq -r ".horizon.device" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE=$(ip addr | egrep -v NO-CARRIER | egrep -A 1 BROADCAST | egrep -v BROADCAST | sed "s/.*ether \([^ ]*\) .*/\1/g" | sed "s/://g" | head -1)
  VALUE="$(hostname)-${VALUE}"
fi
JSON="${JSON}"',"device":"'"${VALUE}"'"'
echo "DEVICE_ID ${VALUE}" >&2
# TOKEN
VALUE=$(jq -r ".horizon.token" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE==$(echo "${HZN_EXCHANGE_USER_AUTH}" | sed 's/.*://')
fi
JSON="${JSON}"',"token":"'"${VALUE}"'"'
echo "DEVICE_TOKEN ${VALUE}" >&2

## DONE w/ horizon
JSON="${JSON}"'}'

##
## KAFKA OPTIONS
##

JSON="${JSON}"',"kafka":{"instance_id":"'$(jq -r '.kafka.instance_id')'"'
# BROKERS_SASL
VALUE=$(jq -r '.kafka.kafka_brokers_sasl' "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No kafka kafka_brokers_sasl"; exit; fi
echo "Kafka brokers: ${VALUE}"
JSON="${JSON}"',"brokers":'"${VALUE}"
# ADMIN_URL
VALUE=$(jq -r '.kafka.kafka_admin_url' "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No kafka kafka_admin_url"; exit; fi
echo "Kafka admin URL: ${VALUE}"
JSON="${JSON}"',"admin_url":"'"${VALUE}"'"'
# API_KEY
VALUE=$(jq -r '.kafka.api_key' "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No kafka api_key"; exit; fi
echo "Kafka API key: ${VALUE}"
JSON="${JSON}"',"api_key":"'"${VALUE}"'"}'

## DONE w/ kakfa
JSON="${JSON}"'}'

echo "${JSON}"

###
### REVIEW
###

HZN_PATTERN_ORG=$(echo "$JSON" | jq -r '.horizon.pattern.org?')
HZN_PATTERN_ID=$(echo "$JSON" | jq -r '.horizon.pattern.id?')
HZN_PATTERN_URL=$(echo "$JSON" | jq -r '.horizon.pattern.url?')

KAFKA_BROKER_URL=$(echo "$JSON" | jq -j '.kafka.brokers[]?|.,","')
KAFKA_ADMIN_URL=$(echo "$JSON" | jq -r '.kafka.admin_url?')
KAFKA_API_KEY=$(echo "$JSON" | jq -r '.kafka.api_key?')

DEVICE_ID=$(echo "$JSON" | jq -r '.horizon.device?' )
DEVICE_TOKEN=$(echo "$JSON" | jq -r '.horizon.token?')
DEVICE_ORG=$(echo "$JSON" | jq -r '.horizon.organization?')

echo "+++ INFO: HORIZON device ${DEVICE_ID} in ${HZN_ORG_ID} using pattern ${HZN_PATTERN_ORG}/${HZN_PATTERN_ID} @ ${HZN_PATTERN_URL}"

###
### CHECK KAKFA
###

KAFKA_TOPIC=$(echo "${DEVICE_ORG}.${HZN_PATTERN_ORG}_${HZN_PATTERN_ID}" | sed 's/@/_/g')

# FIND TOPICS
TOPIC_NAMES=$(curl -fsSL -H "X-Auth-Token: $KAFKA_API_KEY" $KAFKA_ADMIN_URL/admin/topics | jq -j '.[]|.name," "')
echo "+++ INFO: Topics availble:"
for TN in ${TOPIC_NAMES}; do
  echo -n " ${TN}"
  if [ ${TN} == "${KAFKA_TOPIC}" ]; then
    FOUND=true
  fi
done
if [ -z ${FOUND} ]; then
  # attempt to create a new topic
  curl -fsSL -H "X-Auth-Token: $KAFKA_API_KEY" -d "{ \"name\": \"$KAFKA_TOPIC\", \"partitions\": 2 }" $KAFKA_ADMIN_URL/admin/topics
else
  echo "+++ INFO: Topic found: ${KAFKA_TOPIC}"
fi

### INSTALL HORIZON 

curl -fsSL "${HZN_PUBLICKEY_URL}" | apt-key add -
echo "deb [arch=${ARCH}] http://pkg.bluehorizon.network/linux/ubuntu xenial-${HZN_APT_REPO} main" >> "${HZN_APT_LIST}"
echo "deb-src [arch=${ARCH}] http://pkg.bluehorizon.network/linux/ubuntu xenial-${HZN_APT_REPO} main" >> "${HZN_APT_LIST}"
apt-get update -y
apt-get install -y horizon-cli

HZN=$(command -v hzn)
if [ ! -z "${HZN}" ]; then
  echo "!!! ERROR: Failure to install horizon CLI"
  exit
fi

### REGISTER DEVICE WITH PATTERN

NODE_LIST=$(hzn node list)
if [ -n "${NODE_LIST}" ]; then
  DEVICE_REG=$(echo "${NODE_LIST}" | jq '.id?=="'"${DEVICE_ID}"'"')
fi
if [ "${DEVICE_REG}" == "true" ]; then
    echo "### ALREADY REGISTERED as ${DEVICE_ID} organization ${DEVICE_ORG}"
else
  INPUT="${KAFKA_TOPIC}.json"
  if [ -s "${INPUT}" ]; then
    echo "*** WARN: Existing services registration file found: ${INPUT}; deleting"
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

  echo "### REGISTERING device ${DEVICE_ID} organization ${DEVICE_ORG}) with pattern ${PATTERN_ORG}/${PATTERN_ID} using input " $(jq -c '.' "${INPUT}")
  hzn register -n "${DEVICE_ID}:${DEVICE_TOKEN}" "${DEVICE_ORG}" "${PATTERN_ORG}/${PATTERN_ID}" -f "${INPUT}"
fi

###
### POST REGISTRATION WAITING
###

while [[ $(hzn node list | jq '.id?=="'"${DEVICE_ID}"'"') == false ]]; do echo "--- WAIT: On registration (60)" $(date); sleep 60; done
echo "+++ INFO: Registration complete" $(date)

while [[ $(hzn node list | jq '.connectivity."firmware.bluehorizon.network"?==true') == false ]]; do echo "--- WAIT: On firmware (60)" $(date); sleep 60; done
echo "+++ INFO: Firmware complete" $(date)

while [[ $(hzn node list | jq '.connectivity."images.bluehorizon.network"?==true') == false ]]; do echo "--- WAIT: On images (60)" $(date); sleep 60; done
echo "+++ INFO: Images complete" $(date)

while [[ $(hzn node list | jq '.configstate.state?=="configured"') == false ]]; do echo "--- WAIT: On configstate (60)" $(date); sleep 60; done
echo "+++ INFO: Configuration complete" $(date)

while [[ $(hzn node list | jq '.pattern?=="'"${PATTERN_ORG}/${PATTERN_ID}"'"') == false ]]; do echo "--- WAIT: On pattern (60)" $(date); sleep 60; done
echo "+++ INFO: Pattern complete" $(date)

while [[ $(hzn node list | jq '.configstate.last_update_time?!=null') == false ]]; do echo "--- WAIT: On update (60)" $(date); sleep 60; done
echo "+++ INFO: Update received" $(date)
  
echo "SUCCESS at $(date) for $(hzn node list | jq -c '.id')"

###
### KAFKACAT
###

while [[ $(hzn node list | jq '.token_valid?!=true') == false ]]; do 
  # wait on kafkacat death and re-start as long as token is valid
  echo '+++ INFO: Waiting on kafkacat -u -C -q -o end -f "%s\n" -b '$KAFKA_BROKER_URL' -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username='${KAFKA_API_KEY:0:16}'" -X "sasl.password='${KAFKA_API_KEY:16}'" -t "'$KAFKA_TOPIC'" | jq .'
  kafkacat -u -C -q -o end -f "%s\n" -b $KAFKA_BROKER_URL -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username=${KAFKA_API_KEY:0:16}" -X "sasl.password=${KAFKA_API_KEY:16}" -t "$KAFKA_TOPIC" | mosquitto_pub -l -h "core-mosquitto" -t "kafka/${KAFKA_TOPIC}"
done
