#!/bin/bash
APP="horizon"
API="test"

if [ -z ${TMP:-} ]; then TMP="/tmpfs"; fi
if [ -z ${LOGTO:-} ]; then LOGTO=$TMP/$APP.log; fi

if [ -n ${DEBUG:-} ]; then echo `date` "$0 $$ -- START" >> $LOGTO 2>&1; fi

CU="${HORIZON_CLOUDANT_URL}"

###
### dateutils REQUIRED
###

if [ -e /usr/bin/dateutils.dconv ]; then
   dateconv=/usr/bin/dateutils.dconv
elif [ -e /usr/bin/dateconv ]; then
   dateconv=/usr/bin/dateconv
elif [ -e /usr/local/bin/dateconv ]; then
   dateconv=/usr/local/bin/dateconv
else
  echo "No date converter; install dateutils" &> /dev/stderr
  exit 1
fi

# don't update statistics more than once per (in seconds)
TTL=30
SECONDS=`date "+%s"`
DATE=`echo $SECONDS \/ $TTL \* $TTL | bc`

if [ -n ${QUERY_STRING:-} ]; then
    db=`echo "$QUERY_STRING" | sed 's/.*db=\([^&]*\).*/\1/'`
    if [ $db == "$QUERY_STRING" ]; then db=""; fi
fi

if [ -z ${db:-} ]; then db="all"; fi

# standardize QUERY_STRING (rendezvous w/ APP-make-API.csh script)
export QUERY_STRING="db=$db"

##
## ACCESS CLOUDANT
##

# output target
OUTPUT="$TMP/$APP-$API-$QUERY_STRING.$DATE.json"
# test if been-there-done-that
if [ ! -s "$OUTPUT" ]; then 
  rm -f "${OUTPUT%.*}".*

  # find devices
  if [ $db == "all" ]; then
    devices=`curl -s -q -L "$CU/$HORIZON_DEVICE_DB/_all_docs" | jq -r '.rows[]?.id'`
    if [ -z ${devices} ]; then
      if [ -n ${DEBUG:-} ]; then echo `date` "$0 $$ ++ Could not retrieve list of devices from ($url)" >> $LOGTO 2>&1; fi
      goto done
    fi
  else
    devices=$db
  fi

  if [ -n ${DEBUG:-} ]; then echo `date` "$0 $$ ++ Devices in DB ($devices)" >> $LOGTO 2>&1; fi

  k=0
  all='{"date":'"$DATE"',"devices":['

  for d in $devices; do
    # get device entry
    url="$CU/$HORIZON_DEVICE_DB/$d"
    out="$TMP/$APP-$API-$$.json"
    curl -sL "$url" -o "$out"
    if [ ! -e "$out" ]; then
      if [ -n ${DEBUG:-} ]; then echo `date` "$0 $$ ++ FAILURE ($d)" `ls -al $out` >> $LOGTO 2>&1; fi
      rm -f "$out"
      continue
    fi
    if [ $db == "all" && $d == "$db" ]; then
      jq '{"hostname":.hostname,"date":.date,"host_ipaddr":.host_ipaddr,"arch":.arch}' "$out" > "$OUTPUT"
      rm -f "$out"
      break
    elif [ $db == "all" ]; then
      json=`jq '{"name":.name,"date":.date}' "$out"`
      rm -f "$out"
    else
      json=""
    fi
    if [ $k -gt 0 ]; then all="$all"','; fi
    k=$((k+1))
    if [ -n ${json:-} ]; then all="${all}${json}"; fi
  done
  all="$all"']}'
fi

if [ ! -s "${OUTPUT}" ]; then
  echo "$all" | jq -c '.' > "$OUTPUT"
fi

#
# output
#

echo "Content-Type: application/json; charset=utf-8"
echo "Access-Control-Allow-Origin: *"

if [ -z ${output:-} ] && [ -s "$OUTPUT" ]; then
  age=$((SECONDS - DATE))
  echo "Age: $age"
  refresh=$((TTL - age))
  # check back if using old
  if [ $refresh -lt 0 ]; then refresh=$TTL; fi
  echo "Refresh: $refresh"
  echo "Cache-Control: max-age=$TTL"
  echo "Last-Modified:" `$dateconv -i '%s' -f '%a, %d %b %Y %H:%M:%S %Z' $DATE`
  echo ""
  jq -c '.' "$OUTPUT"
  if [ -n ${DEBUG:-} ]; then echo `date` "$0 $$ -- output $OUTPUT Age: $age Refresh: $refresh" >> $LOGTO 2>&1; fi
else
  echo "Cache-Control: no-cache"
  echo "Last-Modified:" `$dateconv -i '%s' -f '%a, %d %b %Y %H:%M:%S %Z' $DATE`
  echo ""
  if [ -n ${output:-} ]; then
    echo "$output"
  else
    echo '{ "error": "not found" }'
  fi
fi

if [ -n ${DEBUG:-} ]; then echo `date` "$0 $$ -- FINISH $QUERY_STRING" >> $LOGTO 2>&1; fi
