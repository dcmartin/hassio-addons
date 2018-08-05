#!/bin/tcsh
setenv APP "motion"
setenv API "matrix"

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

if ($?TTL == 0) set TTL = 5
if ($?SECONDS == 0) set SECONDS = `/bin/date "+%s"`
if ($?DATE == 0) set DATE = `/bin/echo $SECONDS \/ $TTL \* $TTL | /usr/bin/bc`

##
## ACCESS CLOUDANT
##
if ($?MOTION_CLOUDANT_URL) then
  set CU = $MOTION_CLOUDANT_URL
else
  /bin/echo `date` "$0:t $$ -- FAILURE: no Cloudant credentials" >>&! $LOGTO
  goto done
endif

#
# SETUP THE PROBLEM
#

set JSON = "$TMP/$APP-$API-$QUERY_STRING.$DATE.json"
set TEST = "$TMP/$APP-$API-$QUERY_STRING-test.$DATE.json"
set CSV = "$TMP/$APP-$API-$QUERY_STRING-test.$DATE.csv"
set CSV = "$MOTION_SHARE_DIR/matrix/$model.csv"

if ((-s "$JSON") && (-s "$CSV") && (-M "$JSON") <= (-M "$CSV")) then
    /bin/echo `date` "$0:t $$ -- EXISTING && UP-TO-DATE $JSON" >& /dev/stderr
    goto output
endif

if ((-M "$TEST") > (-M "$JSON") || (-M "$JSON") > (-M "$CSV")) then
    /bin/echo `date` "$0:t $$ -- rebuilding matrix" >& /dev/stderr
    # remove all residuals
    rm -f "$JSON:r".*
endif

#
# PROCESS THE TEST RESULTS
#

set sets = ( `jq -r '.sets[].set' "$TEST"` )
if ($#sets) then
  /bin/echo `date` "$0:t $$ -- building $JSON on $#sets ($sets)" >>&! $LOGTO

  unset matrix
  set total = 0

  foreach this ( $sets )
    /bin/echo -n `date` "$0:t $$ -- $this [ " >& /dev/stderr
    if (! -s "$MOTION_SHARE_DIR/matrix/$model.$this.json") then
	jq -c '.sets[]|select(.set=="'"$this"'").results[]?' "$TEST" >! "$MOTION_SHARE_DIR/matrix/$model.$this.json"
    endif
    # make matrix
    if ($?matrix) then
        set matrix = "$matrix"',{"set":"'$this'","truth":'
    else
	set names = ( `jq '.sets[].set' "$TEST"` )
	set tested_on = `jq -r '.date' "$TEST"`
	set names = `/bin/echo "$names" | sed 's/ /,/g'`
	set matrix = '{"name":"'"$device"'","model":"'"$model"'","date":'"$tested_on"',"size":'$#sets',"sets":['"$names"'],"matrix":[{"set":"'$this'","truth":'
	unset names
    endif
    unset truth
    foreach class ( $sets )
      /bin/echo -n "$class " >& /dev/stderr
      if (! -s "$MOTION_SHARE_DIR/matrix/$model.$this.$class.csv") then
	@ match = 0
	set noglob
	@ count = 0
	foreach line ( `cat "$MOTION_SHARE_DIR/matrix/$model.$this.json"` )
	  set id = `/bin/echo "$line" | jq -r '.id'`
	  if ($id != "null") then
	    set score = `/bin/echo "$line" | jq -r '.classes[]|select(.class=="'"$class"'").score'`
	    set top = `/bin/echo "$line" | jq -r '.classes|sort_by(.score)[-1].class'`
	    if ($class == $top) @ match++
	    /bin/echo "$id,$score" >>! "$MOTION_SHARE_DIR/matrix/$model.$this.$class.csv.$$"
	    @ count++
	  endif
	end
	unset noglob
	/bin/echo "id,label,$class" >! "$MOTION_SHARE_DIR/matrix/$model.$this.$class.csv"
	cat "$MOTION_SHARE_DIR/matrix/$model.$this.$class.csv.$$" | sed "s/\(.*\),\(.*\)/\1,$this,\2/" >> "$MOTION_SHARE_DIR/matrix/$model.$this.$class.csv"
	rm -f "$MOTION_SHARE_DIR/matrix/$model.$this.$class.csv.$$"
	if ($?found) then
	  set found = ( $found $class )
	else
	  set found = ( $class )
	endif
	if ($?truth) then
	  set truth = "$truth"','"$match"
	else
	  set truth = '['"$match"
	endif
      endif
    end
    if ($?truth) then
      set matrix = "$matrix""$truth"'],"count":'"$count"'}'
    else
      set matrix = "$matrix"'null}'
    endif
    @ total += $count
    if ($?found) then
      set out = ( "$MOTION_SHARE_DIR/matrix/$model.$this".*.csv )
      set found = `/bin/echo "$found" | sed 's/ /,/g'`
      csvjoin -c "id" $out | csvcut -c "id,label,$found" >! "$MOTION_SHARE_DIR/matrix/$model.$this.csv"
      unset found
      rm -f $out
    endif
    rm "$MOTION_SHARE_DIR/matrix/$model.$this.json"
    /bin/echo "]" >& /dev/stderr
  end
  set matrix = "$matrix"'],"count":'$total'}'

  /bin/echo "$matrix" | jq . >! "$MOTION_SHARE_DIR/matrix/$model.json"
  /bin/echo `date` "$0:t $$ -- MADE $MOTION_SHARE_DIR/matrix/$model.json" >& /dev/stderr

  set out = ( "$MOTION_SHARE_DIR/matrix/$model".*.csv )
  if ($#out) then
    head -1 $out[1] >! "$MOTION_SHARE_DIR/matrix/$model.csv"
    tail +2 -q $out >> "$MOTION_SHARE_DIR/matrix/$model.csv"
    /bin/echo `date` "$0:t $$ -- MADE $MOTION_SHARE_DIR/matrix/$model.csv" >& /dev/stderr
  else
    /bin/echo `date` "$0:t $$ -- FAILURE $MOTION_SHARE_DIR/matrix/$model.csv" >& /dev/stderr
  endif
endif

rm -f $out

