#!/bin/csh -fb
echo "+++ BEGIN: $0 $* ($$)" `date` >& /dev/stderr
# interval time in minutes
set INTERVAL = 15
# cache'ing directives
set TTL = 1800
set SECONDS = `date +%s`
set DATE = `echo $SECONDS \/ $TTL \* $TTL | bc`
set PERIOD = `echo "($SECONDS/($INTERVAL*60))*($INTERVAL*60)" | bc`

#
if ($?DEVICE_NAME == 0) then
    echo "+++ STATUS: $0 ($$)" `date` "no DEVICE_NAME specified" >& /dev/stderr
    setenv DEVICE_NAME "rough-fog"
endif

set WWW="http://www.dcmartin.com/CGI"
set APP="aah"
set API="stats"
set DIR="/var/lib/motion"

#
# CLI arguments
#
set SEQNO = $argv[1]
set YEAR = $argv[2]
set MONTH = $argv[3]
set DAY = $argv[4]
set HOUR = $argv[5]
set MINUTE = $argv[6]
set SECOND = $argv[7]

if (-e /tmp/$0:t.$PERIOD) then
    echo "*** TOO SOON ***"
else
    rm -f /tmp/$0:t.*
    touch /tmp/$0:t.$PERIOD
endif

# calculate current time series 
set INDEX = `echo "$YEAR" "$MONTH" "$DAY" "$HOUR" "$MINUTE" "$SECOND" | \
    gawk -v interval="$INTERVAL" '{ m=$4*60+$5; m/=interval; \
    	t=mktime(sprintf("%4d %2d %2d %2d %2d %2d", $1, $2, $3, $4, $5, $6)); \
	printf "{ \"interval\":\"%d\",\"AMPM\":\"%s\",\"week\":\"%d\",\"day\":\"%s\" }", \
	    m, \
	    strftime("%p",t),\
	    strftime("%U",t),\
	    strftime("%w",t) }'`
echo "+++ STATUS: $0 ($$)" `date` "INDEX = $INDEX" >& /dev/stderr

set PRIOR_ID = ( `echo "$YEAR $MONTH $DAY $HOUR" | awk '{ printf("%04d%02d%02d%02d", $1, $2, $3, $4) }'` )
# get events occuring in this hour as list oldest first
set PRIOR = ( `ls -1t "$DIR/$PRIOR_ID"*.json | sed "s|$DIR/\(.*\)-.*-.*.json|\1|" | sort -n` )

