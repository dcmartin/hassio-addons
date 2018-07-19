#!/bin/csh -fb

# don't update statistics more than once per (in seconds)
set TTL = 1800
set SECONDS = `/bin/date "+%s"`
set DATE = `/bin/echo $SECONDS \/ $TTL \* $TTL | /usr/bin/bc`
set AGE = `/bin/echo "$SECONDS - $DATE" | /usr/bin/bc`

@ age = $SECONDS - $DATE
/bin/echo "Age: $age"
@ refresh = $TTL - $age
# check back if using old
if ($refresh < 0) @ refresh = $TTL

/bin/echo "Refresh: $refresh"
/bin/echo "Cache-Control: max-age=$TTL"
/bin/echo "Last-Modified:" `/bin/date -r $DATE '+%a, %d %b %Y %H:%M:%S %Z'`
/bin/echo "Content-type: text/html"
/bin/echo ""

/bin/echo '<html>'
/bin/echo '<head>'
/bin/echo '<title>DASHBOARD</title>'
/bin/echo '</head>'
/bin/echo '<body>'
/bin/echo ''
/bin/echo '<iframe height="800" width="600" src="http://192.168.1.39/dashboard"></iframe>'
/bin/echo '<iframe height="800" width="600" src="http://192.168.1.40/dashboard"></iframe>'
/bin/echo ''
/bin/echo '</body>'
/bin/echo '</html>'
