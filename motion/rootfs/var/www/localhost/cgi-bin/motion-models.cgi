#!/bin/tcsh
setenv APP "motion"
setenv API "models"

setenv DEBUG 
setenv VERBOSE

if ($?TMP == 0) setenv TMP "/tmpfs"
if ($?LOGTO == 0) setenv LOGTO $TMP/$APP.log
if ($?DEBUG) echo `date` "$0:t $$ -- START" >>&! $LOGTO

# environment

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
  echo `date` "$0:t $$ -- No date converter; install dateutils" >>&! "$LOGTO"
  exit 1
endif

# don't update service cache(s) (and this service output) more than once per (in seconds)
set TTL = `echo "60 * 1 * 1  * 1" | bc`
set SECONDS = `date "+%s"`
set DATE = `echo $SECONDS \/ $TTL \* $TTL | bc`

###
### START
###

## PROCESS query string
if ($?QUERY_STRING) then
    set db = `echo "$QUERY_STRING" | sed 's/.*db=\([^&]*\).*/\1/'`
    if ($db == "$QUERY_STRING") unset db
    set model = `echo "$QUERY_STRING" | sed 's/.*model=\([^&]*\).*/\1/'`
    if ($model == "$QUERY_STRING") unset model
    set include_ids = `echo "$QUERY_STRING" | sed 's/.*include_ids\([^&]*\).*/\1/'`
    if ($include_ids == "$QUERY_STRING") unset include_ids
endif
if ($?db == 0) set db = "rough-fog"
setenv QUERY_STRING "db=$db"
if ($?model) then
  setenv QUERY_STRING "$QUERY_STRING"'&model='"$model"
endif
if ($?include_ids) then
  setenv QUERY_STRING "$QUERY_STRING"'&include_ids=true'
endif

##
## ACCESS CLOUDANT
##
if ($?MOTION_CLOUDANT_URL) then
    set CU = "${MOTION_CLOUDANT_URL}"
else
  if ($?DEBUG) echo `date` "$0:t $$ -- FAILURE: no Cloudant credentials" >>&! $LOGTO
  goto done
endif

##
## OUTPUT
##

set OUTPUT = "$TMP/$APP-$API-$QUERY_STRING.$DATE.json"

if (-s "$OUTPUT") then
  if ($?VERBOSE) echo `date` "$0:t $$ -- EXISTING OUTPUT $OUTPUT" >>&! $LOGTO