# check if prior events exist
if ($#PRIOR > 0) then
    echo "+++ STATUS: $0 ($$)" `date` "PRIOR=[$PRIOR_ID] ($#PRIOR): $PRIOR" >& /dev/stderr
else
    echo "*** ERROR: $0" `date` "PRIOR=[] (0): $PRIOR" >& /dev/stderr
    exit
endif

#
# select from all PRIOR events those occuring in INDEX interval (in minutes)
#
set interval = `echo "$INDEX" | jq '.interval' | sed 's/"//g'`
# loop through all starting with oldest (n.b. "sort -n" above)
set prior = ()
set eic = ()
foreach k ( $PRIOR )
   # identify historical event JSON
   set json = $DIR/$k-*-*.json
   if ($#json == 0) continue
   set h = `jq '.hour' $json | sed 's/"//g'`
   set m = `jq '.minute' $json | sed 's/"//g'`
   set t = `echo "($h*60+$m)/$INTERVAL" | bc`
   set d = `echo $MINUTE - $m | bc`

   if ($t == $interval && $d >= 0) then
	# event exists and in same time interval
        echo "+++ STATUS: $0 ($$) `date` "EVENT $k [$t $h $m]($d) : $json" >& /dev/stderr
        set prior = ( $prior $json )
        # identify EIC JSON
        set l = $DIR/$DEVICE_NAME-$k-*-*.json
        if ($#l > 0) then
	    echo "+++ STATUS: $0 ($$) `date` "EIC $l" >& /dev/stderr
	    set eic = ( $eic $l )
	endif
   endif
end

echo "+++ STATUS: $0 ($$)" `date` "INTERVAL=$interval : ($#prior): $prior" >& /dev/stderr

if ($#prior > 1) then
    set EVENT = "$prior[1]"
    set prior = "$prior[2-]"

    # get time series for EVENT
    set ampm = `cat "$EVENT" | jq '.AMPM' | sed 's/"//g'`
    set week = `cat "$EVENT" | jq '.week' | sed 's/"//g'`
    set day = `cat "$EVENT" | jq '.day' | sed 's/"//g'`
    set interval = `cat "$EVENT" | jq '.interval' | sed 's/"//g'`

    # get Alchemy text
    set class = `jq -c '.alchemy.text' $EVENT | sed 's/"//g'`

    @ e = 1
    # iterate over older events
    foreach t ( $prior )
	set tc = `jq -c '.alchemy.text' $t | sed 's/"//g'`

	if ($tc == $class) then
	    echo `jq '.alchemy.score' $t | sed 's/"//g'` >>! "/tmp/$0.$$"
	    set dow = `jq '.day' $eic[$e] | sed 's/"//g'`
	    set int = `jq '.interval' $eic[$e] | sed 's/"//g'`
	    if ($int != $interval) then
		echo "ERROR - mismatch interval ($int != $interval)"
		exit
	    endif

	endif
	@ e++
    end
if (-e "/tmp/$0.$$") then
    set cstats  = `awk 'BEGIN { c=0; s=0; m=0; vs=0; v=0 } { c++; s+=$1; m=s/c; vs+=($1-m)^2; v=vs/c } END { sd=sqrt(v); printf("%d %f %f",c,m,sd) }' "/tmp/$0.$$"`
    rm "/tmp/$0.$$"

    set models = ( `ls -1t $DIR/$DEVICE_NAME-$class.*.json | sed "s|$DIR/$DEVICE_NAME-$class\.\(.*\).*\.json|\1|" | sort -nr` )
    if ($#models > 0) then
	set model =  $DIR/$DEVICE_NAME-$class.$models[1].json
	set mstats = `jq '.days[].intervals['$interval'].count' $model | sed 's/"//g' | awk 'BEGIN { c=0; s=0; m=0; v=0; vs=0 } { c++; s+=$1; m=s/c; vs+=($1-m)^2; v=vs/c } END { sd=sqrt(v); printf("%d %f %f",c,m,sd) }'`
	set count = `jq '.days['$dow'].intervals['$interval'].count'  $model | sed 's/"//g'`
	set mean = `jq '.days['$dow'].intervals['$interval'].mean' $model | sed 's/"//g'`
	set stdev = `jq '.days['$dow'].intervals['$interval'].stdev' $model | sed 's/"//g'`

	# echo $model
	echo "*** MODEL: $0 " `date` day=$dow interval=$interval \( $cstats \) $count \( $mstats \) $mean $stdev >& /dev/stderr
    else
	echo "*** NO MODEL: $models" >& /dev/stderr
    endif
endif
# jq -c '.' $eic

#
# get classifiers & scores
#
set ACLASSES =( `jq '.alchemy|.text' "$EVENT" | sed 's/"//g'` )
set VCLASSES = ( `jq '.visual.scores[]|.name' "$EVENT" | sed 's/"//g'` )
set ASCORES = ( `jq '.alchemy|.score' "$EVENT" | sed 's/"//g'` )
set VSCORES = ( `jq '.visual.scores[]|.score' "$EVENT" | sed 's/"//g'` )

#
# get classifier statistics
#

# all classifiers and scores
set CLASSES = ( $ACLASSES $VCLASSES )
set SCORES = ( $ASCORES $VSCORES )

# define ENTITY in context (to model)
set EIC = "$DIR/$DEVICE_NAME-$EVENT_ID-EIC.json"

# define entity time-series (from EVENT)
echo '{ "event":"'$EVENT_ID'","week":"'$week'","AMPM":"'$ampm'","day":"'$day'","interval":"'$interval'","classifiers":[' >! "$EIC"

echo "+++ STATUS: $0 ($$)" `date` "$CLASSES" >& /dev/stderr

@ i = 0
foreach CLASS ( $CLASSES )
    if ($CLASS == "NO_TAGS") continue;
    if ($CLASS == \"\") continue;

    @ i++
    if ($?continue) echo ',' >> "$EIC"
    set continue
    # if environment variable is specified
    if ($?MINIMUM_CLASSIFIER_SCORE) then
	set TF = `echo "$SCORES[$i] < $MINIMUM_CLASSIFIER_SCORE" | bc`

	if ($TF) then
	    echo "+++ STATUS: $0 ($$)" `date` "$CLASS under minimum score ($SCORES[$i])" >& /dev/stderr
	    continue;
	endif
    endif

    # get statistical model for this classifier
    set MODEL = "$DIR/$DEVICE_NAME-$CLASS.$DATE.json"
    if ( ! -e "$MODEL" ) then
	# find old statistical models
	set OLD_MODEL = `ls -1t "$DIR/$DEVICE_NAME-$CLASS".*.json`
	# retrieve new/updated statistical model
	( curl -o "$MODEL.$$" -s -L "$WWW/aah-stats.cgi?db=$DEVICE_NAME&id=$CLASS" ; mv "$MODEL.$$" "$MODEL" ) &
	# if there are no old models
	if ( $#OLD_MODEL == 0 ) then
	    echo "+++ STATUS: $0 ($$)" `date` "waiting on $MODEL" >& /dev/stderr
	    while ( ! -e "$MODEL" )
		sleep 5
	    end
	    set err = `jq '.error' "$MODEL" | sed 's/"//g'`
	    if ($err != "null") then
		rm -f "$MODEL"
	    endif
	else
	    # use newest old model
	    set MODEL = "$OLD_MODEL[1]"
	    # remove oldest model
	    if ($#OLD_MODEL > 1) then
		echo "+++ STATUS: $0 ($$)" `date` "removing $OLD_MODEL[2-]" >& /dev/stderr
		rm -f $OLD_MODEL[2-]
	    endif
	endif
    endif
    if (! -e "$MODEL" ) then
	echo "+++ STATUS: $0 ($$)" `date` "NO $MODEL"
	unset continue
	continue
    else
        set err = `jq '.error' "$MODEL"`
	if ($err == "not_found") then
	    unset continue
	    continue
	endif
    endif

    set CLASS_COUNTS = "$DIR/$DEVICE_NAME-$CLASS-counts.$DATE.json"
    if (! -e "$CLASS_COUNTS") then
	set OLDCLASS_COUNTS = `ls -1t $DIR/$DEVICE_NAME-$CLASS-counts.*.json`
	rm -f "$OLDCLASS_COUNTS"
	# get counts for all days and all intervals
	jq -c '.days[].intervals[].count' "$MODEL" | sed 's/"//g' | gawk 'BEGIN { t = 0; c = 0; s = 0 } { t++; if ($1 > 0) { c++; s += $1; m = s/c; vs += ($1 - m)^2; v=vs/c} } END { sd = sqrt(v/c); printf "{\"count\":\"%d\",\"non-zero\":\"%d\",\"sum\":\"%d\",\"mean\":\"%f\",\"stdev\":\"%f\"}\n", t, c, s, m, sd  }' > "$CLASS_COUNTS"

	echo "+++ STATUS: $0 ($$)" `date` `jq . $CLASS_COUNTS` >& /dev/stderr
    endif

    # get entity time-series context (n.b. number of weeks)

    echo -n '{ "class":"'$CLASS'",' >> "$EIC"
    echo -n '"score":"'$SCORES[$i]'",' >> "$EIC"
    echo -n '"model":' `jq '.days['$day'].intervals['$interval']' "$MODEL"` ',' >> "$EIC"
    echo -n '"weeks":' `jq '.days['$day'].weeks' "$MODEL"` ',' >> "$EIC"
    echo -n '"nweek":' `jq '.days['$day'].nweek' "$MODEL"` ',' >> "$EIC"
    echo -n '"intervals":' `jq '.' "$CLASS_COUNTS"` >> "$EIC"
    echo -n '}' >> "$EIC"
end
echo ']}' >> "$EIC"

# jq -c . "$EIC"

#
# test condtionals
#
@ i = 1
foreach CLASS ( $CLASSES )
    @ i++
end

set seconds = `date +%s`
set elapsed = ( `echo "$seconds - $SECONDS" | bc` )
echo "+++ END: $0 ($$)" `date` " elapsed $elapsed " $EIC >& /dev/stderr
