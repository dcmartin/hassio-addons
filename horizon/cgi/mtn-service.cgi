#!/bin/csh -fb

# don't update statistics more than once per (in seconds)
set TTL = 1800
set SECONDS = `/bin/date "+%s"`
set DATE = `/bin/echo $SECONDS \/ $TTL \* $TTL | /usr/bin/bc`
set AGE = `/bin/echo "$SECONDS - $DATE" | /usr/bin/bc`

if ($?QUERY_STRING) then
    set ip = `/bin/echo "$QUERY_STRING" | sed 's/.*ip=\([^&]*\).*/\1/'`
    if ($ip == "$QUERY_STRING") unset ip
endif

if ($?ip == 0) then
  set ip = 39
else
  if ($#ip != 1 || ("$ip" != "39" && "$ip" != "40")) then
    exit
  endif
endif

if (! -e /tmp/$0:t.$ip.$DATE.json) then
  /bin/rm -f /tmp/$0:t.$ip.*.json
  /usr/bin/curl -s -q -f -L0 "http://192.168.1.$ip/service" | /usr/local/bin/jq '.' >! /tmp/$0:t.$ip.$DATE.json
endif

@ age = $SECONDS - $DATE
/bin/echo "Age: $age"
@ refresh = $TTL - $age
# check back if using old
if ($refresh < 0) @ refresh = $TTL
/bin/echo "Refresh: $refresh"
/bin/echo "Cache-Control: max-age=$TTL"
/bin/echo "Last-Modified:" `/bin/date -r $DATE '+%a, %d %b %Y %H:%M:%S %Z'`
/bin/echo "Content-type: application/json"
/bin/echo ""
/bin/cat /tmp/$0:t.$ip.$DATE.json
