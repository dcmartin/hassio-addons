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

if [ -z "${ORGID}" ]; then
  ORGID='cgiroua@us.ibm.com'
  echo "*** WARN: Using default ORGID=${ORGID}"
else
  echo "+++ INFO: Using existing ORGID=${ORGID}"
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
    read -p "${ORGID} username: " UN
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
  echo "OPEN LINK: https://console.bluemix.net/services/messagehub/b5f8df99-d3f6-47b8-b1dc-12806d63ae61/?paneId=credentials&new=true&env_id=ibm:yp:us-south&org=51aea963-6924-4a71-81d5-5f8c313328bd&space=f965a097-fcb8-4768-953e-5e86ea2d66b4"
  echo "COPY credentials JSON structure from from IBM Cloud $ORGID; and PASTE and then type Control-D"
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
  ARCH="amd64"
elif [ "${ARCH}" == "armv71" ]; then
  ARCH="arm"
else
  echo "Cannot automagically identify architecture (${ARCH}); options are: arm, arm64, amd64, ppc64el"
  read -p 'Architecture: ' ARCH
  if [ -n "${ARCH}" ]; then
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

  if [ ! -n "${APT_REPO}" ]; then
    APT_REPO=testing
    echo "*** WARN: Using default APT_REPO = ${APT_REPO}"
  fi
  if [ ! -n "${APT_LIST}" ]; then
    APT_LIST=/etc/apt/sources.list.d/bluehorizon.list
    echo "*** WARN: Using default APT_LIST = ${APT_LIST}"
  fi
  if [ ! -n "${PUBLICKEY_URL}" ]; then
    PUBLICKEY_URL=http://pkg.bluehorizon.network/bluehorizon.network-public.key
    echo "*** WARN: Using default PUBLICKEY_URL = ${PUBLICKEY_URL}"
  fi
  if [ -s "${APT_LIST}" ]; then
    echo "*** WARN: Existing Open Horizon ${APT_LIST}; deleting"
    rm -f "${APT_LIST}"
  fi
  # get public key and install
  echo "+++ INFO: Adding key for Open Horizon from ${PUBLICKEY_URL}"
  curl -fsSL "${PUBLICKEY_URL}" | apt-key add -
  echo "+++ INFO: Configuring Open Horizon repository ${APT_REPO} for ${ARCH}"
  # create repository entry 
  echo "deb [arch=${ARCH}] http://pkg.bluehorizon.network/linux/ubuntu xenial-${APT_REPO} main" >> "${APT_LIST}"
  echo "deb-src [arch=${ARCH}] http://pkg.bluehorizon.network/linux/ubuntu xenial-${APT_REPO} main" >> "${APT_LIST}"
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
if [ -z "${LOG_CONF}" ]; then
  LOG_CONF=/etc/rsyslog.d/10-horizon-docker.conf
  echo "*** WARN: Using default LOG_CONF = ${LOG_CONF}"
fi
if [ -s "${LOG_CONF}" ]; then
  echo "*** WARN: Existing logging configuration: ${LOG_CONF}; skipping"
else
  echo "+++ INFO: Configuring logging: ${LOG_CONF}"
  rm -f "${LOG_CONF}"
  echo '$template DynamicWorkloadFile,"/var/log/workload/%syslogtag:R,ERE,1,DFLT:.*workload-([^\[]+)--end%.log"' >> "${LOG_CONF}"
  echo '' >> "${LOG_CONF}"
  echo ':syslogtag, startswith, "workload-" -?DynamicWorkloadFile' >> "${LOG_CONF}"
  echo '& stop' >> "${LOG_CONF}"
  echo ':syslogtag, startswith, "docker/" -/var/log/docker_containers.log' >> "${LOG_CONF}"
  echo '& stop' >> "${LOG_CONF}"
  echo ':syslogtag, startswith, "docker" -/var/log/docker.log' >> "${LOG_CONF}"
  echo '& stop' >> "${LOG_CONF}"
  echo "+++ INFO: Restarting rsyslog(8)"
  service rsyslog restart
fi

# SERVICE ACTIVATION
if [ $(systemctl is-active horizon.service) != "active" ]; then
  echo "+++ INFO: The horizon.service is not active; starting"
  systemctl start horizon.service
else
  echo "*** WARN: The horizon.service is already active"
fi

##
## HORIZON PATTERN SETUP
##

PATTERN_ORG="IBM"
PATTERN_ID="cpu2msghub"
PATTERN_URL="https://github.com/open-horizon/examples/wiki/service-cpu2msghub"

# TOPIC
KAFKA_TOPIC=$(echo "${ORGID}.${PATTERN_ORG}_${PATTERN_ID}" | sed 's/@/_/g')

###
### KAFKA CONFIGURATION (kafkacreds.json)
###

