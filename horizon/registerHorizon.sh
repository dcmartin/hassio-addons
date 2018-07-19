#!/bin/bash 

export ORG=public
export NODE_ID=$(hostname)
export NODE_TOKEN="whocares"
export USERNAME="dcmartin"
export PASSWORD="whocares"
export EMAIL="horizon@dcmartin.com"
# KELIS POND - 37.174612, -121.816487
# MT UMUNUM - 37.160560, -121.897549
# IBM ALMADEN - 37.211682,-121.808543
# IBM SAN FRANCISCO - 37.791447, -122.398156
# IBM SILICON VALLEY LAB - 37.195937, -121.748065
export LATITUDE="37.195937"
export LONGITUDE="-121.748065"

ACTIVE=$(systemctl is-active horizon.service)
if [ $ACTIVE != "active" ]; then
  echo "The horizon.service is not active ($ACTIVE); please run setup script"
  exit
else
  echo "The horizon.service is $ACTIVE"
fi

NODE=$(hzn node list)
if [ -z "${NODE}" ]; then
  hzn exchange node create -u $USERNAME:$PASSWORD -e $EMAIL -n $NODE_ID:$NODE_TOKEN -o $ORG
else
  echo -n "Node $NODE_ID exists with pattern: "
  echo "${NODE}" | jq '.pattern'
fi

JSON=$(mktemp).json
cat > $JSON << EOF
{
  "global": [
    {
      "type": "LocationAttributes",
      "variables": {
        "lat": $LATITUDE,
        "lon": $LONGITUDE,
        "use_gps": false,
        "location_accuracy_km": 0.01
      }
    }
  ]
}
EOF

ARCH=$(arch)
if [ $ARCH == "x86_64" ]; then
  ARCH="amd64"
elif [ $ARCH == "arm71" ]; then
  ARCH="arm"
else
  echo "No matching patterns for architecture ($ARCH)"
  exit
fi
PATTERNS=$(hzn exchange pattern list --user-pw $NODE_ID:$NODE_TOKEN -o $ORG --names-only | jq -r '.[]' | sed "s@$ORG/@@" | egrep "$ARCH")
echo "Available patterns"
echo "$PATTERNS"
echo "========="
export PATTERN=netspeed-$ARCH

AGREEMENTS=$(hzn agreement list)
NAGREEMENT=$(echo "${AGREEMENTS}" | jq '.|length')
if [ $NAGREEMENT -gt 0 ]; then
  echo "NODE $NODE_ID has $NAGREEMENT existing agreements; run 'hzn unregister' and run $0 again"
  echo "${AGREEMENTS}" | jq '.[].name'
  # hzn unregister
else
  echo "Using pattern: $PATTERN"
  hzn register -u $USERNAME:$PASSWORD -n $NODE_ID:$NODE_TOKEN -f $JSON $ORG $PATTERN
fi

