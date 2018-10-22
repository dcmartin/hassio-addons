#!/bin/bash

## BASE

if [ "${VENDOR}" == "apple" ] || [ "${OSTYPE}" == "darwin" ]; then
  echo "You're on a Macintosh; download from https://github.com/open-horizon/anax/releases; exiting"
  exit
fi

if [ $(whoami) != "root" ]; then
  echo "!!! ERROR: Please run as root, e.g. sudo $*"
  exit
fi

ACTIVE=$(systemctl is-active horizon.service)
if [ $ACTIVE != "active" ]; then
  echo "+++ INFO: The horizon.service is not active ($ACTIVE)"
else
  echo "!!! ERROR: The horizon.service is already active ($ACTIVE); exiting"
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

# fix DNS
if [ -e "/run/systemd/resolve/resolv.conf" ]; then
  echo "*** WARN: Check your /etc/resolv.conf for link to /run/systemd/resolve/resolv.conf under Ubuntu 18.04"
fi

# check apt
CMD=$(command -v apt)
if [ -z "${CMD}" ]; then
  echo "!!! ERROR: No apt(1) package installation; are you using Alpine; exiting"
  exit
fi

# update
echo "+++ INFO: Updating via apt"
apt-get update -y

echo "+++ INFO: Upgrading via apt"
apt-get upgrade -y

# install jq
CMD=$(command -v jq)
if [ -z "${CMD}" ]; then
  echo "+++ INFO: Installing jq"
  apt-get install -y jq
fi

# install curl
CMD=$(command -v curl)
if [ -z "${CMD}" ]; then
  echo "+++ INFO: Installing curl"
  apt-get install -y curl
fi

# install ssh
CMD=$(command -v ssh)
if [ -z "${CMD}" ]; then
  echo "+++ INFO: Installing ssh"
  apt-get install -y ssh
fi

# install docker
CMD=$(command -v docker)
if [ -z "${CMD}" ]; then
  echo "+++ INFO: Installing docker"
  curl -fsSL get.docker.com | sh
fi

###
### HORIZON
###

# must register and get access to exchange

if [ ! -n "${HZN_EXCHANGE_URL}" ]; then
  HZN_EXCHANGE_URL='https://stg-edge-cluster.us-south.containers.appdomain.cloud/v1'
  echo "*** WARN: Using default HZN_EXCHANGE_URL = ${HZN_EXCHANGE_URL}"
else
  echo "+++ INFO: Using HZN_EXCHANGE_URL from environment"
fi
if [ ! -n "${HZN_ORG_ID}" ]; then
  HZN_ORG_ID='cgiroua@us.ibm.com'
  echo "*** WARN: Using default HZN_ORG_ID = ${HZN_ORG_ID}"
else
  echo "+++ INFO: Using HZN_ORG_ID from environment"
fi

# CHECK REPOSITORY

if [ ! -n "${HZN_APT_REPO}" ]; then
  HZN_APT_REPO=testing
  echo "*** WARN: Using default HZN_APT_REPO = ${HZN_APT_REPO}"
fi
if [ ! -n "${HZN_APT_LIST}" ]; then
  HZN_APT_LIST=/etc/apt/sources.list.d/bluehorizon.list
  echo "*** WARN: Using default HZN_APT_LIST = ${HZN_APT_LIST}"
fi
if [ ! -n "${HZN_LOG_CONF}" ]; then
  HZN_LOG_CONF=/etc/rsyslog.d/10-horizon-docker.conf
  echo "*** WARN: Using default HZN_LOG_CONF = ${HZN_LOG_CONF}"
fi
if [ ! -n "${HZN_PUBLICKEY_URL}" ]; then
  HZN_PUBLICKEY_URL=http://pkg.bluehorizon.network/bluehorizon.network-public.key
  echo "*** WARN: Using default HZN_PUBLICKEY_URL = ${HZN_PUBLICKEY_URL}"
fi

if [ -s "${HZN_APT_LIST}" ]; then
  echo "*** WARN: Existing Open Horizon ${HZN_APT_LIST}; deleting"
  rm -f "${HZN_APT_LIST}"
fi

CMD=$(command -v hzn)
if [ ! -z "${CMD}" ]; then
  echo "*** WARN: Open Horizon already installed as ${CMD}; skipping"
else
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
  if [ -z $(command -v hzn) ]; then
    echo "!!! ERROR: Failed to install horizon; exiting"
    exit
  fi
  echo "+++ INFO: Starting horizon"
  systemctl start horizon.service
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

###
### MESSAGE HUB (run.sh)
###