else
  if ($?VERBOSE) echo `date` "$0:t $$ -- BUILDING OUTPUT $OUTPUT" >>&! $LOGTO
  set TRAIN = "$TMP/$APP-$API-$db-train.$DATE.json" 
  if (! -s "$TRAIN") then
    if ($?VERBOSE) echo `date` "$0:t $$ -- NO TRAINING DATA $TRAIN" >>&! $LOGTO
    set url = "$CU/$db-train/_all_docs?include_docs=true" 
    if ($?DEBUG) echo "$0:t $$" `date` "RETRIEVE TRAINING DATA ($TRAIN) FROM CLOUDANT ($url)" >>&! $LOGTO
    curl -s -q -f -L "$url" -o "$TRAIN.$$"
    if ($status == 22 || ! -s "$TRAIN.$$") then
      if ($?DEBUG) echo `date` "$0:t $$ -- FAILURE -- $TRAIN from $url" >>&! $LOGTO
      set old = ( `echo "$TRAIN:r:r".*` )
      if ($?old) then
        if ($?VERBOSE) echo `date` "$0:t $$ -- OLD TRAINING FILES (COUNT = $#old)" >>&! $LOGTO
        if ($#old) then
          if (-s "$old[$#old]") then
            set TRAIN = "$old[$#old]"
          else
            if ($?VERBOSE) echo `date` "$0:t $$ -- no existing $old[$#old] for $TRAIN" >>&! $LOGTO
            unset TRAIN
          endif
        endif
      else
        if ($?VERBOSE) echo `date` "$0:t $$ -- NO OLD TRAINING FILES: $TRAIN" >>&! $LOGTO
        unset TRAIN
      endif
    else if (-s "$TRAIN.$$") then
      if ($?VERBOSE) echo `date` "$0:t $$ -- SUCCESS -- $TRAIN from $url" >>&! $LOGTO
      mv -f "$TRAIN.$$" "$TRAIN"
      if ($?old) then
        @ i = 1
        while ($i <= $#old) 
          if ($?DEBUG) echo `date` "$0:t $$ -- DEBUG: removing $i/$#old from $old" >>&! $LOGTO
          rm -f "$old[$i]"
          @ i++
        end
      endif
    else
      if ($?DEBUG) echo `date` "$0:t $$ -- FAILURE -- $url" >>&! $LOGTO
      unset TRAIN
    endif
  endif

  # process training information
  if ($?TRAIN == 0) then
    if ($?VERBOSE) echo `date` "$0:t $$ -- no training data" >>&! $LOGTO
  else if (! -s "$TRAIN") then
    if ($?VERBOSE) echo `date` "$0:t $$ -- no training cache $TRAIN" >>&! $LOGTO
  else
    set models = ( `jq -r '.rows[].id' "$TRAIN"` )
    if ($status == 0 && $#models) then
      if ($?VERBOSE) echo `date` "$0:t $$ -- found models $models" >>&! $LOGTO
      foreach m ( $models )
        if ($?model) then
          if ("$m" != "$model") then
            if ($?VERBOSE) echo `date` "$0:t $$ -- model $model only; skipping non-matching model ($m)" >>&! $LOGTO
            continue
          endif
        endif
        if ($?include_ids) then
          if ($?VERBOSE) echo `date` "$0:t $$ -- finding row for model ($m) including ids" >>&! $LOGTO
          jq '.rows[]|select(.id=="'$m'")' "$TRAIN" | \
            jq '{"model":.id,"date":.doc.date,"device":.doc.name,"labels":[.doc.images[]|{"class":.class,"bytes":.bytes,"count":.count,"ids":.ids}],"negative":.doc.negative,"classes":.doc.classes,"detail":.doc.detail}' >! "$OUTPUT.$$.$$"
        else
          if ($?VERBOSE) echo `date` "$0:t $$ -- finding row for model ($m)" >>&! $LOGTO
          jq '.rows[]|select(.id=="'$m'")' "$TRAIN" | \
            jq '{"model":.id,"date":.doc.date,"device":.doc.name,"labels":[.doc.images[]|{"class":.class,"bytes":.bytes,"count":.count}],"negative":.doc.negative,"classes":.doc.classes,"detail":.doc.detail}' >! "$OUTPUT.$$.$$"
        endif
        if ($status == 0 && -s "$OUTPUT.$$.$$") then
          if ($?DEBUG) echo `date` "$0:t $$ -- FOUND model ($m)" >>&! $LOGTO
          if ($?model) then
            # found one model
            jq -c '.' "$OUTPUT.$$.$$" >>! "$OUTPUT.$$"
            break
          else
            if (! -e "$OUTPUT.$$") then
              # start list of matching models
              echo '{ "models": [' >! "$OUTPUT.$$"
            else 
              echo ',' >> "$OUTPUT.$$"
            endif
            jq -c '.' "$OUTPUT.$$.$$" >> "$OUTPUT.$$"
          endif
        else
          if ($?DEBUG) echo `date` "$0:t $$ -- DID NOT FIND model ($m)" >>&! $LOGTO
        endif
        rm -f "$OUTPUT.$$.$$"
      end
      if ($?model == 0) then
        # terminate list of matching models
        echo ']}' >>! "$OUTPUT.$$"
      endif
      if (-s "$OUTPUT.$$") then
        if ($?VERBOSE) echo `date` "$0:t $$ -- testing output for JSON" >>&! $LOGTO
        jq -c '.' "$OUTPUT.$$" >! "$OUTPUT"
	if ($status != 0) then
	  if ($?DEBUG) echo `date` "$0:t $$ -- bad json" `cat $OUTPUT.$$` >>&! $LOGTO
	  rm -f "$OUTPUT" "$OUTPUT.$$"
        else
	  if ($?DEBUG) echo `date` "$0:t $$ -- good json" >>&! $LOGTO
          rm -f "$OUTPUT.$$"
	endif
      else
        if ($?DEBUG) echo `date` "$0:t $$ -- no or zero size output" >>&! $LOGTO
        rm -f "$OUTPUT.$$"
      endif
    else
      if ($?DEBUG) echo `date` "$0:t $$ -- no models in $TRAIN" >>&! $LOGTO
      goto output
    endif
  endif
endif

output:

if (! -s "$OUTPUT") then
  if ($?DEBUG) echo `date` "$0:t $$ -- no models found ($db)" >>&! $LOGTO
  echo "Content-Type: application/json; charset=utf-8"
  echo "Access-Control-Allow-Origin: *"
  echo "Cache-Control: no-cache"
  echo ""
  echo '{"error":"not found"}'
else 
  echo "Content-Type: application/json; charset=utf-8"
  echo "Access-Control-Allow-Origin: *"
  set AGE = `echo "$SECONDS - $DATE" | bc`
  echo "Age: $AGE"
  echo "Cache-Control: max-age=$TTL"
  echo "Last-Modified:" `$dateconv -i '%s' -f '%a, %d %b %Y %H:%M:%S %Z' $DATE`
  echo ""
  jq -c '.' "$OUTPUT"
endif

done:

if ($?DEBUG) echo `date` "$0:t $$ -- FINISH" >>&! $LOGTO
