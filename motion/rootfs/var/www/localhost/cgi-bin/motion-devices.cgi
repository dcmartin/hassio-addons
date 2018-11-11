#!/bin/tcsh 
setenv APP "motion"
setenv API "devices"

setenv DEBUG 
setenv VERBOSE

if ($?TMP == 0) setenv TMP "/tmpfs"
if ($?LOGTO == 0) setenv LOGTO $TMP/$APP.log
if ($?DEBUG) echo `date` "$0:t $$ -- START" >>&! $LOGTO

# environment
if ($?MOTION_DEVICE_DB == 0) then
  set MOTION_DEVICE_DB = "motion"
  if ($?DEBUG) echo `date` "$0:t $$ -- MOTION_DEVICE_DB not set; using $MOTION_DEVICE_DB" >>&! $LOGTO
endif
if ($?MOTION_CLOUDANT_URL == 0) then
  if ($?DEBUG) echo `date` "$0:t $$ -- FAILURE: no Cloudant credentials" >>&! $LOGTO
  goto done
endif
set CU = "${MOTION_CLOUDANT_URL}"

###
### dateutils REQUIRED
###

if ( -e /usr/bin/dateutils.dconv ) then
   set dateconv = /usr/bin/dateutils.dconv
else if ( -e /usr/bin/dateconv ) then
   set dateconv = /usr/bin/dateconv
else if ( -e /usr/local/bin/dateconv ) then
   set dateconv = /usr/local/bin/dateconv
else
  echo "No date converter; install dateutils" >& /dev/stderr
  exit 1
endif

# don't update statistics more than once per (in seconds)
setenv TTL 30
setenv SECONDS `date "+%s"`
setenv DATE `echo $SECONDS \/ $TTL \* $TTL | bc`

if ($?QUERY_STRING) then
    set db = `echo "$QUERY_STRING" | sed 's/.*db=\([^&]*\).*/\1/'`
    if ($db == "$QUERY_STRING") unset db
endif

if ($?db == 0) set db = all

# standardize QUERY_STRING (rendezvous w/ APP-make-API.csh script)
setenv QUERY_STRING "db=$db"

##
## ACCESS CLOUDANT
##

# output target
set OUTPUT = "$TMP/$APP-$API-$QUERY_STRING.$DATE.json"
# test if been-there-done-that
if (-e "$OUTPUT") goto output
rm -f "$OUTPUT:r:r".*

# find devices
if ($db == "all") then
  set devices = ( `curl -s -q -L "$CU/$MOTION_DEVICE_DB/_all_docs" | jq -r '.rows[]?.id'` )
  if ($#devices == 0) then
    if ($?VERBOSE) echo `date` "$0:t $$ ++ Could not retrieve list of devices from ($url)" >>&! $LOGTO
    goto done
  endif
else
  set devices = ($db)
endif

if ($?VERBOSE) echo `date` "$0:t $$ ++ Devices in DB ($devices)" >>&! $LOGTO

@ k = 0
set all = '{"date":'"$DATE"',"devices":['

foreach d ( $devices )
  # get device entry
  set url = "$CU/$MOTION_DEVICE_DB/$d"
  set out = "$TMP/$APP-$API-$$.json"
  curl -s -q -L "$url" -o "$out"
  if (! -e "$out") then
    if ($?VERBOSE) echo `date` "$0:t $$ ++ FAILURE ($d)" `ls -al $out` >>&! $LOGTO
    rm -f "$out"
    continue
  endif
  if ($db != "all" && $d == "$db") then
    jq '{"name":.name,"date":.date,"ip_address":.ip_address,"location":.location}' "$out" >! "$OUTPUT"
    rm -f "$out"
    goto output
  else if ($db == "all") then
    set json = `jq '{"name":.name,"date":.date}' "$out"`
    rm -f "$out"
  else
    unset json
  endif
  if ($k) set all = "$all"','
  @ k++
  if ($?json) then
    set all = "$all""$json"
  endif
end
set all = "$all"']}'

echo "$all" | jq -c '.' >! "$OUTPUT"

#
# output
#

output:

echo "Content-Type: application/json; charset=utf-8"
echo "Access-Control-Allow-Origin: *"

if ($?output == 0 && -e "$OUTPUT") then
  @ age = $SECONDS - $DATE
  echo "Age: $age"
  @ refresh = $TTL - $age
  # check back if using old
  if ($refresh < 0) @ refresh = $TTL
  echo "Refresh: $refresh"
  echo "Cache-Control: max-age=$TTL"
  echo "Last-Modified:" `$dateconv -i '%s' -f '%a, %d %b %Y %H:%M:%S %Z' $DATE`
  echo ""
  jq -c '.' "$OUTPUT"
  if ($?VERBOSE) echo `date` "$0:t $$ -- output ($OUTPUT) Age: $age Refresh: $refresh" >>&! $LOGTO
else
  echo "Cache-Control: no-cache"
  echo "Last-Modified:" `$dateconv -i '%s' -f '%a, %d %b %Y %H:%M:%S %Z' $DATE`
  echo ""
  if ($?output) then
    echo "$output"
  else
    echo '{ "error": "not found" }'
  endif
endif

# done

done:

if ($?VERBOSE) echo `date` "$0:t $$ -- FINISH ($QUERY_STRING)" >>&! $LOGTO
