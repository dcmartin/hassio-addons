#!/bin/tcsh
setenv APP "motion"
setenv API "cfmatrix"

setenv DEBUG
setenv VERBOSE

if ($?TMP == 0) setenv TMP "/tmpfs"
if ($?LOGTO == 0) setenv LOGTO $TMP/$APP.log
if ($?DEBUG) echo `date` "$0:t $$ -- START" >>&! $LOGTO

# environment
if ($?MOTION_SHARE_DIR == 0) then
  set MOTION_SHARE_DIR = "/share/motion"
  if ($?DEBUG) echo `date` "$0:t $$ -- environment error: MOTION_SHARE_DIR undefined; using $MOTION_SHARE_DIR" >>&! $LOGTO
endif

# don't update statistics more than once per 15 minutes
set TTL = `echo "30 * 1" | bc`
set SECONDS = `date "+%s"`
set DATE = `echo $SECONDS \/ $TTL \* $TTL | bc`

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
  echo "No date converter; install dateutils" >>&! "$LOGTO"
  exit 1
endif

## process query
if ($?QUERY_STRING) then
    set db = `echo "$QUERY_STRING" | sed 's/.*db=\([^&]*\).*/\1/'`
    if ($db == "$QUERY_STRING") then
      set db = `echo "$QUERY_STRING" | sed 's/.*device=\([^&]*\).*/\1/'`
      if ($db == "$QUERY_STRING") unset db
    endif
    set model = `echo "$QUERY_STRING" | sed 's/.*model=\([^&]*\).*/\1/'`
    if ($model == "$QUERY_STRING") unset model
endif
## test arguments
if ($?db && $?model) then
    setenv QUERY_STRING "db=$db&model=$model"
else if ($?model) then
    setenv QUERY_STRING "model=$model"
else if ($?db) then
    setenv QUERY_STRING "db=$db"
endif

##
## ACCESS CLOUDANT
##
if ($?MOTION_CLOUDANT_URL) then
  set CU = "${MOTION_CLOUDANT_URL}"
  if ($?VERBOSE) echo `date` "$0:t $$ -- Cloudant credentials found" >>&! $LOGTO
else
  if ($?DEBUG) echo `date` "$0:t $$ -- FAILURE: no Cloudant credentials" >>&! $LOGTO
  goto done
endif

##
## ACCESS WATSON_VR
##
if ($?MOTION_JSON_FILE == 0) then
  if ($?DEBUG) echo `date` "$0:t $$ -- MOTION_JSON_FILE undefined" >>&! $LOGTO
  goto done
else if (! -s "$MOTION_JSON_FILE") then
  if ($?DEBUG) echo `date` "$0:t $$ -- MOTION_JSON_FILE ($MOTION_JSON_FILE) does not exist or zero size" >>&! $LOGTO
  goto done
else
  set WVR_URL = `jq -r '.watson.url' "$MOTION_JSON_FILE"`
  set WVR_DATE = `jq -r '.watson.date' "$MOTION_JSON_FILE"`
  set WVR_VERSION = `jq -r '.watson.version' "$MOTION_JSON_FILE"`
endif

if ($?WVR_URL == 0 || $?MOTION_WATSON_APIKEY == 0 || $?WVR_DATE == 0 || $?WVR_VERSION == 0) then
  if ($?DEBUG) echo `date` "$0:t $$ -- insufficient Watson credentials in $MOTION_JSON_FILE" >>&! $LOGTO
  goto done
