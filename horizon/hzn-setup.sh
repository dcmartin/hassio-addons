#!/bin/bash

## BASE

if [ "${VENDOR}" == "apple" ] || [ "${OSTYPE}" == "darwin" ]; then
  echo "You're on a Macintosh; download from https://github.com/open-horizon/anax/releases; exiting"
  exit
fi

if [ $(whoami) != "root" ]; then
  echo "!!! ERROR: Please run as root, e.g. sudo $0 $*"
  exit
fi

## EXCHANGE

if [ -z "${HZN_ORG_ID}" ]; then
  HZN_ORG_ID='cgiroua@us.ibm.com'
  echo "*** WARN: Using default HZN_ORG_ID=${HZN_ORG_ID}"
else
  echo "+++ INFO: Using existing HZN_ORG_ID=${HZN_ORG_ID}"
fi

if [ -z "${HZN_EXCHANGE_URL}" ]; then
  HZN_EXCHANGE_URL="https://stg-edge-cluster.us-south.containers.appdomain.cloud/v1"
  echo "*** WARN: Using default HZN_EXCHANGE_URL=${HZN_EXCHANGE_URL}"
else 
  echo "*** WARN: Using existing HZN_EXCHANGE_URL=${HZN_EXCHANGE_URL}"
fi
export HZN_EXCHANGE_URL

if [ -n "${HZN_EXCHANGE_USER_AUTH}" ]; then
  echo "*** WARN: Using existing HZN_EXCHANGE_USER_AUTH=${HZN_EXCHANGE_USER_AUTH}"
elif [ -n "${1}" ]; then
  HZN_EXCHANGE_USER_AUTH="${1}"
else
  while [ -z "${HZN_EXCHANGE_USER_AUTH}" ]; do
    read -p "${HZN_ORG_ID} username: " UN
    read -sp "Password: " PW
    if [ ! -z "${UN}" ] && [ ! -z "${PW}" ]; then 
      HZN_EXCHANGE_USER_AUTH="${UN}:${PW}"
    fi
  done
fi
echo "*** WARN: Using existing HZN_EXCHANGE_USER_AUTH=${HZN_EXCHANGE_USER_AUTH}"
export HZN_EXCHANGE_USER_AUTH


## KAFKA

KAFKA_CREDS="kafkacreds.json"
if [ -n "${2}" ] && [ -s "${2}" ]; then
  KAFKA_CREDS="${2}"
  echo "+++ INFO: Using IBM MessageHub credentials ${KAFKA_CREDS}"
elif [ ! -n "${2}" ] && [ -e "${KAFKA_CREDS}" ]; then
  echo "+++ INFO: Using IBM MessageHub credentials ${KAFKA_CREDS}"
else
  echo "Copy credentials JSON structure from from IBM Cloud $HZN_ORG_ID; and PASTE (Control-V) and then type Control-D"
  rm -f "${KAFKA_CREDS}"
  while read -r; do
    printf "%s\n" "$REPLY" >> "${KAFKA_CREDS}"
  done
fi
if [ ! -s "${KAFKA_CREDS}" ]; then
  echo "Empty ${KAFKA_CREDS}; exiting"
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
  read -p 'Architecture: ' ARCH
  if [ ! -z "${ARCH}" ]; then
    echo "+++ INFO: Specified ${ARCH}"
  else
    echo "!!! ERROR: No architecture defined; exiting"
    exit
  fi
fi

echo "+++ INFO: Using architecture: ${ARCH}"

# check apt
CMD=$(command -v apt)
if [ -z "${CMD}" ]; then
  echo "!!! ERROR: No apt(1) package installation; are you using Alpine; exiting"
  exit
fi

# warn about DNS
if [ -e "/run/systemd/resolve/resolv.conf" ]; then
  echo "*** WARN: Check your /etc/resolv.conf for link to /run/systemd/resolve/resolv.conf under Ubuntu 18.04"
fi

# install pre-requisites
for CMD in jq curl ssh kafkacat; do
  C=$(command -v $CMD)
  if [ -z "${C}" ]; then
    echo "+++ INFO: Installing ${CMD}"
    apt-get install -y ${CMD}
  fi
done

# check docker
CMD=$(command -v docker)
if [ -z "${CMD}" ]; then
  echo "*** WARN: Installing docker"
  curl -fsSL "get.docker.com" | sh
  exit
fi

###
### HORIZON
###

# CLI
CMD=$(command -v hzn)
if [ ! -z "${CMD}" ]; then
  echo "*** WARN: Open Horizon already installed as ${CMD}; skipping"