## KAFKA +++ INFORMATION (from ORG credentials)

KAFKA_CREDS="kafkacreds.json"
if [ -n "${1}" ] && [ -s "${1}" ]; then
  KAFKA_CREDS="jq -c '.' ${1}"
elif [ ! -n "${1}" ] && [ ! -e "${KAFKA_CREDS}" ]; then
  echo "Specify credentials file copied from MessageHub for $HZN_ORG_ID, e.g. $* ./kafkacreds.json; exiting"
  exit
elif [ -n ${CONFIG_PATH} ] && [ -s ${CONFIG_PATH} ]; then
  jq '.kafka' ${CONFIG_PATH} > kafkacreds.json
fi

if [ -z "${KAFKA_CREDS}" ]; then
  echo "Empty ${KAFKA_CREDS}; exiting"
  exit
fi

echo "+++ INFO: KAFKA MESSAGE HUB"

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

# USERNAME and PASSWORD

if [ ! -n "${HZN_EXCHANGE_USER_AUTH}" ]; then
  echo "### Enter username for organization ${HZN_ORG_ID} to access exchange: ${HZN_EXCHANGE_URL}"
  # get login information
  read -p 'Username: ' HZN_EXCHANGE_USERNAME
  read -sp 'Password: ' HZN_EXCHANGE_PASSWORD
  HZN_EXCHANGE_USER_AUTH="${HZN_EXCHANGE_USERNAME}:${HZN_EXCHANGE_PASSWORD}"
else
  echo "+++ INFO: Using HZN_EXCHANGE_USER_AUTH from environment"
fi

##
## PATTERN SETUP
##

HZN_PATTERN_ORG_ID="IBM"
HZN_PATTERN_ID="cpu2msghub"
HZN_PATTERN_URL="https://github.com/open-horizon/examples/wiki/service-cpu2msghub"
MSGHUB_TOPIC=$(echo "${HZN_ORG_ID}.${HZN_PATTERN_ORG_ID}_${HZN_PATTERN_ID}" | sed 's/@/_/g')
echo "### TOPIC SELECTED == ${MSGHUB_TOPIC}"
  
MAC=$(ip addr | egrep -v NO-CARRIER | egrep -A 1 BROADCAST | egrep -v BROADCAST | sed "s/.*ether \([^ ]*\) .*/\1/g" | sed "s/://g")

HZN_DEVICE_ID="$(hostname)-${MAC}"
HZN_DEVICE_TOKEN='whocares'
echo "+++ INFO: HZN_DEVICE_ID = ${HZN_DEVICE_ID}"
echo "+++ INFO: HZN_DEVICE_TOKEN = ${HZN_DEVICE_TOKEN}"

## try to get topics
TOPICS=$(curl -L -s -q -H "X-Auth-Token: $MSGHUB_API_KEY" $MSGHUB_ADMIN_URL/admin/topics | jq -c '.')
TOPIC_NAMES=$(echo "${TOPICS}" | jq -j '.[]|.name," "')
echo "### FOUND TOPICS: ${TOPIC_NAMES}"

# attempt to create a new topic
JSON=$(curl -H "X-Auth-Token: $MSGHUB_API_KEY" -d "{ \"name\": \"$MSGHUB_TOPIC\", \"partitions\": 2 }" $MSGHUB_ADMIN_URL/admin/topics | jq -c '.')
echo "### TOPIC RESPONSE: ${JSON}"


if [[ $(hzn node list | jq '.id?=="'"${HZN_DEVICE_ID}"'"') == false ]]; then
  INPUT="${MSGHUB_TOPIC}.json"
  if [ -s "${INPUT}" ]; then
    echo -n "*** WARN: Existing services registration file found: ${INPUT}; deleting"
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

  echo "### REGISTERING as ${HZN_DEVICE_ID} organization ${HZN_ORG_ID}) with pattern " $(jq -c '.' "${INPUT}")
  hzn register -n "${HZN_DEVICE_ID}:${HZN_DEVICE_TOKEN}" "${HZN_ORG_ID}" "${HZN_PATTERN_ORG_ID}/${HZN_PATTERN_ID}" -f "${INPUT}"
fi

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
  kafkacat -C -q -o end -f "%t/%p/%o/%k: %s\n" -b $MSGHUB_BROKER_URL -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username=${MSGHUB_API_KEY:0:16}" -X "sasl.password=${MSGHUB_API_KEY:16}" -t "$MSGHUB_TOPIC"

  echo "--- WAIT: On invalid token (300)"
  sleep 300
done

exit