else if ($#WVR_URL == 0 || $#MOTION_WATSON_APIKEY == 0 || $#WVR_DATE == 0 || $#WVR_VERSION == 0) then
  if ($?DEBUG) echo `date` "$0:t $$ -- incomplete Watson credentials in $MOTION_JSON_FILE" >>&! $LOGTO
  goto done
endif

if ($?VERBOSE) echo `date` "$0:t $$ -- Watson credentials found (url $#WVR_URL key $#MOTION_WATSON_APIKEY date $#WVR_DATE version $#WVR_VERSION)" >>&! $LOGTO

# find models and dbs
set CLASSIFIERS = "$TMP/$APP-$API-classifiers.$DATE.json"
if (! -s "$CLASSIFIERS") then
  rm -f "$TMP/$APP-$API-classifiers".*.json
  curl -q -s -L "$WVR_URL/$WVR_VERSION/classifiers?api_key=$MOTION_WATSON_APIKEY&version=$WVR_DATE" >! "$CLASSIFIERS"
endif

if (-s "$CLASSIFIERS") then
    set tmp = ( `cat "$CLASSIFIERS" | jq '.'` )

    if ($?db == 0 && $?model == 0) then
	set classifiers = ( `echo "$tmp" | jq -r '.classifiers[]|select(.status=="ready").classifier_id'` )
        if ($?VERBOSE) echo `date` "$0:t $$ -- Found $#classifiers classifiers in 'ready' state" >>&! $LOGTO
    else if ($?model) then
	set classifiers = ( `echo "$tmp" | jq -r '.classifiers[]|select(.classifier_id=="'"$model"'")|select(.status=="ready").classifier_id'` )
        if ($?VERBOSE) echo `date` "$0:t $$ -- Found $#classifiers with classifier id ($model) in ready state" >>&! $LOGTO
    else  if ($?db) then
	set classifiers = ( `echo "$tmp" | jq -r '.classifiers[]|select(.name=="'"$db"'")|select(.status=="ready").classifier_id'` )
        if ($?VERBOSE) echo `date` "$0:t $$ -- Found $#classifiers classifiers for db ($db) in ready state" >>&! $LOGTO
    endif
else
  if ($?DEBUG) echo `date` "$0:t $$ -- No classifiers returned from Watson VR (zero size)" >>&! $LOGTO
  set classifiers = ()
endif

if ($#classifiers == 0) then
  echo "Content-Type: application/json; charset=utf-8"
  echo "Access-Control-Allow-Origin: *"
  echo "Cache-Control: no-cache"
  echo ""
  echo '{"error":"not found"}'
  if ($?DEBUG) echo `date` "$0:t $$ -- returning error: not found" >>&! $LOGTO
else if ($?model) then
  set OUTPUT = "$MOTION_SHARE_DIR/matrix/$model.json"
  if (-s "$OUTPUT") then
    echo "Content-Type: application/json; charset=utf-8"
    echo "Access-Control-Allow-Origin: *"
    set AGE = `echo "$SECONDS - $DATE" | bc`
    echo "Age: $AGE"
    echo "Cache-Control: max-age=$TTL"
    echo "Last-Modified:" `$dateconv -i '%s' -f '%a, %d %b %Y %H:%M:%S %Z' $DATE`
    echo ""
    if ($?VERBOSE) echo `date` "$0:t $$ -- returning $OUTPUT" >>&! $LOGTO
    cat "$OUTPUT"
  else
    # return redirect
    set URL = "https://$CU/$db-$API/$model?include_docs=true"
    if ($?DEBUG) echo `date` "$0:t $$ -- returning redirect ($URL)" >>&! $LOGTO
    set AGE = `echo "$SECONDS - $DATE" | bc`
    echo "Age: $AGE"
    echo "Cache-Control: max-age=$TTL"
    echo "Last-Modified:" `$dateconv -i '%s' -f '%a, %d %b %Y %H:%M:%S %Z' $DATE`
    echo "Status: 302 Found"
    echo "Location: $URL"
    echo ""
  endif
else if ($#classifiers) then
    echo "Content-Type: application/json; charset=utf-8"
    echo "Access-Control-Allow-Origin: *"
    echo "Cache-Control: no-cache"
    echo ""
    echo -n '{"models":['
    unset j
    foreach i ( $classifiers )
      if ($?j) then
        set j = "$j"',"'"$i"'"'
      else
        set j = '"'"$i"'"'
      endif
    end
    echo -n "$j"'],"count":'$#classifiers
    echo '}'
    if ($?DEBUG) echo `date` "$0:t $$ -- returning JSON: models: [${j}], count: $#classifiers" >>&! $LOGTO
endif

done:

echo `date` "$0:t $$ -- FINISH" >>&! $LOGTO
