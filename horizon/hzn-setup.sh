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
elif [ "${ARCH}" == "armv7l" ]; then
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

exit
