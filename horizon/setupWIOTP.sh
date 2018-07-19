#!/bin/bash

##
## PRE-REQUISITES
##

WHOAMI=$(whoami)
if [ $WHOAMI != "root" ]; then
  echo "Please run this script as root; e.g. sudo $0"
  exit
fi

ACTIVE=$(systemctl is-active horizon.service)
if [ $ACTIVE != "active" ]; then
  echo "The horizon.service is not active ($ACTIVE)"
  exit
else
  echo "The horizon.service is already active ($ACTIVE)"
fi

ARCH=$(dpkg --print-architecture)
if [ $ARCH != "amd64" ]; then
  if [ $ARCH != "arm64" ]; then
    echo "Architecture $ARCH unsupported by this script"
    exit
  fi
fi

##
## UNREGISTER AND UNINSTALL BLUEHORIZON
##

hzn unregister -f
apt purge bluehorizon bluehorizon-ui

mkdir ~/certs
wget -O ~/certs/messaging.pem https://raw.githubusercontent.com/ibm-watson-iot/iot-python/master/src/ibmiotf/messaging.pem


##
## DOCKER
##

sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=$ARCH] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce

##
## HORIZON
##

wget -qO - http://pkg.bluehorizon.network/bluehorizon.network-public.key | apt-key add -

cat << EOF > /etc/apt/sources.list.d/bluehorizon.list
deb [arch=$ARCH] http://pkg.bluehorizon.network/linux/ubuntu xenial-updates main
deb-src [arch=$ARCH] http://pkg.bluehorizon.network/linux/ubuntu xenial-updates main
EOF

apt update && apt install horizon-wiotp


##
## SYSLOG
##

cat << EOF > /etc/rsyslog.d/10-horizon-docker.conf
$template DynamicWorkloadFile,"/var/log/workload/%syslogtag:R,ERE,1,DFLT:.*workload-([^\[]+)--end%.log"

:syslogtag, startswith, "workload-" -?DynamicWorkloadFile
& stop
:syslogtag, startswith, "docker/" -/var/log/docker_containers.log
& stop
:syslogtag, startswith, "docker" -/var/log/docker.log
& stop
EOF

service rsyslog restart

systemctl start horizon.service