else
  # update
  # echo "+++ INFO: Updating via apt"
  # apt-get update -y
  # echo "+++ INFO: Upgrading via apt"
  # apt-get upgrade -y

  if [ ! -n "${HZN_APT_REPO}" ]; then
    HZN_APT_REPO=testing
    echo "*** WARN: Using default HZN_APT_REPO = ${HZN_APT_REPO}"
  fi
  if [ ! -n "${HZN_APT_LIST}" ]; then
    HZN_APT_LIST=/etc/apt/sources.list.d/bluehorizon.list
    echo "*** WARN: Using default HZN_APT_LIST = ${HZN_APT_LIST}"
  fi
  if [ ! -n "${HZN_PUBLICKEY_URL}" ]; then
    HZN_PUBLICKEY_URL=http://pkg.bluehorizon.network/bluehorizon.network-public.key
    echo "*** WARN: Using default HZN_PUBLICKEY_URL = ${HZN_PUBLICKEY_URL}"
  fi
  if [ -s "${HZN_APT_LIST}" ]; then
    echo "*** WARN: Existing Open Horizon ${HZN_APT_LIST}; deleting"
    rm -f "${HZN_APT_LIST}"
  fi
  # get public key and install
  echo "+++ INFO: Adding key for Open Horizon from ${HZN_PUBLICKEY_URL}"
  curl -fsSL "${HZN_PUBLICKEY_URL}" | apt-key add -
  echo "+++ INFO: Configuring Open Horizon repository ${HZN_APT_REPO} for ${ARCH}"
  # create repository entry 
  echo "deb [arch=${ARCH}] http://pkg.bluehorizon.network/linux/ubuntu xenial-${HZN_APT_REPO} main" >> "${HZN_APT_LIST}"
  echo "deb-src [arch=${ARCH}] http://pkg.bluehorizon.network/linux/ubuntu xenial-${HZN_APT_REPO} main" >> "${HZN_APT_LIST}"
  echo "+++ INFO: Updating apt(1)"
  apt-get update -y
  echo "+++ INFO: Installing Open Horizon"
  apt-get install -y horizon bluehorizon
  # confirm installation
  if [ -z $(command -v hzn) ]; then
    echo "!!! ERROR: Failed to install horizon; exiting"
    exit
  fi
fi

# LOGGING
if [ ! -n "${HZN_LOG_CONF}" ]; then
  HZN_LOG_CONF=/etc/rsyslog.d/10-horizon-docker.conf
  echo "*** WARN: Using default HZN_LOG_CONF = ${HZN_LOG_CONF}"
fi
if [ -s "${HZN_LOG_CONF}" ]; then
  echo "*** WARN: Existing logging configuration: ${HZN_LOG_CONF}; skipping"
else
  echo "+++ INFO: Configuring logging: ${HZN_LOG_CONF}"
  rm -f "${HZN_LOG_CONF}"
  echo '$template DynamicWorkloadFile,"/var/log/workload/%syslogtag:R,ERE,1,DFLT:.*workload-([^\[]+)--end%.log"' >> "${HZN_LOG_CONF}"
  echo '' >> "${HZN_LOG_CONF}"
  echo ':syslogtag, startswith, "workload-" -?DynamicWorkloadFile' >> "${HZN_LOG_CONF}"
  echo '& stop' >> "${HZN_LOG_CONF}"
  echo ':syslogtag, startswith, "docker/" -/var/log/docker_containers.log' >> "${HZN_LOG_CONF}"
  echo '& stop' >> "${HZN_LOG_CONF}"
  echo ':syslogtag, startswith, "docker" -/var/log/docker.log' >> "${HZN_LOG_CONF}"
  echo '& stop' >> "${HZN_LOG_CONF}"
  echo "+++ INFO: Restarting rsyslog(8)"
  service rsyslog restart
fi

# SERVICE ACTIVATION
HZN_SERVICE_ACTIVE=$(systemctl is-active horizon.service)
if [ $HZN_SERVICE_ACTIVE != "active" ]; then
  echo "+++ INFO: The horizon.service is not active ($HZN_SERVICE_ACTIVE); starting"
  systemctl start horizon.service
else
  echo "*** WARN: The horizon.service is already active ($HZN_SERVICE_ACTIVE)"
fi

###
### KAFKA CONFIGURATION (kafkacreds.json)
###

MSGHUB_BROKER_URL=$(jq -r '.kafka_brokers_sasl[]' "${KAFKA_CREDS}" | fmt -1024 | sed "s/ /,/g")
if [ ! -z "${MSGHUB_BROKER_URL}" ]; then
  echo "+++ INFO: MSGHUB_BROKER_URL = ${MSGHUB_BROKER_URL}"
