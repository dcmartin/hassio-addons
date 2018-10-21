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

##
## time zone
##
VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="GMT"; fi
echo "Setting TIMEZONE ${VALUE}" >&2
cp /usr/share/zoneinfo/${VALUE} /etc/localtime
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

## HORIZON OPTIONS
JSON="${JSON}"',"horizon":{'
# URL
VALUE=$(jq -r ".horizon.exchange" "${CONFIG_PATH}")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  echo "Using default horizon exchange: ${HZN_EXCHANGE_URL}"
  VALUE="${HZN_EXCHANGE_URL}"
else
  export HZN_EXCHANGE_URL="${VALUE}"
  echo "Setting HZN_EXCHANGE_URL to ${VALUE}" >&2
fi
JSON="${JSON}"',"exchange":"'"${VALUE}"'"'
# USERNAME
VALUE=$(jq -r ".horizon.username" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No exchange username"; exit; fi
echo "Setting HZN_EXCHANGE_USERNAME ${VALUE}" >&2
JSON="${JSON}"',"username":"'"${VALUE}"'"'
export HZN_EXCHANGE_USERNAME="${VALUE}"
# PASSWORD
VALUE=$(jq -r ".horizon.password" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No exchange password"; exit; fi
echo "Setting HZN_EXCHANGE_PASSWORD [redacted]" >&2
JSON="${JSON}"',"password":"'"${VALUE}"'"'
export HZN_EXCHANGE_PASSWORD="${VALUE}"
# ORGANIZATION
VALUE=$(jq -r ".horizon.organization" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No horizon organization"; exit; fi
echo "Setting HZN_ORG_ID ${VALUE}" >&2
JSON="${JSON}"',"organization":"'"${VALUE}"'"'
export HZN_ORG_ID="${VALUE}"
# DEVICE
VALUE=$(jq -r ".horizon.device" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No horizon device"; exit; fi
echo "Setting HZN_DEVICE_ID ${VALUE}" >&2
JSON="${JSON}"',"device":"'"${VALUE}"'"'
export HZN_DEVICE_ID="${VALUE}"
# TOKEN
VALUE=$(jq -r ".horizon.token" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No horizon device token"; exit; fi
echo "Setting HZN_DEVICE_TOKEN ${VALUE}" >&2
JSON="${JSON}"',"token":"'"${VALUE}"'"'
export HZN_DEVICE_TOKEN="${VALUE}"
## DONE w/ horizon
JSON="${JSON}"'}'

## KAFKA OPTIONS
JSON="${JSON}"',"kafka":{'
# BROKERS_SASL
VALUE=$(jq -r '.kafka.kafka_brokers_sasl' "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No kafka kafka_brokers_sasl"; exit; fi
JSON="${JSON}"',"brokers_sasl":"'"${VALUE}"'"'
export MSGHUB_BROKER_URL=$(echo "${VALUE}" | jq -j '.[]|.,","')
# ADMIN_URL
VALUE=$(jq -r '.kafka.kafka_admin_url' "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No kafka kafka_admin_url"; exit; fi
JSON="${JSON}"',"admin_url":"'"${VALUE}"'"'
export MSGHUB_ADMIN_URL="${VALUE}"
# API_KEY
VALUE=$(jq -r '.kafka.api_key' "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then echo "No kafka api_key"; exit; fi
JSON="${JSON}"',"api_key":"'"${VALUE}"'"}'
export MSGHUB_API_KEY="${VALUE}"
## DONE w/ kakfa
JSON="${JSON}"'}'

echo "+++ INFO: KAFKA at ${MSGHUB_ADMIN_URL}; brokers ${MSGHUB_BROKER_URL}; api_key ${MSGHUB_API_KEY}"

## FROM Dockerfile

if [ -z "${HZN_PATTERN_ORG_ID}" ]; then HZN_PATTERN_ORG_ID="IBM"; fi
JSON="${JSON}"',"pattern_org_id":"'"${HZN_PATTERN_ORG_ID}"'"}'

if [ -z "${HZN_PATTERN_ID}" ]; then HZN_PATTERN_ID="cpu2msghub"; fi
JSON="${JSON}"',"pattern_id":"'"${HZN_PATTERN_ID}"'"}'

if [ -z "${HZN_PATTERN_URL}" ]; then HZN_PATTERN_URL="https://github.com/open-horizon/examples/wiki/service-cpu2msghub"; fi
JSON="${JSON}"',"pattern_url":"'"${HZN_PATTERN_URL}"'"}'

echo "+++ INFO: HORIZON device ${HZN_DEVICE_ID} in ${HZN_ORG_ID} using pattern ${HZN_PATTERN_ORG_ID}/${HZN_PATTERN_ID} @ ${HZN_PATTERN_URL}"

MSGHUB_TOPIC=$(echo "${HZN_ORG_ID}.${HZN_PATTERN_ORG_ID}_${HZN_PATTERN_ID}" | sed 's/@/_/g')
INPUT="${MSGHUB_TOPIC}.json"
rm -f "${INPUT}"

echo '{' >> "${INPUT}"
echo '  "services": [' >> "${INPUT}"
echo '    {' >> "${INPUT}"
echo '      "org": "'"${HZN_PATTERN_ORG_ID}"'",' >> "${INPUT}"
echo '      "url": "'"${HZN_PATTERN_URL}"'",' >> "${INPUT}"
echo '      "versionRange": "[0.0.0,INFINITY)",' >> "${INPUT}"
echo '      "variables": {' >> "${INPUT}"
echo '        "MSGHUB_API_KEY": "'"${MSGHUB_API_KEY}"'"' >> "${INPUT}"
echo '      }' >> "${INPUT}"
echo '    }' >> "${INPUT}"
echo '  ]' >> "${INPUT}"
echo '}' >> "${INPUT}"

echo "+++ INFO: Registering with JSON payload: " $(jq -c '.' "${INPUT}")

### INSTALL HORIZON 

HZN=$(command -v hzn)
if [ -z "${HZN}" ]; then
  curl -s -L0 "${HZN_PUBLICKEY_URL}" | apt-key add -
  echo "deb [arch=${BUILD_ARCH}] http://pkg.bluehorizon.network/linux/ubuntu xenial-${HZN_APT_REPO} main" >> "${HZN_APT_LIST}"
  echo "deb-src [arch=${BUILD_ARCH}] http://pkg.bluehorizon.network/linux/ubuntu xenial-${HZN_APT_REPO} main" >> "${HZN_APT_LIST}"
  apt-get update -y
  apt-get install -y horizon
fi

if [[ $(hzn node list | jq '.id?=="'"${HZN_DEVICE_ID}"'"') == false ]]; then
  echo "+++ INFO: Registering ${HZN_DEVICE_ID}" $(date)
  hzn register -n "${HZN_DEVICE_ID}:${HZN_DEVICE_TOKEN}" "${HZN_ORG_ID}" "${PATTERN_ORG_ID}/${PATTERN}" -f "${INPUT}"
fi

# {
#   "id": "horizon-000c295b1394",
#   "organization": "cgiroua@us.ibm.com",
#   "pattern": "IBM/cpu2msghub",
#   "name": "horizon-000c295b1394",
#   "token_last_valid_time": "2018-10-19 12:19:07 -0700 PDT",
#   "token_valid": true,
#   "ha": false,
#   "configstate": {
#     "state": "configured",
#     "last_update_time": "2018-10-19 12:19:11 -0700 PDT"
#   },
#   "configuration": {
#     "exchange_api": "https://stg-edge-cluster.us-south.containers.appdomain.cloud/v1/",
#     "exchange_version": "1.61.0",
#     "required_minimum_exchange_version": "1.60.0",
#     "preferred_exchange_version": "1.60.0",
#     "architecture": "amd64",
#     "horizon_version": "2.18.1"
#   },
#   "connectivity": {
#     "firmware.bluehorizon.network": true,
#     "images.bluehorizon.network": true
#   }
# }

while [[ $(hzn node list | jq '.id?=="'"${HZN_DEVICE_ID}"'"') == false ]]; do echo "--- WAIT: On registration (60)" $(date); sleep 60; done
echo "+++ INFO: Registration complete" $(date)

while [[ $(hzn node list | jq '.connectivity."firmware.bluehorizon.network"?==true') == false ]]; do echo "--- WAIT: On firmware (60)" $(date); sleep 60; done
echo "+++ INFO: Firmware complete" $(date)

while [[ $(hzn node list | jq '.connectivity."images.bluehorizon.network"?==true') == false ]]; do echo "--- WAIT: On images (60)" $(date); sleep 60; done
echo "+++ INFO: Images complete" $(date)

while [[ $(hzn node list | jq '.configstate.state?=="configured"') == false ]]; do echo "--- WAIT: On configstate (60)" $(date); sleep 60; done
echo "+++ INFO: Configuration complete" $(date)

while [[ $(hzn node list | jq '.pattern?=="'"${HZN_PATTERN_ORG_ID}/${HZN_PATTERN_ID}"'"') == false ]]; do echo "--- WAIT: On pattern (60)" $(date); sleep 60; done
echo "+++ INFO: Pattern complete" $(date)

while [[ $(hzn node list | jq '.configstate.last_update_time?!=null') == false ]]; do echo "--- WAIT: On update (60)" $(date); sleep 60; done
echo "+++ INFO: Update received" $(date)

while [[ $(hzn node list | jq '.token_valid?!=true') == false ]]; do 
  echo "+++ INFO: Nodes at " $(date) $(hzn node list | jq -c '.')
  echo "--- WAIT: On invalid token (300)"
  sleep 300
done

exit
