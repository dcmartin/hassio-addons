#!/bin/csh -fb
# control IFF perform motion conditional testing
if ($?ON_MOTION_DETECT == 0) then
    exit
endif

echo "+++ BEGIN: $0 $* ($$)" `date` >& /dev/stderr
# get start
set SECONDS = `date +%s`

# activity interval (in minutes; of events; 96 per day)
set INTERVAL = 15

# conditional frequency (in seconds; test motion conditional(s) every FREQUENCY seconds)
set FREQUENCY = 300
set PERIOD = `echo "($SECONDS/($FREQUENCY*60))*($FREQUENCY*60)" | bc`

# cache'ing directives on results
set TTL = 1800
set DATE = `echo $SECONDS \/ $TTL \* $TTL | bc`

# test for DEVICE_NAME
if ($?DEVICE_NAME == 0) then
    echo "*** STATUS: $0 ($$)" `date` "no DEVICE_NAME specified" >& /dev/stderr
    setenv DEVICE_NAME "rough-fog"
endif

# test periodicity - only process motion detection events every INTERVAL seconds
if (-e /tmp/$0:t.$PERIOD) then
    echo "*** TOO SOON ($PERIOD) ***"
    if ($?PERIOD_TEST) goto done
else
    rm -f /tmp/$0:t.*
    touch /tmp/$0:t.$PERIOD
endif

#
# ACTUAL WORK STARTS HERE
#

# server CGI (don't think we use them)
set WWW="http://www.dcmartin.com/CGI"
set APP="aah"
set API="stats"
set DIR="/var/lib/motion"

#
# grab CLI arguments
#
if ($#argv >= 7) then
    set SEQNO = $argv[1]
    set YEAR = $argv[2]
    set MONTH = $argv[3]
    set DAY = $argv[4]
    set HOUR = $argv[5]
    set MINUTE = $argv[6]
    set SECOND = $argv[7]
else
    echo "*** ARGUMENT COUNT = $#argv ***"
    exit
endif

# get events occuring in this hour as list oldest first
set PRIOR_ID = ( `echo "$YEAR $MONTH $DAY $HOUR" | awk '{ printf("%04d%02d%02d%02d", $1, $2, $3, $4) }'` )
set PRIOR = ( `ls -1t "$DIR/$PRIOR_ID"*.json | sed "s|$DIR/\(.*\)-.*-.*.json|\1|" | sort -n` )

# check if prior events exist
if ($#PRIOR > 0) then
    # echo "+++ STATUS: $0 ($$)" `date` "PRIOR=[$PRIOR_ID] COUNT=$#PRIOR" >& /dev/stderr
else
    echo "*** ERROR: $0" `date` "PRIOR=[] (0): $PRIOR" >& /dev/stderr
    exit
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
# get interval from current time series
set interval = `echo "$INDEX" | jq '.interval' | sed 's/"//g'`

#
# select from all PRIOR events those occuring in INDEX interval (in minutes)
#
# loop through all starting with oldest (n.b. "sort -n" above)
set prior = ()
foreach k ( $PRIOR )
   # identify historical event
   set event = $DIR/$k-*-*.json
   if ($#event == 0 || !(-e "$event")) continue
   set h = `jq '.hour' $event | sed 's/"//g'`
   set m = `jq '.minute' $event | sed 's/"//g'`
   set t = `echo "($h*60+$m)/$INTERVAL" | bc`
   set d = `echo $MINUTE - $m | bc`

   if ($t == $interval && $d >= 0) then
	# event exists and in same time interval
        echo "+++ STATUS: $0 ($$)" `date` "EVENT $k [$t $h $m]($d) : $event" >& /dev/stderr
        set prior = ( $prior $event )
   endif
end

echo "+++ STATUS: $0 ($$)" `date` "INTERVAL=$interval : ($#prior): $prior" >& /dev/stderr

#
# build "event in context" (EIC) for all prior events across each EVENT classifier's MODEL
#
if ($#prior == 0) goto done

foreach EVENT ( $prior )
    echo "+++ STATUS: $0 ($$)" `date` "EVENT = $EVENT" >& /dev/stderr
    # get time series for EVENT
    set year = `cat "$EVENT" | jq '.year' | sed 's/"//g'`
    set month = `cat "$EVENT" | jq '.month' | sed 's/"//g'`
    set day = `cat "$EVENT" | jq '.day' | sed 's/"//g'`
    set hour = `cat "$EVENT" | jq '.hour' | sed 's/"//g'`
    set minute = `cat "$EVENT" | jq '.minute' | sed 's/"//g'`
    set second = `cat "$EVENT" | jq '.second' | sed 's/"//g'`

    # calculate current time series 
    set index = `echo "$year" "$month" "$day" "$hour" "$minute" "$second" | \
	gawk -v interval="$INTERVAL" '{ m=$4*60+$5; m/=interval; \
    	t=mktime(sprintf("%4d %2d %2d %2d %2d %2d", $1, $2, $3, $4, $5, $6)); \
	printf "{ \"interval\":\"%d\",\"AMPM\":\"%s\",\"week\":\"%d\",\"day\":\"%s\" }", \
	    m, \
	    strftime("%p",t),\
	    strftime("%U",t),\
	    strftime("%w",t) }'`
    echo "+++ STATUS: $0 ($$)" `date` "index = $index" >& /dev/stderr

    set ampm = `echo "$index" | jq '.AMPM' | sed 's/"//g'`
    set week = `echo "$index" | jq '.week' | sed 's/"//g'`
    set day = `echo "$index" | jq '.day' | sed 's/"//g'`
    set interval = `echo "$index" | jq '.interval' | sed 's/"//g'`

    # identify EVENT in context
    set EIC = "$DIR/EIC-$EVENT:t"
    # echo "+++ STATUS: $0 ($$)" `date` "INITIATE EIC: $EIC" >& /dev/stderr
    $0:h/make-eic "$EVENT" "$EIC"

    # union Alchemy and VisualInsights classifiers and scores
    set CLASSES = ( `jq '.classifiers[].class' "$EIC" | sed 's/"//g'` )

    # process each class
    @ i = 0
    foreach CLASS ( $CLASSES )
	set class = `jq -c '.classifiers['$i'].class' "$EIC" | sed 's/"//g'`
	set score = `jq -c '.classifiers['$i'].score' "$EIC" | sed 's/"//g'`
	set model_mean = `jq -c '.classifiers['$i'].model.mean' "$EIC" | sed 's/"//g'`
	set model_stdev = `jq -c '.classifiers['$i'].model.stdev' "$EIC" | sed 's/"//g'`
	echo "$CLASS : $class $score $model_mean $model_stdev $model_mean" >& /dev/stderr
	@ i++
    end
end

done:

set seconds = `date +%s`
set elapsed = ( `echo "$seconds - $SECONDS" | bc` )
echo "+++ END: $0 ($$)" `date` "elapsed $elapsed" >& /dev/stderr
