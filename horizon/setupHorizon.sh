#!/bin/bash

WHOAMI=$(whoami)
if [ $WHOAMI != "root" ]; then
  echo "Please run this script as root; e.g. sudo $0"
  exit
fi

ACTIVE=$(systemctl is-active horizon.service)
if [ $ACTIVE != "active" ]; then
  echo "The horizon.service is not active ($ACTIVE)"
else
  echo "The horizon.service is already active ($ACTIVE)"
  exit
fi

ARCH=$(arch|sed "s/.*86.*/amd64/")
if [ $ARCH != "amd64" ]; then
  ARCH=$(arch|sed "s/.*arm.*/arm64/")
  if [ $ARCH != "arm64" ]; then
    echo "Architecture $ARCH unsupported by this script"
    exit
  fi
fi

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

apt-get update

apt-get install -y horizon bluehorizon bluehorizon-ui

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
