#!/bin/bash
url="https://alpha.edge-fabric.com/v1/orgs/dcmartin@us.ibm.com/nodes"
key="dcmartin@us.ibm.com/iamapikey:Kq65Z9rfOQvPpx1fU1_BxdzXsGbp_0E8nrlVFYX0F9Vi"
result=$(curl -sL "$url" -u "$key")
if [[ $(echo "${result}" | jq '.nodes==null') == 'false' ]]; then
  nodes=$(echo "${result}" | jq '.nodes')
  names=$(echo "${nodes}" | jq '[ . | objects | keys[]] | unique' | jq -r '.[]')
  i=0
  echo '{"nodes":[' 
  for name in $names; do
    if [ $i -gt 0 ]; then echo ','; fi; i=$((i+1))
    echo "${nodes}" | jq '."'"${name}"'"|.id="'${name}'"'
  done 
  echo ']}'
else
  echo 'null'
fi