KAFKA_BROKER_URL=$(jq -r '.kafka_brokers_sasl[]' "${KAFKA_CREDS}" | fmt -1024 | sed "s/ /,/g")
if [ ! -z "${KAFKA_BROKER_URL}" ]; then
  echo "+++ INFO: KAFKA_BROKER_URL = ${KAFKA_BROKER_URL}"
else
  echo "!!! ERROR: KAFKA_BROKER_URL is not defined; exiting"
  exit
fi
KAFKA_ADMIN_URL=$(jq -r '.kafka_admin_url' "${KAFKA_CREDS}")
if [ ! -z "${KAFKA_ADMIN_URL}" ]; then
  echo "+++ INFO: KAFKA_ADMIN_URL = ${KAFKA_ADMIN_URL}"
else
  echo "!!! ERROR: KAFKA_ADMIN_URL is not defined; exiting"
  exit
fi
KAFKA_API_KEY=$(jq -r '.api_key' "${KAFKA_CREDS}")
if [ ! -z "${KAFKA_API_KEY}" ]; then
  echo "+++ INFO: KAFKA_API_KEY = ${KAFKA_API_KEY}"
else
  echo "!!! ERROR: No MessageHub API key = ${KAFKA_API_KEY}"
  exit
fi

# list topics
TOPICS=$(curl -fsSL -H "X-Auth-Token: $KAFKA_API_KEY" $KAFKA_ADMIN_URL/admin/topics | jq '.')
TOPIC_NAMES=$(echo "${TOPICS}" | jq -j '.[]|.name," "')
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

## DEVICE IDENTIFICATION & AUTHENTICATION

# MAC address of first operational ethernet
DEVICE_MAC=$(ip addr | egrep -v NO-CARRIER | egrep -A 1 BROADCAST | egrep -v BROADCAST | sed "s/.*ether \([^ ]*\) .*/\1/g" | sed "s/://g" | head -1)
# Unique identifier for this device (hopefully)
DEVICE_ID="$(hostname)-${DEVICE_MAC}"
# Re-use of password from exchange user authentication "<username>:<password>"
DEVICE_TOKEN=$(echo "${HZN_EXCHANGE_USER_AUTH}" | sed 's/.*://')

echo "+++ INFO: DEVICE_ID=${DEVICE_ID}; DEVICE_TOKEN=${DEVICE_TOKEN}"

###
### REGISTRATION
###

NODE_LIST=$(hzn node list)
if [ -n "${NODE_LIST}" ]; then
  DEVICE_REG=$(echo "${NODE_LIST}" | jq '.id?=="'"${DEVICE_ID}"'"')
fi
if [ "${DEVICE_REG}" == "true" ]; then
    echo "### ALREADY REGISTERED as ${DEVICE_ID} organization ${ORGID}"
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

  echo "### REGISTERING as ${DEVICE_ID} organization ${ORGID}) with pattern " $(jq -c '.' "${INPUT}")
  hzn register -n "${DEVICE_ID}:${DEVICE_TOKEN}" "${ORGID}" "${PATTERN_ORG}/${PATTERN_ID}" -f "${INPUT}"
fi

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

echo -n "(W)ait forever on KafkaCat messages (W/n)? "
while read -r -n 1 -s answer; do
  if [[ $answer = [NnWw] ]]; then
    [[ $answer = [Nn] ]] && retval=0
    [[ $answer = [Ww] ]] && retval=1
    break
  fi
done
if [[ $reval == 1 ]]; then
  while [[ $(hzn node list | jq '.token_valid?!=true') == false ]]; do 
    # wait on kafkacat death and re-start as long as token is valid
    kafkacat -C -q -o end -f "%t/%p/%o/%k: %s\n" -b $KAFKA_BROKER_URL -X "security.protocol=sasl_ssl" -X "sasl.mechanisms=PLAIN" -X "sasl.username=${KAFKA_API_KEY:0:16}" -X "sasl.password=${KAFKA_API_KEY:16}" -t "$KAFKA_TOPIC"
  done
  echo ""
fi

###
### HOME ASSISTANT
###

echo -n "(I)nstall Home-Assistant (I/n)? "
while read -r -n 1 -s answer; do
  if [[ $answer = [NnIi] ]]; then
    [[ $answer = [Nn] ]] && retval=0
    [[ $answer = [Ii] ]] && retval=1
    break
  fi
done
echo ""
if [[ $retval == 1 ]]; then
  # install hassio
  curl -fsSL https://raw.githubusercontent.com/home-assistant/hassio-build/master/install/hassio_install | bash -s
  echo "Home-Assistant installation running in background"
  DEVICE_IP=$(ip addr | egrep -A 2 BROADCAST | egrep inet | sed 's|.*inet \(.*\)/.*|\1|' | head -1)
  echo "Home Assistant setting up; http://127.0.0.1:8123/, http://${DEVICE_IP}:8123/ or http://$(hostname).local:8123/"
fi
