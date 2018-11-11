#!/bin/tcsh
setenv APP "motion"
setenv API "matrix"

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
  echo "No date converter; install dateutils" >& /dev/stderr
  exit 1
endif

# don't update service cache(s) (and this service output) more than once per (in seconds)
set TTL = `/bin/echo "60 * 1 * 1  * 1" | bc`
set SECONDS = `date "+%s"`
set DATE = `/bin/echo $SECONDS \/ $TTL \* $TTL | bc`

/bin/echo `date` "$0:t $$ -- START" >>&! $LOGTO

if ($?QUERY_STRING) then
    set db = `/bin/echo "$QUERY_STRING" | sed 's/.*db=\([^&]*\).*/\1/'`
    if ($db == "$QUERY_STRING") unset db
    set model = `/bin/echo "$QUERY_STRING" | sed 's/.*model=\([^&]*\).*/\1/'`
    if ($model == "$QUERY_STRING") unset model
endif
if ($?db == 0) set db = "rough-fog"
setenv QUERY_STRING "db=$db"
if ($?model) then
  setenv QUERY_STRING "$QUERY_STRING"'&model='"$model"
endif

##
## ACCESS CLOUDANT
##
if ($?MOTION_CLOUDANT_URL) then
  set CU = $MOTION_CLOUDANT_URL
else
  /bin/echo `date` "$0:t $$ -- FAILURE: no Cloudant credentials" >>&! $LOGTO
  goto done
endif

set OUTPUT = "$TMP/$APP-$API-$QUERY_STRING.$DATE.json"
if ( -s "$OUTPUT") then
  goto output
endif

#
# gather testing information
#

set TEST = "$TMP/$APP-$API-$db-test.$DATE.json" 
if (! -s "$TEST") then
  set old = ( `/bin/echo "$TEST:r:r".*` )
  if ($?DEBUG) /bin/echo `date` "$0:t $$ -- DEBUG: variable (old) is defined (0/1)? ($?old)" >>&! $LOGTO

  /bin/echo `date` "$0:t $$ -- retrieving from Cloudant: $TEST" >>&! $LOGTO
  curl -s -q -f -L "$CU/$db-test/_all_docs?include_docs=true" -o "$TEST.$$"
  if ($status == 22 || ! -s "$TEST.$$") then
    /bin/echo `date` "$0:t $$ -- cannot retrieve $TEST from $CU/$db-test" >>&! $LOGTO
    if ($?old) then
      if ($#old) then
	if (-s "$old[$#old]") then
	  set TEST = "$old[$#old]"
	else
	  /bin/echo `date` "$0:t $$ -- no existing $old[$#old] for $TEST" >>&! $LOGTO
	endif
      endif
    else
      /bin/echo `date` "$0:t $$ -- no old for $TEST" >>&! $LOGTO
      unset TEST
    endif
  else
    /bin/echo `date` "$0:t $$ -- success retrieving from Cloudant $TEST.$$" >>&! $LOGTO
    mv -f "$TEST.$$" "$TEST"
    if ($?old) then
      @ i = 1
      while ($i <= $#old) 
	if ($?DEBUG) /bin/echo `date` "$0:t $$ -- DEBUG: removing $i/$#old from $old" >>&! $LOGTO
	rm -f "$old[$i]"
	@ i++
      end
    endif
  endif
endif

# SANITY
if (! -s "$TEST") goto output

#
# process the test results
#

set results = ( `jq -r '.rows[].id' "$TEST"` )
if ($status == 0 && $#results) then
  foreach m ( $results )
    if ($?model) then
      if ("$m" != "$model") continue
    endif

    jq '.rows[]|select(.id=="'$m'")' "$TEST" >! "$OUTPUT.$$.$$" # MAKE MATRIX >! "$OUTPUT.$$.$$"

    if ($status == 0 && -s "$OUTPUT.$$.$$") then
      jq -c '.' "$OUTPUT.$$.$$" >>! "$OUTPUT.$$"
    else
      /bin/echo `date` "$0:t $$ -- failure model ($m)" >>&! $LOGTO
    endif
    rm -f "$OUTPUT.$$.$$"
  end
  if (-s "$OUTPUT.$$") then
    jq -c '.' "$OUTPUT.$$" >! "$OUTPUT"
  endif
  if ($status != 0) then
    /bin/echo `date` "$0:t $$ -- bad JSON ($OUTPUT.$$)" >>&! $LOGTO
    rm -f "$OUTPUT"
  endif
  rm -f "$OUTPUT.$$"
else
  /bin/echo `date` "$0:t $$ -- no results in $TEST" >>&! $LOGTO
  rm -f "$OUTPUT".*
  goto output
endif

output:

if (! -s "$OUTPUT") then
  if ($?DEBUG) /bin/echo `date` "$0:t $$ -- no matrix found ($db)" >>&! $LOGTO
  /bin/echo "Content-Type: application/json; charset=utf-8"
  /bin/echo "Access-Control-Allow-Origin: *"
  /bin/echo "Cache-Control: no-cache"
  /bin/echo ""
  /bin/echo '{"error":"not found"}'
else 
  /bin/echo "Content-Type: application/json; charset=utf-8"
  /bin/echo "Access-Control-Allow-Origin: *"
  set AGE = `/bin/echo "$SECONDS - $DATE" | bc`
  /bin/echo "Age: $AGE"
  /bin/echo "Cache-Control: max-age=$TTL"
  /bin/echo "Last-Modified:" `$dateconv -i '%s' -f '%a, %d %b %Y %H:%M:%S %Z' $DATE`
  /bin/echo ""
  jq -c '.' "$OUTPUT"
endif

done:

/bin/echo `date` "$0:t $$ -- FINISH" >>&! $LOGTO