else
  echo "!!! ERROR: MSGHUB_BROKER_URL is not defined; exiting"
  exit
fi
MSGHUB_ADMIN_URL=$(jq -r '.kafka_admin_url' "${KAFKA_CREDS}")
if [ ! -z "${MSGHUB_ADMIN_URL}" ]; then
  echo "+++ INFO: MSGHUB_ADMIN_URL = ${MSGHUB_ADMIN_URL}"
else
  echo "!!! ERROR: MSGHUB_ADMIN_URL is not defined; exiting"
  exit
fi
MSGHUB_API_KEY=$(jq -r '.api_key' "${KAFKA_CREDS}")
if [ ! -z "${MSGHUB_API_KEY}" ]; then
  echo "+++ INFO: MSGHUB_API_KEY = ${MSGHUB_API_KEY}"
else
  echo "!!! ERROR: No MessageHub API key = ${MSGHUB_API_KEY}"
  exit
fi

##
## HORIZON PATTERN SETUP
##

HZN_PATTERN_ORG_ID="IBM"
HZN_PATTERN_ID="cpu2msghub"
HZN_PATTERN_URL="https://github.com/open-horizon/examples/wiki/service-cpu2msghub"

# TOPIC
MSGHUB_TOPIC=$(echo "${HZN_ORG_ID}.${HZN_PATTERN_ORG_ID}_${HZN_PATTERN_ID}" | sed 's/@/_/g')

# get the mac address (uniqueness)  
DEVICE_MAC=$(ip addr | egrep -v NO-CARRIER | egrep -A 1 BROADCAST | egrep -v BROADCAST | sed "s/.*ether \([^ ]*\) .*/\1/g" | sed "s/://g" | head -1)
DEVICE_ID="$(hostname)-${DEVICE_MAC}"
DEVICE_TOKEN=$(echo "${HZN_EXCHANGE_USER_AUTH}" | sed 's/.*://')

echo "+++ INFO: DEVICE_ID=${DEVICE_ID}; DEVICE_TOKEN=${DEVICE_TOKEN}"

# list topics
TOPICS=$(curl -fsSL -H "X-Auth-Token: $MSGHUB_API_KEY" $MSGHUB_ADMIN_URL/admin/topics | jq '.')
TOPIC_NAMES=$(echo "${TOPICS}" | jq -j '.[]|.name," "')
echo "+++ INFO: Topics availble:"
for TN in ${TOPIC_NAMES}; do
  echo -n " ${TN}"
  if [ ${TN} == "${MSGHUB_TOPIC}" ]; then
    FOUND=true
  fi
done

if [ -z ${FOUND} ]; then
  # attempt to create a new topic
  curl -fsSL -H "X-Auth-Token: $MSGHUB_API_KEY" -d "{ \"name\": \"$MSGHUB_TOPIC\", \"partitions\": 2 }" $MSGHUB_ADMIN_URL/admin/topics
else
  echo "+++ INFO: Topic found: ${MSGHUB_TOPIC}"
fi

if [[ $(hzn node list | jq '.id?=="'"${DEVICE_ID}"'"') == false ]]; then
  INPUT="${MSGHUB_TOPIC}.json"
  if [ -s "${INPUT}" ]; then
    echo "*** WARN: Existing services registration file found: ${INPUT}; deleting"
    rm -f "${INPUT}"
  fi
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

  echo "### REGISTERING as ${DEVICE_ID} organization ${HZN_ORG_ID}) with pattern " $(jq -c '.' "${INPUT}")
  hzn register -n "${DEVICE_ID}:${DEVICE_TOKEN}" "${HZN_ORG_ID}" "${HZN_PATTERN_ORG_ID}/${HZN_PATTERN_ID}" -f "${INPUT}"
fi

while [[ $(hzn node list | jq '.id?=="'"${DEVICE_ID}"'"') == false ]]; do echo "--- WAIT: On registration (60)" $(date); sleep 60; done
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
  
echo "+++ INFO: OPERATIONAL at " $(date) $(hzn node list | jq -c '.')

while [[ $(hzn node list | jq '.token_valid?!=true') == false ]]; do 
  # wait on kafkacat death and re-start as long as token is valid
  kafkacat -C -q -o end -f "%t/%p/%o/%k: %s\n" -b $MSGHUB_BROKER_URL -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username=${MSGHUB_API_KEY:0:16}" -X "sasl.password=${MSGHUB_API_KEY:16}" -t "$MSGHUB_TOPIC"
done

exit
